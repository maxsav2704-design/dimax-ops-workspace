import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { copyFileSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, rmSync, rmdirSync, symlinkSync, unlinkSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const source = path.join(path.dirname(fileURLToPath(import.meta.url)), "prepare-acceptance-mail.ps1");

test("mail secret provisioning is private, reusable and fails closed", { skip: process.platform !== "win32" }, () => {
  const root = mkdtempSync(path.join(os.tmpdir(), "dimax-mail-secret-test-"));
  const scripts = path.join(root, "scripts");
  const folder = path.join(root, "acceptance", ".factory-mail");
  const secret = path.join(folder, "shared.env");
  const other = path.join(root, "unrelated");
  mkdirSync(scripts);
  const script = path.join(scripts, "prepare.ps1");
  copyFileSync(source, script);
  const run = () => spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-File", script], { encoding: "utf8" });
  try {
    assert.notEqual(run().status, 0, "unknown workspace must be rejected");
    assert.equal(existsSync(secret), false);
    writeFileSync(path.join(root, "docker-compose.acceptance.yml"), "services: {}\n");
    const first = run();
    assert.equal(first.status, 0, first.stderr);
    assert.deepEqual(JSON.parse(first.stdout), { status: "created", rotated: false });
    const content = readFileSync(secret, "ascii");
    assert.match(content, /^FACTORY_APPROVAL_EMAIL_KEY=[A-Za-z0-9+/]{43}=\n$/);
    const second = run();
    assert.equal(second.status, 0, second.stderr);
    assert.deepEqual(JSON.parse(second.stdout), { status: "reused", rotated: false });
    assert.ok(readFileSync(secret, "ascii") === content, "restart must not rotate the key");
    const acl = JSON.parse(execFileSync("pwsh", ["-NoProfile", "-NonInteractive", "-Command",
      "$a=Get-Acl -LiteralPath $env:DIMAX_SECRET_TEST_PATH; " +
      "@{Protected=$a.AreAccessRulesProtected; Rules=@($a.Access | ForEach-Object {" +
      "$_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value});" +
      "Owner=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value} | ConvertTo-Json -Compress"],
      { encoding: "utf8", env: { ...process.env, DIMAX_SECRET_TEST_PATH: secret } }));
    assert.equal(acl.Protected, true);
    assert.deepEqual(acl.Rules.sort(), [acl.Owner, "S-1-5-18"].sort());
    writeFileSync(secret, "invalid-secret\n");
    const invalid = run();
    assert.notEqual(invalid.status, 0);
    assert.equal(readFileSync(secret, "ascii"), "invalid-secret\n");
    assert.equal(invalid.stdout.includes("invalid-secret"), false);
    unlinkSync(secret);
    rmdirSync(folder);
    mkdirSync(other);
    writeFileSync(path.join(other, "shared.env"), "must-not-change\n");
    symlinkSync(other, folder, "junction");
    try {
      const redirected = run();
      assert.notEqual(redirected.status, 0);
      assert.match(redirected.stderr, /reparse point/);
      assert.equal(readFileSync(path.join(other, "shared.env"), "ascii"), "must-not-change\n");
    } finally {
      assert.ok(lstatSync(folder).isSymbolicLink());
      unlinkSync(folder);
    }
  } finally {
    assert.ok(path.resolve(root).startsWith(path.resolve(os.tmpdir()) + path.sep));
    for (const target of [root, scripts, path.join(root, "acceptance"), folder, secret, other]) {
      if (existsSync(target)) assert.equal(lstatSync(target).isSymbolicLink(), false);
    }
    rmSync(root, { recursive: true });
  }
});
