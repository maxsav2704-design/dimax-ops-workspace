import unittest
from device_work_price import PUBLIC_URL, require_phone_event, validate_environment


class DeviceAcceptanceGuards(unittest.TestCase):
    def test_only_isolated_environment(self):
        valid = dict(app_env="test", db_host="db", database="dimax_acceptance", smtp_host="mailpit",
                     whatsapp=False, public_url=PUBLIC_URL)
        validate_environment(**valid)
        for key, value in [("app_env", "production"), ("db_host", "localhost"),
                           ("database", "dimax"), ("smtp_host", "smtp.gmail.com"),
                           ("whatsapp", True), ("public_url", "https://example.com")]:
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                validate_environment(**{**valid, key: value})

    def test_requires_exactly_one_phone_work_in_own_project(self):
        fixture = {"project": "owned", "installer": "installer", "door": "door"}
        own = {"project_id": "owned", "event_type": "DOOR_SET_STATUS", "client_event_id": "phone-1",
               "installer_id": "installer", "source": "sync_event",
               "payload": {"door_id": "door", "status": "INSTALLED"}}
        foreign = {**own, "project_id": "other"}
        self.assertEqual(require_phone_event([foreign, own], fixture), own)
        for rows in [[], [foreign], [own, own], [{**own, "event_type": "ADDON_FACT_CREATE"}],
                     [{**own, "installer_id": "other"}], [{**own, "payload": {"door_id": "other"}}],
                     [{**own, "source": "legacy"}]]:
            with self.subTest(rows=rows), self.assertRaises(RuntimeError):
                require_phone_event(rows, fixture)


if __name__ == "__main__":
    unittest.main()
