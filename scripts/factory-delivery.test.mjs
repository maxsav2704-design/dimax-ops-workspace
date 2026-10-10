import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath } from "node:url";
import test from "node:test";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const compose = ["compose", "-f", "docker-compose.acceptance.yml", "-f", "docker-compose.acceptance.delivery.yml",
  "--profile", "delivery"];
function docker(...args) {
  return execFileSync("docker", args, { cwd: root, encoding: "utf8", timeout: 240_000,
    maxBuffer: 2 * 1024 * 1024, stdio: ["ignore", "pipe", "pipe"] }).trim();
}
function pg(database, sql) {
  return docker(...compose, "exec", "-T", "db", "psql", "-U", "postgres", "-d", database,
    "-A", "-t", "-v", "ON_ERROR_STOP=1", "-c", sql);
}
const ledgerQuery = "SELECT json_build_array(count(*),sum(amount_snapshot)," +
  "md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY id)::text,'[]'))) FROM completed_work t";

test("real factory API/worker/SMTP/code flow survives restarts without activation", {
  skip: process.env.DIMAX_FACTORY_DELIVERY_CHECK !== "1", timeout: 1_200_000,
}, async (t) => {
  const id = randomBytes(6).toString("hex");
  const database = `dimax_factory_delivery_${id}`;
  const api = `dimax-factory-delivery-api-${id}`;
  const worker = `dimax-factory-delivery-worker-${id}`;
  const label = `dimax.acceptance.factory-delivery=${id}`;
  const env = ["-e", `DATABASE_URL=postgresql+psycopg2://postgres:postgres@db:5432/${database}`,
    "-e", "DIMAX_FACTORY_DELIVERY_CHECK=1", "-e", "PUBLIC_APP_BASE_URL=https://factory.example.test"];
  const owned = [];
  let databaseCreated = false;
  let apiStarted = false;
  let failure;
  const before = pg("dimax_acceptance", ledgerQuery);
  const phase = (name) => {
    const output = docker("exec", api, "python", "-B", "-m", "scripts.factory_delivery_acceptance", name);
    assert.equal(output, `PASS: factory delivery ${name}`);
    t.diagnostic(output);
  };
  async function ready(name) {
    for (let i = 0; i < 90; i += 1) {
      const state = JSON.parse(docker("inspect", "--format", "{{json .State}}", name));
      assert.ok(state.Running, "Acceptance process must stay running");
      if (state.Health?.Status === "healthy") return;
      await delay(2_000);
    }
    assert.fail("Disposable service did not become healthy");
  }
  function start(name, service) {
    // Remember names before creation; cleanup also handles a failed start after creation.
    owned.push(name);
    docker(...compose, "run", "--detach", "--no-deps", "--name", name, "--label", label, ...env, service);
  }
  try {
    const config = JSON.parse(docker(...compose, "config", "--format", "json"));
    for (const service of [config.services.api, config.services["outbox-worker"]]) {
      const secret = service.volumes.find((v) => v.target === "/app/.env");
      assert.equal(secret.read_only, true);
      assert.equal(secret.bind.create_host_path, false);
      assert.equal(path.resolve(secret.source), path.join(root, "acceptance", ".factory-mail", "shared.env"));
      assert.equal(service.environment.SMTP_HOST, "mailpit");
      assert.equal(service.environment.WHATSAPP_ENABLED, "false");
      assert.equal(service.environment.FACTORY_APPROVAL_EMAIL_KEY, undefined);
    }
    assert.equal(config.services["outbox-worker"].restart, "unless-stopped");
    assert.deepEqual(config.services["outbox-worker"].healthcheck.test, ["CMD", "python", "-m", "app.workers.outbox_health"]);
    docker(...compose, "exec", "-T", "db", "createdb", "-U", "postgres", database);
    databaseCreated = true;
    docker(...compose, "run", "--rm", "--no-deps", ...env, "api", "alembic", "upgrade", "head");
    start(api, "api");
    apiStarted = true;
    await ready(api);
    phase("prepare");
    start(worker, "outbox-worker");
    await ready(worker);
    phase("invitation");
    docker("stop", "--time", "10", worker);
    phase("request-code");
    docker("restart", "--time", "10", api);
    await ready(api);
    docker("start", worker);
    await ready(worker);
    phase("confirm");
    assert.equal(pg("dimax_acceptance", ledgerQuery), before, "Main ledger changed during acceptance");
    t.diagnostic("PASS: shared key across API/worker restarts; main ledger unchanged; no activation or earnings");
  } catch (error) {
    failure = error;
  } finally {
    const errors = [];
    if (owned.includes(worker)) {
      try {
        const found = docker("ps", "-a", "--filter", `name=^/${worker}$`, "--format", "{{.Names}}");
        if (found) {
          const labels = JSON.parse(docker("inspect", "--format", "{{json .Config.Labels}}", worker));
          assert.equal(labels["dimax.acceptance.factory-delivery"], id);
          docker("stop", "--time", "10", worker);
        }
      } catch { errors.push("Acceptance worker could not be stopped before mailbox cleanup"); }
    }
    if (apiStarted) {
      try {
        // Cleanup also works if the disposable API crashed: no access token or state file is needed.
        const output = docker(...compose, "run", "--rm", "--no-deps", ...env, "api", "python", "-B", "-m",
          "scripts.factory_delivery_acceptance", "cleanup");
        assert.equal(output, "PASS: factory delivery cleanup");
        t.diagnostic(output);
      } catch (error) { errors.push(`Mailpit cleanup failed for factory-delivery-${id}@example.com: ${error.message}`); }
    }
    for (const name of owned.reverse()) {
      try {
        const found = docker("ps", "-a", "--filter", `name=^/${name}$`, "--format", "{{.Names}}");
        if (!found) continue;
        assert.equal(found, name);
        const labels = JSON.parse(docker("inspect", "--format", "{{json .Config.Labels}}", name));
        assert.equal(labels["dimax.acceptance.factory-delivery"], id);
        docker("rm", "--force", name);
      } catch { errors.push(`Container cleanup failed: ${name}`); }
    }
    if (databaseCreated) {
      try {
        assert.match(database, /^dimax_factory_delivery_[a-f0-9]{12}$/);
        docker(...compose, "exec", "-T", "db", "dropdb", "-U", "postgres", database);
      } catch { errors.push(`Database cleanup failed: ${database}`); }
    }
    assert.equal(pg("dimax_acceptance", ledgerQuery), before, "Main ledger changed during acceptance");
    if (errors.length) {
      throw new AggregateError([...(failure ? [failure] : []), ...errors.map((message) => new Error(message))],
        [failure?.message, ...errors].filter(Boolean).join("\n"));
    }
  }
  if (failure) throw failure;
});
