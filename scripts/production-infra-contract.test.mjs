import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sources = ["scripts/production-infra-contract.ps1", "backend/docker-compose.production.yml", "backend/.env.production.example",
  "infra/production/docker-compose.edge.yml", "infra/production/Caddyfile", "infra/production/deploy.sh", "infra/production/README.md",
  ...["Dockerfile", ".dockerignore", "Dockerfile.artifact", "Dockerfile.artifact.dockerignore", "next.config.mjs"].map((name) => `dimax-operations-suite-main/${name}`)];

for (const mode of ["config", "failure", "host", "build-failure"]) {
  test(`infrastructure ${mode} preserves existing admin output and unrelated resources`, { skip: process.platform !== "win32" }, () => {
    const folder = mkdtempSync(path.join(os.tmpdir(), "dimax-infra-contract-test-"));
    try {
      for (const relative of sources) {
        const target = path.join(folder, relative);
        mkdirSync(path.dirname(target), { recursive: true });
        copyFileSync(path.join(root, relative), target);
      }
      const next = path.join(folder, "dimax-operations-suite-main", ".next");
      const previousOutput = mode === "build-failure" ? path.join(folder, "existing-build") : next;
      mkdirSync(previousOutput);
      const marker = path.join(previousOutput, "KEEP-running-build");
      writeFileSync(marker, "must remain unchanged");
      const log = path.join(folder, "commands.jsonl");
      const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-File", path.join(root, "scripts/production-infra-contract.fixture.ps1")], {
        encoding: "utf8", timeout: 30_000, env: { ...process.env, DIMAX_INFRA_TEST_LOG: log, NEXT_DIST_DIR: previousOutput,
          DIMAX_INFRA_TEST_SCRIPT: path.join(folder, "scripts/production-infra-contract.ps1"),
          DIMAX_INFRA_TEST_FAIL: mode === "failure" ? "config" : "", DIMAX_INFRA_TEST_MODE: mode },
      });
      if (mode === "config") assert.equal(result.status, 0, result.stderr);
      else assert.notEqual(result.status, 0);
      if (mode === "host") assert.match(result.stderr, /Existing .next is preserved/);
      if (mode === "build-failure") {
        assert.match(result.stderr, /Synthetic host build failure/);
        assert.equal(existsSync(next), false);
      }
      assert.equal(readFileSync(marker, "utf8"), "must remain unchanged");
      const commands = existsSync(log) ? readFileSync(log, "utf8").trim().split(/\r?\n/).map(JSON.parse) : [];
      assert.ok(commands.length);
      for (const args of commands) {
        if (mode === "build-failure" && !args.includes("validate") && !args.includes("config")) continue;
        assert.ok(args.includes("config") || args.includes("validate"), JSON.stringify(args));
        assert.ok(!args.includes("rm") && !args.includes("build") && !args.includes("clean"));
        if (args.includes("validate")) assert.equal(args[args.indexOf("--network") + 1], "none");
      }
      if (mode === "build-failure") {
        const run = commands.find((args) => args.includes("--label"));
        const name = run[run.indexOf("--name") + 1];
        assert.match(name, /^dimax-infra-build-keepalive-[a-f0-9]{32}$/);
        assert.deepEqual(commands.filter((args) => args[0] === "rm"), [["rm", "-f", name]]);
        assert.ok(commands.some((args) => args[0] === "inspect" && args.at(-1) === name));
        assert.ok(!commands.some((args) => args.includes("image") || args.includes("clean")));
      }
    } finally {
      assert.ok(path.resolve(folder).startsWith(path.resolve(os.tmpdir()) + path.sep));
      function verify(target) {
        const entry = lstatSync(target);
        assert.equal(entry.isSymbolicLink(), false);
        if (entry.isDirectory()) for (const child of readdirSync(target)) verify(path.join(target, child));
      }
      verify(folder);
      rmSync(folder, { recursive: true });
    }
  });
}
