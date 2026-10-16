"""Resume only the observed synthetic PHONE addon; never create/rewrite its event."""
from __future__ import annotations

import argparse
import json
import os
from datetime import datetime
from decimal import Decimal, InvalidOperation
from uuid import uuid4

import device_work_price as device


EVENT_ID = "1792100131910-xojfp1u0ys"
RATE = "9.01"
LEDGER_FIELDS = ("id", "work_kind", "entry_type", "project_id", "installer_id", "door_id",
                 "addon_fact_id", "completed_at", "quantity", "rate_snapshot", "amount_snapshot", "work_price")


def require_addon(items, fixture):
    matches = [row for row in items if row.get("client_event_id") == EVENT_ID]
    if len(matches) != 1:
        raise RuntimeError("Expected exactly the previously observed phone addon")
    row = matches[0]
    payload = row.get("payload") or {}
    try:
        quantity = Decimal(str(payload.get("qty_done")))
        valid_quantity = quantity.is_finite() and quantity == Decimal("1")
    except InvalidOperation:
        valid_quantity = False
    if (row.get("source") != "sync_event" or row.get("event_type") != "ADDON_FACT_CREATE"
            or row.get("project_id") != fixture["project"] or row.get("installer_id") != fixture["installer"]
            or payload.get("addon_type_id") != fixture["addon"] or not valid_quantity
            or payload.get("price_list_id") != fixture["price"] or not row.get("client_happened_at")):
        raise RuntimeError("Phone addon identity, quantity or price context changed")
    return row


def ledger_snapshot(row):
    return {key: row.get(key) for key in LEDGER_FIELDS}


def assert_ledger(rows, state, fixture, *, accrued):
    original = [row for row in rows if row["id"] == state["baseline"]["id"]]
    if len(original) != 1 or ledger_snapshot(original[0]) != state["baseline"]:
        raise AssertionError("Previously earned door amount/evidence changed")
    others = [row for row in rows if row["id"] != state["baseline"]["id"]]
    if not accrued:
        if others:
            raise AssertionError("Factory confirmation must not accrue another work")
        return
    if len(others) != 1:
        raise AssertionError("Expected one addon earning, without duplicates")
    row = others[0]
    if (row["work_kind"] != "ADDON" or row["entry_type"] != "ORIGINAL"
            or row["project_id"] != fixture["project"] or row["installer_id"] != fixture["installer"]
            or row.get("addon_type_id") != fixture["addon"] or not row.get("addon_fact_id")
            or Decimal(row["quantity"]) != Decimal("1") or Decimal(row["rate_snapshot"]) != Decimal(RATE)
            or Decimal(row["amount_snapshot"]) != Decimal(RATE) or row.get("can_correct") is not False
            or (row.get("work_price") or {}).get("id") != state["receipt"]
            or datetime.fromisoformat(row["completed_at"]) != datetime.fromisoformat(state["performed_at"])):
        raise AssertionError("Addon earning does not match the approved original phone work")


def ledger(r, admin):
    return r.request(admin, "GET", "/admin/earnings/ledger")["items"]


def observe(r, admin, fixture):
    if "addon_acceptance" in fixture:
        return fixture["addon_acceptance"]
    if fixture["stage"] != "ACCRUED_AWAITING_PHONE_ACK":
        raise RuntimeError("Complete the existing door acceptance first")
    row = require_addon(r.request(admin, "GET", "/admin/sync/problems?status=price_conflict")["items"], fixture)
    rows = ledger(r, admin)
    if (len(rows) != 1 or rows[0]["work_kind"] != "DOOR"
            or rows[0]["door_id"] != fixture["door"] or Decimal(rows[0]["amount_snapshot"]) != Decimal("9.01")
            or (rows[0].get("work_price") or {}).get("id") != fixture["receipt"]):
        raise RuntimeError("Unexpected baseline; refusing another work or changed door earning")
    state = {"stage": "OBSERVED", "source_id": row["id"], "event_id": EVENT_ID,
             "performed_at": row["client_happened_at"], "payload": row["payload"],
             "baseline": ledger_snapshot(rows[0])}
    fixture["addon_acceptance"] = state
    device.save(fixture)
    return state


def review(r, admin, installer, public, mail, fixture, state):
    if state["stage"] not in {"OBSERVED", "PREPARED", "INVITED", "CONFIRMED"}:
        raise RuntimeError("Addon is already in the separate accrual stage")
    row = require_addon(r.request(admin, "GET", "/admin/sync/problems?status=price_conflict")["items"], fixture)
    if row["id"] != state["source_id"] or row["payload"] != state["payload"] or row["client_happened_at"] != state["performed_at"]:
        raise RuntimeError("Retained phone evidence changed; do not rewrite it")
    path = f'/admin/sync/price-conflicts/sync_event/{row["id"]}/work-price-proposals'
    if "proposal" not in state:
        if "proposal_request" not in state:
            preview = r.request(admin, "POST", path + "/review", {})
            state["proposal_request"] = {"request_id": str(uuid4()), "review_token": preview["review_token"],
                "rate": RATE, "reason": "Missing rate for previously retained synthetic phone addon",
                "agreement_reference": "Synthetic device addon agreement only",
                "execution_evidence": "Observed phone SQLite and server event on October 16; quantity 1; no real work",
                "confirm_execution_evidence": True}
            device.save(fixture)
        r.request(installer, "POST", path, state["proposal_request"], expected=403)
        proposal = r.request(admin, "POST", path, state["proposal_request"])
        assert Decimal(proposal["amount"]) == Decimal(RATE) and Decimal(proposal["scope"]["quantity"]) == 1
        state.update(proposal=proposal["id"], proposal_hash=proposal["snapshot_hash"], stage="PREPARED")
        device.save(fixture)
    if "approval" not in state:
        if "invitation_request" not in state:
            state["mail_before"] = sorted(r.mailbox_ids(mail))
            state["invitation_request"] = {"request_id": str(uuid4()), "factory_contact_id": fixture["contact"],
                                            "proposal_hash": state["proposal_hash"]}
            device.save(fixture)
        invitation = r.request(admin, "POST", f'/admin/sync/work-price-proposals/{state["proposal"]}/invitations',
                               state["invitation_request"])
        state.update(approval=invitation["id"], stage="INVITED")
        device.save(fixture)
    token = r.receive(mail, set(state["mail_before"]), r"/work-price-approval#([A-Za-z0-9_-]{43})")
    preview = r.request(public, "POST", "/public/price-approvals/work/preview", {"token": token})
    assert preview["work"]["proposal_id"] == state["proposal"]
    assert Decimal(preview["work"]["quantity"]) == 1 and Decimal(preview["work"]["amount"]) == Decimal(RATE)
    assert datetime.fromisoformat(preview["work"]["performed_at"]) == datetime.fromisoformat(state["performed_at"])
    if preview["status"] != "CONFIRMED":
        r.request(admin, "GET", f'/admin/sync/work-price-approvals/{state["approval"]}/accrual', expected=409)
        r.confirm(public, mail, token, work=True)
    assert_ledger(ledger(r, admin), state, fixture, accrued=False)
    assert r.request(installer, "POST", "/installer/sync", {"events": [], "price_resolution_checks": [EVENT_ID]})["acks"] == []
    state["stage"] = "CONFIRMED"
    device.save(fixture)


def accrue(r, admin, installer, fixture, state):
    if state["stage"] not in {"CONFIRMED", "ACCRUAL_SUBMITTING", "ACCRUED"}:
        raise RuntimeError("Factory must confirm before administrator accrual")
    path = f'/admin/sync/work-price-approvals/{state["approval"]}/accrual'
    if "accrual_request" not in state:
        preview = r.request(admin, "GET", path)
        state["accrual_request"] = {"request_id": str(uuid4()), "approval_hash": preview["approval_hash"],
            "reason": "Reviewed separately confirmed synthetic phone addon", "confirm_accrual": True}
        state["stage"] = "ACCRUAL_SUBMITTING"
        device.save(fixture)
    body = state["accrual_request"]
    r.request(installer, "POST", path, body, expected=403)
    r.request(admin, "POST", path, {**body, "rate": "99.00"}, expected=422)
    receipt = r.request(admin, "POST", path, body)
    assert Decimal(receipt["amount"]) == Decimal(RATE)
    assert r.request(admin, "POST", path, body) == receipt
    r.request(admin, "POST", path, {**body, "request_id": str(uuid4())}, expected=409)
    state.update(receipt=receipt["id"], stage="ACCRUED")
    device.save(fixture)
    verify(r, admin, installer, fixture, state)


def verify(r, admin, installer, fixture, state):
    if state["stage"] != "ACCRUED":
        raise RuntimeError("Addon has not been accrued")
    assert_ledger(ledger(r, admin), state, fixture, accrued=True)
    check = {"events": [], "price_resolution_checks": [EVENT_ID]}
    expected = [{"client_event_id": EVENT_ID, "ok": True, "applied": False, "error": None}]
    assert r.request(installer, "POST", "/installer/sync", check)["acks"] == expected
    assert r.request(installer, "POST", "/installer/sync", check)["acks"] == expected
    assert r.request(admin, "GET", "/admin/price-lists/state")["active_price"]["price_list_id"] == fixture["price"]
    assert len(r.request(admin, "GET", f'/admin/price-lists/{fixture["price"]}')["items"]) == 1
    day = datetime.fromisoformat(state["performed_at"]).astimezone(r.ZoneInfo("Asia/Jerusalem")).date().isoformat()
    earnings = r.request(installer, "GET", f"/installer/earnings/summary?period=day&date={day}")
    assert Decimal(earnings["total"]) == Decimal("18.02")
    assert_ledger(ledger(r, admin), state, fixture, accrued=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=["observe", "review", "accrue", "verify"])
    stage = parser.parse_args().stage
    import work_price_runtime as r
    url = r.make_url(r.settings.DATABASE_URL)
    device.validate_environment(app_env=os.environ.get("APP_ENV"), db_host=url.host, database=url.database,
                                smtp_host=r.settings.SMTP_HOST, whatsapp=r.settings.WHATSAPP_ENABLED,
                                public_url=r.settings.PUBLIC_APP_BASE_URL)
    r.API = "http://127.0.0.1:8000/api/v1"
    r.import_all_orm_models()
    fixture = json.loads(device.SESSION.read_text(encoding="utf-8"))
    device.assert_fixture(r, fixture)
    with r.httpx.Client(timeout=60) as admin, r.httpx.Client(timeout=60) as installer, \
            r.httpx.Client(timeout=60) as public, r.httpx.Client(timeout=15) as mail:
        device.login(r, admin, fixture, "owner")
        state = observe(r, admin, fixture)
        if stage != "observe":
            device.login(r, installer, fixture, "installer")
        if stage == "review":
            review(r, admin, installer, public, mail, fixture, state)
        elif stage == "accrue":
            accrue(r, admin, installer, fixture, state)
        elif stage == "verify":
            verify(r, admin, installer, fixture, state)
        print(json.dumps({"stage": state["stage"], "event": EVENT_ID,
                          "phone_queue_and_ui_require_separate_inspection": True}))


if __name__ == "__main__":
    main()
