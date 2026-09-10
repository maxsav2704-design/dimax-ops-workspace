"""Fixture contracts; run with the backend's locked dependencies."""
import unittest
from types import SimpleNamespace

from bootstrap import acceptance_email, normalize_acceptance_email
from app.modules.identity.api.schemas import LoginBody


class AcceptanceEmailTests(unittest.TestCase):
    def test_generated_addresses_pass_the_real_login_schema(self):
        for local_part in (
            "owner.a", "operations.a", "finance.a", "viewer.a",
            "installer1.a", "installer2.a", "owner.b", "installer1.b", "installer2.b",
        ):
            with self.subTest(account=local_part):
                email = acceptance_email(local_part)
                body = LoginBody(
                    company_id="d1861479-addc-5655-b5c4-f86456bb04d8",
                    email=email, password="Acceptance-only-2026!", device_id="fixture-check",
                )
                self.assertEqual(str(body.email), email)

    def test_legacy_address_normalization_is_repeat_safe(self):
        account = SimpleNamespace(email="owner.a@example.test")
        normalize_acceptance_email(account, "owner.a@example.com")
        normalize_acceptance_email(account, "owner.a@example.com")
        self.assertEqual(account.email, "owner.a@example.com")

    def test_unexpected_address_is_not_overwritten(self):
        account = SimpleNamespace(email="unexpected@example.com")
        with self.assertRaises(RuntimeError):
            normalize_acceptance_email(account, "owner.a@example.com")
        self.assertEqual(account.email, "unexpected@example.com")


if __name__ == "__main__":
    unittest.main()
