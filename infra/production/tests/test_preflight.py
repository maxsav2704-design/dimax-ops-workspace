import base64
from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("preflight", SOURCE / "preflight.py")
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)


def valid_config():
    env = {
        "APP_ENV": "production", "DATABASE_URL": "postgresql://dimax:QaDatabasePass1@db.dimax.co.il/dimax?sslmode=require",
        "JWT_SECRET": "qa-jwt-" + "a" * 40,
        "FACTORY_APPROVAL_EMAIL_KEY": base64.b64encode(bytes(range(32))).decode(),
        "PUBLIC_BASE_URL": "https://api.dimax.co.il", "PUBLIC_APP_BASE_URL": "https://ops.dimax.co.il",
        "CORS_ALLOW_ORIGINS": "https://ops.dimax.co.il", "MINIO_ENDPOINT": "storage.dimax.co.il:443",
        "MINIO_ACCESS_KEY": "qa-access", "MINIO_SECRET_KEY": "qa-storage-secret-123456",
        "MINIO_BUCKET": "dimax-qa", "MINIO_SECURE": "true", "EMAIL_ENABLED": "true",
        "SMTP_HOST": "smtp.dimax.co.il", "SMTP_PORT": "587", "SMTP_TLS": "true", "SMTP_USER": "qa-mailer",
        "SMTP_PASSWORD": "qa-smtp-secret-123456", "SMTP_FROM": "qa@dimax.co.il", "WHATSAPP_ENABLED": "false",
        "WHATSAPP_FALLBACK_TO_EMAIL": "false", "TWILIO_WEBHOOK_VALIDATE": "false",
    }
    services = {name: {"environment": dict(env), "image": "registry.dimax.co.il/backend:git-0123456789ab"}
                for name in preflight.BACKEND_SERVICES}
    services["api"]["ports"] = [{"host_ip": "127.0.0.1", "target": 8000, "published": "8000"}]
    services["outbox-worker"].update(restart="unless-stopped", healthcheck={"test": ["CMD", "python", "-m", "app.workers.outbox_health"]})
    services["admin"] = {"image": "registry.dimax.co.il/admin:git-0123456789ab"}
    services["gateway"] = {"environment": {"DIMAX_API_HOST": "api.dimax.co.il", "DIMAX_ADMIN_HOST": "ops.dimax.co.il",
                                           "DIMAX_TLS_EMAIL": "owner@dimax.co.il"}}
    return {"name": "dimax-staging", "services": services}


class PreflightTests(unittest.TestCase):
    def test_valid_without_bootstrap_credentials(self):
        self.assertEqual(preflight.validate(valid_config()), [])

    def test_hosts_reject_private_reserved_and_injected_syntax(self):
        for value in ("localhost", "127.0.0.1", "10.2.3.4", "ops.example", "ops.test", "ops.invalid", "ops.local",
                      "ops.localhost", "ops.internal", "ops.dimax.co.il:443", "https://ops.dimax.co.il", "*.dimax.co.il",
                      "ops.dimax.co.il\nrespond injected", "-ops.dimax.co.il", "ops..dimax.co.il"):
            with self.subTest(value=value):
                self.assertFalse(preflight.public_host(value))

    def test_bad_project_or_missing_services(self):
        config = valid_config()
        config["name"] = "dimax_acceptance"
        self.assertTrue(preflight.validate(config))
        config["services"].pop("outbox-worker")
        self.assertTrue(any("missing" in error for error in preflight.validate(config)))

    def test_mismatched_frontend_api_and_cors_are_rejected(self):
        for key, value in (("PUBLIC_APP_BASE_URL", "https://different.dimax.co.il"),
                           ("PUBLIC_BASE_URL", "https://api.dimax.co.il/api"),
                           ("PUBLIC_BASE_URL", "https://api.dimax.co.il:443"),
                           ("CORS_ALLOW_ORIGINS", "https://ops.dimax.co.il,https://staging.dimax.co.il")):
            config = valid_config()
            config["services"]["api"]["environment"][key] = value
            self.assertTrue(preflight.validate(config), key)

    def test_worker_uses_identical_db_key_and_mail_settings(self):
        for key, value in (("DATABASE_URL", "postgresql://u:Pass1@other.dimax.co.il/dimax?sslmode=require"),
                           ("FACTORY_APPROVAL_EMAIL_KEY", base64.b64encode(b"z" * 32).decode()),
                           ("SMTP_PASSWORD", "different-mail-password")):
            config = valid_config()
            config["services"]["outbox-worker"]["environment"][key] = value
            self.assertTrue(any(key in error and "match" in error for error in preflight.validate(config)))

    def test_existing_backend_security_validator_is_used(self):
        for key, value in (("JWT_SECRET", "short"), ("EMAIL_ENABLED", "false"), ("SMTP_TLS", "false"),
                           ("FACTORY_APPROVAL_EMAIL_KEY", "invalid"), ("MINIO_SECURE", "false")):
            config = valid_config()
            for name in preflight.BACKEND_SERVICES:
                config["services"][name]["environment"][key] = value
            self.assertTrue(preflight.validate(config), key)

    def test_backend_and_admin_images_must_be_immutable_and_coherent(self):
        for name, image in (("api", "backend:latest"), ("admin", "admin:latest"),
                            ("migrate", "registry.dimax.co.il/backend:git-abcdef012345")):
            config = valid_config()
            config["services"][name]["image"] = image
            self.assertTrue(preflight.validate(config))

    def test_non_edge_services_cannot_publish_public_ports(self):
        for name in ("api", "admin", "outbox-worker"):
            config = valid_config()
            config["services"][name]["ports"] = [{"host_ip": "0.0.0.0", "target": 8000}]
            self.assertTrue(preflight.validate(config))

    def test_mail_worker_supervision_cannot_be_removed(self):
        for field in ("restart", "healthcheck"):
            config = valid_config()
            config["services"]["outbox-worker"].pop(field)
            self.assertTrue(preflight.validate(config))

    def test_bootstrap_requires_explicit_owner_credentials(self):
        config = valid_config()
        self.assertTrue(preflight.validate(config, bootstrap=True))
        config["services"]["bootstrap"]["environment"].update(SEED_ADMIN_EMAIL="owner@dimax.co.il", SEED_ADMIN_PASSWORD="QaInitialOwnerPass123")
        self.assertEqual(preflight.validate(config, bootstrap=True), [])

    def test_image_origin_is_inspected_not_inferred_from_runtime_override(self):
        config = valid_config()
        config["services"]["admin"]["environment"] = {"NEXT_PUBLIC_API_BASE_URL": "https://api.dimax.co.il"}
        for base, user, valid in (("https://api.dimax.co.il", "10001:10001", True),
                                  ("http://localhost:8000", "10001:10001", False),
                                  ("https://api.dimax.co.il", "root", False)):
            result = subprocess.CompletedProcess([], 0, json.dumps([{"Config": {"Env": [f"NEXT_PUBLIC_API_BASE_URL={base}"], "User": user}}]))
            with patch.object(preflight.subprocess, "run", return_value=result):
                self.assertEqual(not preflight.validate(config, inspect_admin_image=True), valid)

    def test_cli_never_echoes_secrets_or_malformed_input(self):
        config = valid_config()
        secret = "do-not-echo-Secret-Token"
        config["services"]["api"]["environment"]["DATABASE_URL"] = "https://user:" + secret + "@["
        for payload in (json.dumps(config), secret, "[]"):
            output = io.StringIO()
            with redirect_stdout(output), redirect_stderr(output):
                self.assertNotEqual(preflight.main([], io.StringIO(payload)), 0)
            self.assertNotIn(secret, output.getvalue())


@unittest.skipUnless(os.name == "posix", "deploy.sh targets the Linux production host")
class DeployShellTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dimax-deploy-preflight-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.infra = self.root / "infra/production"
        self.infra.mkdir(parents=True)
        backend = self.root / "backend/scripts"
        backend.mkdir(parents=True)
        for name in ("deploy.sh", "preflight.py"):
            shutil.copyfile(SOURCE / name, self.infra / name)
        shutil.copyfile(preflight.ROOT / "backend/scripts/validate_production_env.py", backend / "validate_production_env.py")
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        (bin_dir / "docker").write_text((SOURCE / "tests/docker_fixture.py").read_text())
        (bin_dir / "docker").chmod(0o700)
        self.config = self.root / "rendered.json"
        self.config.write_text(json.dumps(valid_config()))
        self.log = self.root / "commands.jsonl"
        self.marker = self.root / "env-was-executed"
        (self.infra / ".env.local").write_text(f"UNUSED=$(touch '{self.marker}')\n")
        self.env = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}", "FIXTURE_COMPOSE_JSON": str(self.config),
                    "FIXTURE_DOCKER_LOG": str(self.log), "DIMAX_INFRA_ENV_FILE": str(self.infra / ".env.local"),
                    "DIMAX_RUN_BOOTSTRAP": "false"}

    def run_script(self, *args):
        return subprocess.run(["sh", str(self.infra / "deploy.sh"), *args], env=self.env, text=True,
                              capture_output=True, timeout=20)

    def commands(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_check_never_executes_env_or_changes_services(self):
        result = self.run_script("--check")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.marker.exists())
        self.assertEqual(len(self.commands()), 1)
        self.assertIn("config", self.commands()[0])

    def test_invalid_config_or_failed_compose_stops_before_pull(self):
        self.config.write_text('{"name":"dimax_acceptance"}')
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertEqual(len(self.commands()), 1)
        self.env["FIXTURE_FAIL_COMMAND"] = "config"
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertTrue(all("config" in args for args in self.commands()))

    def test_bad_flags_do_not_start_deploy(self):
        for flags in (("--typo",), ("--check", "extra")):
            self.assertNotEqual(self.run_script(*flags).returncode, 0)
        self.assertEqual(self.commands(), [])

    def test_stale_admin_image_stops_before_migrations(self):
        self.env["FIXTURE_BAD_IMAGE"] = "1"
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertFalse(any("migrate" in args or "up" in args for args in self.commands()))

    def test_deploy_order_waits_for_health_without_orphan_deletion(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.commands()
        indexes = [next(i for i, args in enumerate(commands) if item in args) for item in ("pull", "inspect", "migrate", "up", "ps")]
        self.assertEqual(indexes, sorted(indexes))
        up = commands[indexes[3]]
        self.assertIn("--wait", up)
        self.assertNotIn("--remove-orphans", up)
        self.assertFalse(self.marker.exists())

    def test_failed_migration_does_not_start_services(self):
        self.env["FIXTURE_FAIL_COMMAND"] = "migrate"
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertTrue(any("migrate" in args for args in self.commands()))
        self.assertFalse(any("up" in args for args in self.commands()))


if __name__ == "__main__":
    unittest.main()
