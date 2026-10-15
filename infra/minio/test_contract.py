"""Compose parsing checks; no Docker daemon, starts, pulls or live env reads."""
import json
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
CONFIGS = ("docker-compose.workspace.yml", "docker-compose.workspace.test.yml",
           "docker-compose.demo.yml", "docker-compose.acceptance.yml",
           "acceptance/work-price-runtime.compose.yml")


class MinioContract(unittest.TestCase):
    def test_source_builds_and_storage_identity(self):
        expected_volumes = {
            CONFIGS[0]: "workspace_minio_data", CONFIGS[1]: "workspace_test_minio_data",
            CONFIGS[2]: "demo_minio_data", CONFIGS[3]: "acceptance_files",
        }
        env = {**os.environ, "DIMAX_RUNTIME_MAIL_KEY": "synthetic-contract-value",
               "DIMAX_RUNTIME_OUTPUT": str(ROOT / ".tmp"), "MINIO_ACCESS_KEY": "synthetic-user",
               "MINIO_SECRET_KEY": "synthetic-password", "MINIO_BUCKET": "dimax"}
        for filename in CONFIGS:
            with self.subTest(config=filename):
                result = subprocess.run(["docker", "compose", "-f", str(ROOT / filename), "config",
                                         "--no-env-resolution", "--format", "json"],
                                        capture_output=True, text=True, env=env, timeout=30)
                self.assertEqual(result.returncode, 0, result.stderr)
                config = json.loads(result.stdout)
                services = config["services"]
                for name, image, target in (("minio", "dimax-minio:source-9e49d5e", "server"),
                                             ("minio_init", "dimax-mc:source-7394ce0", "client")):
                    if name not in services:
                        self.assertEqual(name, "minio_init")
                        continue
                    service = services[name]
                    self.assertEqual(service["image"], image)
                    self.assertEqual(service["build"]["target"], target)
                    self.assertEqual(Path(service["build"]["context"]).resolve(), ROOT / "infra/minio")
                    self.assertEqual(service["pull_policy"], "build")
                if filename in expected_volumes:
                    data = next(v for v in services["minio"]["volumes"] if v["target"] == "/data")
                    self.assertEqual(data["source"], expected_volumes[filename])
                    self.assertEqual(data["type"], "volume")

    def test_test_environment_cannot_mount_working_data(self):
        result = subprocess.run(["docker", "compose", "-f", str(Path(__file__).with_name("compose.test.yml")),
                                 "config", "--format", "json"], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        config = json.loads(result.stdout)
        self.assertTrue(config["networks"]["default"]["internal"])
        self.assertFalse(config["volumes"]["data"].get("external", False))
        for service in config["services"].values():
            self.assertFalse(service.get("ports"))
        self.assertEqual(config["services"]["minio"]["volumes"][0]["source"], "data")


if __name__ == "__main__":
    unittest.main()
