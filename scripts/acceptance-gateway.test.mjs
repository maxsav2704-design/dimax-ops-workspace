import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { request as httpRequest } from "node:http";
import path from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath } from "node:url";
import test from "node:test";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const id = `dimax-gateway-check-${process.pid}`;
const network = `${id}-net`;
const upstream = `${id}-api`;
const gateway = `${id}-proxy`;
const label = `dimax.acceptance.gateway-check=${id}`;

function docker(...args) {
  return execFileSync("docker", args, {
    encoding: "utf8", timeout: 90_000, maxBuffer: 2 * 1024 * 1024,
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

function findHandlers(value, name, found = []) {
  if (!value || typeof value !== "object") return found;
  if (value.handler === name) found.push(value);
  for (const child of Object.values(value)) findHandlers(child, name, found);
  return found;
}

// Opt-in integration test: existing images only, unique containers, no app network.
test("acceptance gateway transport and lost-response contract", {
  skip: process.env.DIMAX_GATEWAY_CHECK !== "1", timeout: 300_000,
}, async (t) => {
  const created = [];
  let networkCreated = false;
  try {
    docker("network", "create", "--internal", "--label", label, network);
    networkCreated = true;
    docker("create", "--pull", "never", "--name", upstream, "--label", label,
      "--network", network, "--network-alias", "api",
      "--memory", "64m", "--pids-limit", "64", "--read-only",
      "--cap-drop", "ALL", "--security-opt", "no-new-privileges:true",
      "--mount", `type=bind,src=${path.join(root, "scripts/acceptance-gateway-fixture.py")},dst=/fixture.py,readonly`,
      "--entrypoint", "python", "dimax-backend-workspace:local", "-B", "/fixture.py");
    created.push(upstream);
    docker("start", upstream);
    docker("create", "--pull", "never", "--name", gateway, "--label", label,
      "--network", "bridge", "--publish", "127.0.0.1::8000",
      "--memory", "64m", "--pids-limit", "64", "--read-only",
      "--cap-drop", "ALL", "--cap-add", "NET_BIND_SERVICE",
      "--security-opt", "no-new-privileges:true", "--tmpfs", "/data", "--tmpfs", "/config",
      "--mount", `type=bind,src=${path.join(root, "acceptance/Caddyfile")},dst=/etc/caddy/Caddyfile,readonly`,
      "caddy:2.11.4-alpine");
    created.push(gateway);
    docker("network", "connect", network, gateway);
    docker("start", gateway);
    const inspection = JSON.parse(docker("inspect", gateway))[0];
    const port = inspection.NetworkSettings.Ports["8000/tcp"][0].HostPort;
    const base = `http://127.0.0.1:${port}`;
    const request = (url, options = {}) => new Promise((resolve, reject) => {
      const body = options.body ?? "";
      const req = httpRequest(`${base}${url}`, {
        method: options.method ?? "GET",
        headers: { ...options.headers, "Content-Length": Buffer.byteLength(body) },
      }, (response) => {
        const chunks = [];
        response.on("data", (chunk) => chunks.push(chunk));
        response.on("error", (error) => { clearTimeout(deadline); reject(error); });
        response.on("end", () => {
          clearTimeout(deadline);
          const data = Buffer.concat(chunks);
          resolve({
            status: response.statusCode, ok: response.statusCode === 200,
            headers: new Map(Object.entries(response.headers).map(([key, value]) => [key, value])),
            json: async () => JSON.parse(data.toString()),
            arrayBuffer: async () => data,
          });
        });
      });
      const deadline = setTimeout(() => req.destroy(new Error("fixture request timed out")), 15_000);
      req.on("error", (error) => { clearTimeout(deadline); reject(error); });
      req.end(body);
    });
    let ready = false;
    for (let attempt = 0; attempt < 20; attempt += 1) {
      try {
        const response = await request("/ready");
        ready = response.ok && (await response.json()).fixture === true;
      } catch { /* Wait only for fixture startup; never repeat a write. */ }
      if (ready) break;
      await delay(500);
    }
    assert.ok(ready, "disposable fixture did not start");

    await t.test("adapted config caches IPv4 DNS and expires idle connections early", () => {
      const config = JSON.parse(docker("exec", gateway, "caddy", "adapt",
        "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"));
      const proxy = findHandlers(config, "reverse_proxy").find((item) => item.dynamic_upstreams);
      assert.equal(proxy.dynamic_upstreams.source, "a");
      assert.equal(proxy.dynamic_upstreams.name, "api");
      assert.equal(proxy.dynamic_upstreams.refresh, 30_000_000_000);
      assert.deepEqual(proxy.dynamic_upstreams.versions, { ipv4: true });
      assert.equal(proxy.transport.keep_alive.idle_timeout, 4_000_000_000);
      assert.equal(proxy.transport.dial_timeout, 5_000_000_000);
      assert.ok(!proxy.load_balancing?.retries);
      assert.ok(!proxy.load_balancing?.try_duration);
    });
    await t.test("normal writes and writes after idle time execute once", async () => {
      for (const route of ["/write/first", "/write/after-idle"]) {
        if (route.endsWith("after-idle")) await delay(6_000);
        const response = await request(route, { method: "POST", body: "fixture" });
        assert.equal(response.status, 200);
        assert.deepEqual(await response.json(), { accepted: 1 });
      }
    });
    for (const [name, origin] of [
      ["loopback", "http://127.0.0.1:4173"], ["localhost", "http://localhost:4173"],
      ["untrusted", "https://untrusted.example"], ["missing", null],
    ]) {
      await t.test(`lost write response is not replayed; CORS ${name}`, async () => {
        const response = await request(`/lost-response/${name}`, {
          method: "POST", body: "fixture", headers: origin ? { Origin: origin } : {},
        });
        assert.equal(response.status, 502);
        assert.equal((await response.json()).error.code, "UPSTREAM_UNAVAILABLE");
        const allowed = name === "loopback" || name === "localhost";
        assert.equal(response.headers.get("access-control-allow-origin"), allowed ? origin : undefined);
        assert.equal(response.headers.get("access-control-allow-credentials"), allowed ? "true" : undefined);
        assert.equal(response.headers.get("cache-control"), "no-store");
        assert.equal(response.headers.get("vary"), "Origin");
        const counts = await (await request("/counts")).json();
        assert.equal(counts[`/lost-response/${name}`], 1);
      });
    }
    await t.test("business validation errors retain their status and body", async () => {
      const response = await request("/validation", { method: "POST", body: "fixture" });
      assert.equal(response.status, 422);
      assert.deepEqual(await response.json(), { error: { code: "VALIDATION_ERROR" } });
    });
    await t.test("API unavailable is an error, then service recovers", async () => {
      docker("stop", "--time", "1", upstream);
      const unavailable = await request("/ready");
      // A cached address refuses the connection (502); an empty DNS pool is 503.
      assert.ok([502, 503].includes(unavailable.status), `unexpected outage status ${unavailable.status}`);
      assert.equal((await unavailable.json()).error.code, "UPSTREAM_UNAVAILABLE");
      docker("start", upstream);
      // Empty discovery results may stay cached until the configured 30s refresh.
      const recoveryDeadline = Date.now() + 45_000;
      while (Date.now() < recoveryDeadline) {
        const response = await request("/ready");
        if (response.ok) {
          assert.deepEqual(await response.json(), { fixture: true });
          return;
        }
        await response.arrayBuffer();
        await delay(500);
      }
      assert.fail("fixture did not recover");
    });
  } finally {
    const failures = [];
    for (const name of created.reverse()) {
      try {
        const owned = JSON.parse(docker("inspect", name))[0].Config.Labels;
        assert.equal(owned["dimax.acceptance.gateway-check"], id);
        docker("rm", "--force", name);
      } catch (error) { failures.push(`${name}: ${error.message}`); }
    }
    if (networkCreated) {
      try {
        const owned = JSON.parse(docker("network", "inspect", network))[0].Labels;
        assert.equal(owned["dimax.acceptance.gateway-check"], id);
        docker("network", "rm", network);
      } catch (error) { failures.push(`${network}: ${error.message}`); }
    }
    assert.deepEqual(failures, [], "fixture cleanup must finish");
  }
});
