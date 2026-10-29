"""Offline contracts for the planning-only domain/mail coordinates."""
import configparser
from pathlib import Path
import unittest
from unittest.mock import patch

from test_preflight import preflight, valid_config


PLAN = Path(__file__).resolve().parents[1] / "planning" / "public-services.example.ini"


class PublicServicesPlanTests(unittest.TestCase):
    def setUp(self):
        self.plan = configparser.ConfigParser(interpolation=None)
        self.plan.optionxform = str
        with PLAN.open(encoding="utf-8") as stream:
            self.plan.read_file(stream)

    def test_all_clients_and_links_agree(self):
        edge = self.plan["edge"]
        backend = self.plan["backend"]
        api = "https://" + edge["DIMAX_API_HOST"]
        admin = "https://" + edge["DIMAX_ADMIN_HOST"]
        self.assertNotEqual(api, admin)
        self.assertEqual(backend["PUBLIC_BASE_URL"], api)
        self.assertEqual(backend["PUBLIC_APP_BASE_URL"], admin)
        self.assertEqual(backend["CORS_ALLOW_ORIGINS"], admin)
        self.assertEqual(self.plan["admin_build"]["NEXT_PUBLIC_API_BASE_URL"], api)
        self.assertEqual(self.plan["mobile_build"]["EXPO_PUBLIC_API_BASE_URL"], api)

    def test_coordinates_use_only_reserved_domain(self):
        self.assertEqual(self.plan["edge"]["DIMAX_API_HOST"], "api.dimax.example")
        self.assertEqual(self.plan["edge"]["DIMAX_ADMIN_HOST"], "ops.dimax.example")
        self.assertEqual(self.plan["backend"]["SMTP_HOST"], "smtp.dimax.example")
        for section, key in (("edge", "DIMAX_TLS_EMAIL"), ("backend", "SMTP_FROM")):
            self.assertEqual(self.plan[section][key].split("@")[1], "dimax.example")

    def test_mail_requires_starttls_not_implicit_tls(self):
        self.assertTrue(self.plan.getboolean("backend", "EMAIL_ENABLED"))
        self.assertTrue(self.plan.getboolean("backend", "SMTP_TLS"))
        self.assertEqual(self.plan.getint("backend", "SMTP_PORT"), 587)

    def test_plan_contains_only_public_coordinates(self):
        expected = {
            "edge": {"DIMAX_API_HOST", "DIMAX_ADMIN_HOST", "DIMAX_TLS_EMAIL"},
            "backend": {"PUBLIC_BASE_URL", "PUBLIC_APP_BASE_URL", "CORS_ALLOW_ORIGINS",
                        "EMAIL_ENABLED", "SMTP_HOST", "SMTP_PORT", "SMTP_TLS", "SMTP_FROM"},
            "admin_build": {"NEXT_PUBLIC_API_BASE_URL"},
            "mobile_build": {"EXPO_PUBLIC_API_BASE_URL"},
        }
        self.assertFalse(self.plan.defaults())
        self.assertEqual(set(self.plan.sections()), set(expected))
        for section, keys in expected.items():
            self.assertEqual(set(self.plan[section]), keys)

    def test_existing_preflight_rejects_planned_hosts_without_docker(self):
        config = valid_config()
        config["services"]["gateway"]["environment"].update(self.plan["edge"])
        for name in preflight.BACKEND_SERVICES:
            config["services"][name]["environment"].update(self.plan["backend"])
        with patch.object(preflight.subprocess, "run") as run:
            errors = preflight.validate(config, inspect_admin_image=True)
        run.assert_not_called()
        for key in ("DIMAX_API_HOST", "DIMAX_ADMIN_HOST", "DIMAX_TLS_EMAIL"):
            self.assertTrue(any(key in error for error in errors), key)


if __name__ == "__main__":
    unittest.main()
