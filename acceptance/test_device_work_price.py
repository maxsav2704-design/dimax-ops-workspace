import unittest
from contextlib import ExitStack
from types import SimpleNamespace
from unittest.mock import Mock, patch
from uuid import UUID, uuid4

from device_work_price import PUBLIC_URL, publish_fixture, require_phone_event, validate_environment


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


class DeviceFixturePublication(unittest.TestCase):
    def setUp(self):
        self.fixture = {key: str(uuid4()) for key in ("company", "project", "installer", "door")}
        self.fixture["stage"] = "AWAITING_PHONE_COMMAND"
        self.door = SimpleNamespace(id=UUID(self.fixture["door"]), project_id=UUID(self.fixture["project"]),
                                    installer_id=UUID(self.fixture["installer"]), is_locked=False)
        self.uow = Mock()
        self.uow.session.execute.return_value.scalar_one.return_value = 0
        self.uow.sync_change_log.max_cursor.return_value = 0
        self.uow.doors.get.return_value = self.door
        self.uow.projects.get.return_value = SimpleNamespace(id=self.door.project_id)
        context = Mock()
        context.__enter__ = Mock(return_value=self.uow)
        context.__exit__ = Mock(return_value=False)
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(patch("device_work_price.assert_fixture"))
        self.stack.enter_context(patch.dict("sys.modules", {
            "app.modules.doors.application.sync_payload": SimpleNamespace(build_door_sync_payload=lambda door: {"door": str(door.id)}),
            "app.modules.projects.application.sync_payload": SimpleNamespace(build_project_sync_payload=lambda project: {"project": str(project.id)}),
            "app.modules.sync.domain.enums": SimpleNamespace(SyncChangeType=SimpleNamespace(PROJECT_BASE="PROJECT_BASE", DOOR="DOOR")),
            "app.shared.infrastructure.db.uow_sqlalchemy": SimpleNamespace(SqlAlchemyUnitOfWork=lambda: context),
        }))
        self.runtime = SimpleNamespace(text=lambda sql: sql)

    def test_publishes_only_assigned_project_and_door_once(self):
        self.assertEqual(publish_fixture(self.runtime, self.fixture), {"fixture_published": True, "already_present": False})
        calls = self.uow.sync_change_log.add_change.call_args_list
        self.assertEqual([call.kwargs["change_type"] for call in calls], ["PROJECT_BASE", "DOOR"])
        for call in calls:
            self.assertEqual(str(call.kwargs["company_id"]), self.fixture["company"])
            self.assertEqual(str(call.kwargs["installer_id"]), self.fixture["installer"])
            self.assertEqual(str(call.kwargs["project_id"]), self.fixture["project"])
        self.uow.commit.assert_called_once()
        self.uow.sync_change_log.max_cursor.return_value = 2
        self.assertTrue(publish_fixture(self.runtime, self.fixture)["already_present"])
        self.assertEqual(self.uow.sync_change_log.add_change.call_count, 2)
        self.uow.commit.assert_called_once()

    def test_refuses_after_phone_event_or_work_without_writing(self):
        for counts in [(1, 0), (0, 1)]:
            with self.subTest(counts=counts), self.assertRaises(RuntimeError):
                self.uow.session.execute.return_value.scalar_one.side_effect = counts
                publish_fixture(self.runtime, self.fixture)
        self.uow.commit.assert_not_called()
        self.uow.sync_change_log.add_change.assert_not_called()

    def test_refuses_later_stage_and_changed_assignment(self):
        with self.assertRaises(RuntimeError):
            publish_fixture(self.runtime, {**self.fixture, "stage": "PROPOSED"})
        for changes in ({"installer_id": uuid4()}, {"project_id": uuid4()}, {"is_locked": True}):
            with self.subTest(changes=changes), self.assertRaises(RuntimeError):
                self.uow.doors.get.return_value = SimpleNamespace(**{**vars(self.door), **changes})
                publish_fixture(self.runtime, self.fixture)
        self.uow.commit.assert_not_called()
        self.uow.sync_change_log.add_change.assert_not_called()


if __name__ == "__main__":
    unittest.main()
