"""Staged acceptance of a PHONE-created command, never a simulated mobile event.

Run inside the isolated acceptance API container, alongside work_price_runtime.py.
The private session stays in /tmp and must never be committed or printed.
No existing company/account, price, queue or earning is changed.
"""
from __future__ import annotations

import argparse
import json
import os
import secrets
from decimal import Decimal
from pathlib import Path
from uuid import UUID, uuid4


COMPANY_NAME = "DIMAX Device Price Acceptance 20261015"
PUBLIC_URL = "https://dimax-device.example.test"
SESSION = Path("/tmp/dimax-device-price.json")


def validate_environment(*, app_env, db_host, database, smtp_host, whatsapp, public_url):
    if (app_env != "test" or db_host != "db" or database != "dimax_acceptance"
            or smtp_host != "mailpit" or whatsapp or public_url != PUBLIC_URL):
        raise RuntimeError("Only the isolated device acceptance configuration is permitted")


def require_phone_event(items, fixture):
    matches = [item for item in items if item.get("project_id") == fixture["project"]
               and item.get("event_type") == "DOOR_SET_STATUS"
               and item.get("installer_id") == fixture["installer"]
               and item.get("source") == "sync_event"
               and item.get("payload", {}).get("door_id") == fixture["door"]
               and item.get("payload", {}).get("status") == "INSTALLED"]
    if len(matches) != 1:
        raise RuntimeError("Expected exactly one retained phone door command; no command was created")
    return matches[0]


def save(fixture):
    # Only random test credentials. Never emit the session in normal tool output.
    SESSION.write_text(json.dumps(fixture), encoding="utf-8")
    SESSION.chmod(0o600)


def login(r, client, fixture, role):
    response = r.request(client, "POST", "/auth/login", {
        "company_id": fixture["company"], "email": fixture[role + "_email"],
        "password": fixture["password"], "device_id": "device-price-acceptance-admin",
    })
    client.headers["Authorization"] = "Bearer " + response["access_token"]


def seed(r):
    if SESSION.exists():
        raise RuntimeError("Session already exists; refusing another preparation")
    r.import_all_orm_models()
    with r.SessionLocal.begin() as db:
        if db.query(r.CompanyORM).filter_by(name=COMPANY_NAME).first():
            raise RuntimeError("Device fixture already exists; refusing duplicate/reset")
        company = r.CompanyORM(name=COMPANY_NAME, is_active=True)
        db.add(company)
        db.flush()
        cid = company.id
        password = secrets.token_hex(16)
        db.add(r.CompanyPlanORM(company_id=cid, plan_code="acceptance", currency="ILS", is_active=True))
        owner = r.UserORM(company_id=cid, email="owner.device@example.com", full_name="Device Test Owner",
                          role="ADMIN", password_hash=r.hash_password(password), status="ACTIVE", is_active=True)
        user = r.UserORM(company_id=cid, email="installer.device@example.com", full_name="Device Test Installer",
                         role="INSTALLER", password_hash=r.hash_password(password), status="ACTIVE", is_active=True)
        db.add_all([owner, user])
        db.flush()
        db.add(r.AdminProfileORM(company_id=cid, user_id=owner.id, admin_scope="OWNER", can_view_rates=True,
                                 can_manage_imports=True, can_manage_users=True))
        installer = r.InstallerORM(company_id=cid, user_id=user.id, full_name=user.full_name, is_active=True)
        project = r.ProjectORM(company_id=cid, name="Device price acceptance", address="Synthetic test only", status="OK")
        priced = r.DoorTypeORM(company_id=cid, code="entrance", name="Priced entrance", is_active=True)
        db.add_all([installer, project, priced])
        db.flush()
        db.add(r.InstallerProfileORM(company_id=cid, user_id=user.id, installer_id=installer.id,
                                     display_name=user.full_name, language="ru", is_active=True))
        fixture = {"company": str(cid), "password": password, "owner_email": owner.email,
                   "installer_email": user.email, "project": str(project.id),
                   "installer": str(installer.id), "priced_type": str(priced.id), "stage": "SEEDED"}
        save(fixture)
    return fixture


def prepare(r, admin, public, mail):
    fixture = seed(r)
    login(r, admin, fixture, "owner")
    contact = r.request(admin, "POST", "/admin/price-lists/factory/contact", {
        "expected_contact_id": None, "factory_name": "Device Test Factory",
        "recipient_name": "Runtime Factory Representative", "recipient_email": "factory.runtime@example.com",
        "authority_reference": "Synthetic device acceptance only; Mailpit capture",
    })
    fixture["contact"] = contact["id"]
    price = r.request(admin, "POST", "/admin/price-lists", {"request_id": str(uuid4()),
        "expected_latest_version": 0, "reason": "Synthetic device acceptance initial terms",
        "agreement_reference": "Device acceptance only", "items": [
            {"kind": "DOOR", "target_id": fixture["priced_type"], "installer_price": "250.00"}]})
    fixture["price"] = price["id"]
    save(fixture)
    before = r.mailbox_ids(mail)
    r.request(admin, "POST", f'/admin/price-lists/{price["id"]}/approvals', {
        "factory_name": "Device Test Factory", "recipient_name": "Runtime Factory Representative",
        "recipient_email": "factory.runtime@example.com", "send_email": True})
    token = r.receive(mail, before, r"/price-approval#([A-Za-z0-9_-]{43})")
    r.confirm(public, mail, token)
    r.request(admin, "POST", f'/admin/price-lists/{price["id"]}/activate', {
        "request_id": str(uuid4()), "expected_active_price_list_id": None,
        "reason": "Reviewed synthetic device transition", "reviewed_transition": True})
    r.seed_new_work(fixture)
    fixture["stage"] = "AWAITING_PHONE_COMMAND"
    save(fixture)
    return {"stage": fixture["stage"], "company": fixture["company"], "project": fixture["project"],
            "door": fixture["door"], "work_reference": "RUNTIME-101", "physical_phone_verified": False}


def assert_fixture(r, fixture):
    with r.SessionLocal() as db:
        company = db.get(r.CompanyORM, UUID(fixture["company"]))
        if not company or company.name != COMPANY_NAME:
            raise RuntimeError("Private session does not identify the owned synthetic fixture")


def review(r, admin, public, mail, fixture):
    if fixture["stage"] != "AWAITING_PHONE_COMMAND":
        raise RuntimeError("Proposal stage already started; inspect saved state instead of replaying")
    problems = r.request(admin, "GET", "/admin/sync/problems?status=price_conflict")["items"]
    row = require_phone_event(problems, fixture)
    path = f'/admin/sync/price-conflicts/sync_event/{row["id"]}/work-price-proposals'
    preview = r.request(admin, "POST", path + "/review", {})
    proposal = r.request(admin, "POST", path, {"request_id": str(uuid4()),
        "review_token": preview["review_token"], "rate": "9.01",
        "reason": "Missing rate in synthetic device work", "agreement_reference": "Device test agreement",
        "execution_evidence": "Supervised physical-device acceptance; new assigned RUNTIME-101 door; no real work",
        "confirm_execution_evidence": True})
    fixture.update(event=row["client_event_id"], proposal=proposal["id"], stage="PROPOSED")
    save(fixture)
    before = r.mailbox_ids(mail)
    invitation = r.request(admin, "POST", f'/admin/sync/work-price-proposals/{proposal["id"]}/invitations', {
        "request_id": str(uuid4()), "factory_contact_id": fixture["contact"], "proposal_hash": proposal["snapshot_hash"]})
    fixture["approval"] = invitation["id"]
    save(fixture)
    token = r.receive(mail, before, r"/work-price-approval#([A-Za-z0-9_-]{43})")
    r.confirm(public, mail, token, work=True)
    if r.request(admin, "GET", "/admin/earnings/ledger")["items"]:
        raise AssertionError("Factory confirmation must not accrue earnings")
    fixture["stage"] = "CONFIRMED_WITHOUT_EARNINGS"
    save(fixture)
    return {"stage": fixture["stage"], "ledger_rows": 0, "event": fixture["event"]}


def accrue(r, admin, fixture):
    if fixture["stage"] not in {"CONFIRMED_WITHOUT_EARNINGS", "ACCRUAL_SUBMITTING"}:
        raise RuntimeError("Work must be confirmed first")
    path = f'/admin/sync/work-price-approvals/{fixture["approval"]}/accrual'
    if "accrual_request" not in fixture:
        preview = r.request(admin, "GET", path)
        fixture["accrual_request"] = {"request_id": str(uuid4()), "approval_hash": preview["approval_hash"],
            "reason": "Device test administrator checked the exact factory decision", "confirm_accrual": True}
        fixture["stage"] = "ACCRUAL_SUBMITTING"
        save(fixture)
    receipt = r.request(admin, "POST", path, fixture["accrual_request"])
    assert Decimal(receipt["amount"]) == Decimal("9.01")
    assert r.request(admin, "POST", path, fixture["accrual_request"]) == receipt
    fixture.update(receipt=receipt["id"], stage="ACCRUED_AWAITING_PHONE_ACK")
    save(fixture)
    return {"stage": fixture["stage"], "amount": "9.01", "duplicate_accrual": False}


def verify(r, admin, fixture):
    ledger = r.request(admin, "GET", "/admin/earnings/ledger")["items"]
    assert len(ledger) == 1 and Decimal(ledger[0]["amount_snapshot"]) == Decimal("9.01")
    assert ledger[0]["work_price"] and not ledger[0]["can_correct"]
    assert r.request(admin, "GET", "/admin/price-lists/state")["active_price"]["price_list_id"] == fixture["price"]
    assert len(r.request(admin, "GET", f'/admin/price-lists/{fixture["price"]}')["items"]) == 1
    return {"ledger_rows": 1, "amount": "9.01", "company_price_unchanged": True,
            "phone_ui_and_sqlite_require_separate_inspection": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=["prepare", "review", "accrue", "verify"])
    args = parser.parse_args()
    import work_price_runtime as r
    url = r.make_url(r.settings.DATABASE_URL)
    validate_environment(app_env=os.environ.get("APP_ENV"), db_host=url.host, database=url.database,
                         smtp_host=r.settings.SMTP_HOST, whatsapp=r.settings.WHATSAPP_ENABLED,
                         public_url=r.settings.PUBLIC_APP_BASE_URL)
    r.API = "http://127.0.0.1:8000/api/v1"
    r.import_all_orm_models()
    with r.httpx.Client(timeout=60) as admin, r.httpx.Client(timeout=60) as public, r.httpx.Client(timeout=15) as mail:
        if args.stage == "prepare":
            result = prepare(r, admin, public, mail)
        else:
            fixture = json.loads(SESSION.read_text(encoding="utf-8"))
            assert_fixture(r, fixture)
            login(r, admin, fixture, "owner")
            result = (review(r, admin, public, mail, fixture) if args.stage == "review" else
                      accrue(r, admin, fixture) if args.stage == "accrue" else verify(r, admin, fixture))
        print(json.dumps(result))


if __name__ == "__main__":
    main()
