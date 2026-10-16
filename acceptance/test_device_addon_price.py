import unittest
from copy import deepcopy
from types import SimpleNamespace
from unittest.mock import Mock, patch

import device_addon_price as addon


class AddonAcceptanceGuards(unittest.TestCase):
    def setUp(self):
        self.fixture = dict(project="project", installer="installer", addon="addon", price="price",
                            door="door", receipt="door-receipt", stage="ACCRUED_AWAITING_PHONE_ACK")
        self.event = dict(id="source", client_event_id=addon.EVENT_ID, source="sync_event",
                          event_type="ADDON_FACT_CREATE", project_id="project", installer_id="installer",
                          client_happened_at="2026-10-15T21:35:31.910Z",
                          payload=dict(qty_done="1", addon_type_id="addon", price_list_id="price"))
        self.door = dict(id="door-earning", work_kind="DOOR", entry_type="ORIGINAL", project_id="project",
                         installer_id="installer", door_id="door", quantity="1.00", rate_snapshot="9.01",
                         amount_snapshot="9.01", completed_at="2026-10-15T21:35:00.673Z",
                         work_price={"id": "door-receipt"})
        self.state = dict(baseline=addon.ledger_snapshot(self.door), receipt="addon-receipt",
                          performed_at=self.event["client_happened_at"])
        self.earning = dict(id="addon-earning", work_kind="ADDON", entry_type="ORIGINAL", project_id="project",
                            installer_id="installer", addon_type_id="addon", addon_fact_id="fact", quantity="1.00",
                            rate_snapshot="9.01", amount_snapshot="9.01", can_correct=False,
                            completed_at="2026-10-16T00:35:31.910+03:00", work_price={"id": "addon-receipt"})

    def test_requires_exact_observed_event(self):
        self.assertEqual(addon.require_addon([self.event], self.fixture), self.event)
        cases = [[], [self.event, self.event]]
        for key in ("client_event_id", "source", "event_type", "project_id", "installer_id"):
            cases.append([{**self.event, key: "other"}])
        cases.append([{**self.event, "client_happened_at": None}])
        for rows in cases:
            with self.subTest(rows=rows), self.assertRaises(RuntimeError):
                addon.require_addon(rows, self.fixture)

    def test_refuses_quantity_or_price_context_changes(self):
        changes = [("qty_done", value) for value in (None, "", "0", "1.5", "-1", "NaN", "Infinity")]
        changes += [("addon_type_id", "other"), ("price_list_id", "other")]
        for key, value in changes:
            row = {**self.event, "payload": {**self.event["payload"], key: value}}
            with self.subTest(key=key, value=value), self.assertRaises(RuntimeError):
                addon.require_addon([row], self.fixture)

    def test_confirmation_does_not_create_money(self):
        addon.assert_ledger([self.door], self.state, self.fixture, accrued=False)
        with self.assertRaises(AssertionError):
            addon.assert_ledger([self.door, self.earning], self.state, self.fixture, accrued=False)

    def test_preserves_previous_door_earning_and_evidence(self):
        for key in addon.LEDGER_FIELDS:
            changed = {**self.door, key: "changed"}
            with self.subTest(key=key), self.assertRaises(AssertionError):
                addon.assert_ledger([changed], self.state, self.fixture, accrued=False)

    def test_exactly_one_addon_and_original_execution_time(self):
        addon.assert_ledger([self.door, self.earning], self.state, self.fixture, accrued=True)
        for rows in ([self.door], [self.door, self.earning, self.earning]):
            with self.assertRaises(AssertionError):
                addon.assert_ledger(rows, self.state, self.fixture, accrued=True)
        changes = dict(work_kind="DOOR", entry_type="REVERSAL", project_id="other", installer_id="other",
                       addon_type_id="other", addon_fact_id=None, quantity="1.5", rate_snapshot="99.00",
                       amount_snapshot="99.00", can_correct=True, work_price={"id": "other"},
                       completed_at="2026-10-16T21:35:31.910Z")
        for key, value in changes.items():
            with self.subTest(key=key), self.assertRaises(AssertionError):
                addon.assert_ledger([self.door, {**self.earning, key: value}], self.state, self.fixture, accrued=True)

    def test_observe_persists_existing_evidence_without_creating_work(self):
        runtime = SimpleNamespace(request=Mock(side_effect=[{"items": [self.event]}, {"items": [self.door]}]))
        with patch.object(addon.device, "save") as save:
            state = addon.observe(runtime, object(), self.fixture)
            self.assertEqual(state["payload"], self.event["payload"])
            self.assertEqual(state["performed_at"], self.event["client_happened_at"])
            self.assertEqual(state["stage"], "OBSERVED")
            save.assert_called_once_with(self.fixture)
            self.assertIs(addon.observe(runtime, object(), self.fixture), state)
            self.assertEqual(runtime.request.call_count, 2)
            self.assertTrue(all(call.args[1] == "GET" for call in runtime.request.call_args_list))

    def test_changed_event_stops_before_proposal(self):
        state = dict(stage="OBSERVED", source_id="source", performed_at=self.event["client_happened_at"],
                     payload=deepcopy(self.event["payload"]))
        runtime = SimpleNamespace(request=Mock(return_value={"items": [{**self.event, "id": "changed"}]}))
        with patch.object(addon.device, "save") as save, self.assertRaises(RuntimeError):
            addon.review(runtime, object(), object(), object(), object(), self.fixture, state)
        save.assert_not_called()
        runtime.request.assert_called_once()

    def test_accrual_reuses_saved_request_after_unknown_outcome(self):
        state = {**self.state, "stage": "CONFIRMED", "approval": "approval"}
        self.fixture["addon_acceptance"] = state
        runtime = SimpleNamespace(request=Mock(side_effect=[{"approval_hash": "hash"}, None, None,
                                                           TimeoutError("response lost")]))
        persisted = []
        with patch.object(addon.device, "save", side_effect=lambda f: persisted.append(deepcopy(f))):
            with self.assertRaises(TimeoutError):
                addon.accrue(runtime, object(), object(), self.fixture, state)
        saved = persisted[0]["addon_acceptance"]
        self.assertEqual(saved["stage"], "ACCRUAL_SUBMITTING")
        request = saved["accrual_request"]
        self.assertEqual(runtime.request.call_args.args[3], request)
        receipt = {"id": "addon-receipt", "amount": "9.01"}
        runtime.request = Mock(side_effect=[None, None, receipt, receipt, None])
        with patch.object(addon.device, "save"), patch.object(addon, "verify") as verify:
            addon.accrue(runtime, object(), object(), self.fixture, saved)
        self.assertEqual(runtime.request.call_args_list[2].args[3], request)
        self.assertEqual(runtime.request.call_args_list[3].args[3], request)
        self.assertEqual(saved["stage"], "ACCRUED")
        verify.assert_called_once()

    def test_accrual_requires_factory_confirmation(self):
        runtime = SimpleNamespace(request=Mock())
        for stage in ("OBSERVED", "PREPARED", "INVITED"):
            with self.subTest(stage=stage), self.assertRaises(RuntimeError):
                addon.accrue(runtime, object(), object(), self.fixture, {"stage": stage})
        runtime.request.assert_not_called()


if __name__ == "__main__":
    unittest.main()
