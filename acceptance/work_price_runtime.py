"""Real HTTP/SMTP acceptance; only fixture creation touches the disposable DB."""
from __future__ import annotations

import json
import os
import re
import secrets
import time
from datetime import datetime, timezone
from decimal import Decimal
from email import policy
from email.parser import BytesParser
from pathlib import Path
from uuid import UUID, uuid4
from zoneinfo import ZoneInfo

import httpx
from sqlalchemy import text
from sqlalchemy.engine import make_url

from app.core.config import settings
from app.core.security.password import hash_password
from app.modules.addons.infrastructure.models import AddonTypeORM
from app.modules.companies.infrastructure.models import CompanyPlanORM
from app.modules.door_types.infrastructure.models import DoorTypeORM
from app.modules.doors.infrastructure.models import DoorORM
from app.modules.identity.infrastructure.models import AdminProfileORM, CompanyORM, UserORM
from app.modules.installers.infrastructure.models import InstallerORM, InstallerProfileORM
from app.modules.projects.infrastructure.models import ProjectORM
from app.modules.reasons.infrastructure.models import ReasonORM
from app.shared.infrastructure.db.session import SessionLocal
from app.shared.infrastructure.db.model_registry import import_all_orm_models


def seed():
    url = make_url(settings.DATABASE_URL)
    if (os.environ.get("APP_ENV") != "test" or url.host != "db"
            or url.database != "dimax_work_price_runtime_tests"
            or settings.SMTP_HOST != "mailpit" or settings.WHATSAPP_ENABLED):
        raise RuntimeError("Only the disposable runtime acceptance environment is permitted")
    password = secrets.token_urlsafe(24)
    import_all_orm_models()
    with SessionLocal.begin() as db:
        assert db.execute(text("SELECT current_database()")).scalar_one() == url.database
        assert db.query(CompanyORM).count() == 0, "Refusing an existing database"
        company = CompanyORM(name="DIMAX Runtime Acceptance", is_active=True)
        db.add(company)
        db.flush()
        cid = company.id
        db.add(CompanyPlanORM(company_id=cid, plan_code="acceptance", currency="ILS", is_active=True))
        owner = UserORM(company_id=cid, email="owner.runtime@example.com", full_name="Runtime Owner",
                        role="ADMIN", password_hash=hash_password(password), status="ACTIVE", is_active=True)
        worker = UserORM(company_id=cid, email="installer.runtime@example.com", full_name="Runtime Installer",
                         role="INSTALLER", password_hash=hash_password(password), status="ACTIVE", is_active=True)
        db.add_all([owner, worker])
        db.flush()
        db.add(AdminProfileORM(company_id=cid, user_id=owner.id, admin_scope="OWNER", can_view_rates=True,
                               can_manage_imports=True, can_manage_users=True))
        installer = InstallerORM(company_id=cid, user_id=worker.id, full_name="Runtime Installer", is_active=True)
        project = ProjectORM(company_id=cid, name="Runtime acceptance site", address="Test only", status="OK")
        priced = DoorTypeORM(company_id=cid, code="entrance", name="Priced entrance", is_active=True)
        reason = ReasonORM(company_id=cid, code="runtime_cancel", name="Runtime cancellation", is_active=True)
        db.add_all([installer, project, priced, reason])
        db.flush()
        db.add(InstallerProfileORM(company_id=cid, user_id=worker.id, installer_id=installer.id,
                                  display_name="Runtime Installer", language="en", is_active=True))
        return {"company": str(cid), "password": password, "owner_email": owner.email,
                "installer_email": worker.email, "project": str(project.id), "installer": str(installer.id),
                "priced_type": str(priced.id), "reason": str(reason.id)}


def seed_new_work(fixture):
    # New catalog entries appear after activation; incomplete initial lists must remain blocked.
    with SessionLocal.begin() as db:
        cid = UUID(fixture["company"])
        unpriced = DoorTypeORM(company_id=cid, code="fire", name="Unpriced fire door", is_active=True)
        addon = AddonTypeORM(company_id=cid, name="Runtime adjustment", unit="pcs", is_active=True)
        db.add_all([unpriced, addon])
        db.flush()
        door = DoorORM(company_id=cid, project_id=UUID(fixture["project"]), door_type_id=unpriced.id,
                       installer_id=UUID(fixture["installer"]), unit_label="RUNTIME-101", status="IN_PROGRESS",
                       version=0, our_price=Decimal("500"), is_locked=False)
        db.add(door)
        db.flush()
        fixture.update(door=str(door.id), addon=str(addon.id))


API = "http://api:8000/api/v1"
MAIL = "http://mailpit:8025/api/v1"


def request(client, method, path, body=None, expected=200):
    response = client.request(method, API + path, json=body)
    # Do not log tokens, mailbox codes or authentication response bodies on failure.
    assert response.status_code == expected, f"{method} {path}: expected {expected}, got {response.status_code}"
    return response.json() if response.content else None


def mailbox_ids(client):
    response = client.get(MAIL + "/messages?limit=100")
    response.raise_for_status()
    return {row["ID"] for row in response.json()["messages"]}


def receive(client, before, pattern):
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline:
        for ident in mailbox_ids(client) - before:
            raw = client.get(MAIL + f"/message/{ident}/raw")
            raw.raise_for_status()
            message = BytesParser(policy=policy.default).parsebytes(raw.content)
            assert "factory.runtime@example.com" in str(message["To"])
            body = message.get_body(preferencelist=("plain",)) if message.is_multipart() else message
            match = re.search(pattern, body.get_content())
            if match:
                return match.group(1)
        time.sleep(0.5)
    raise AssertionError("Expected invitation/code did not arrive through deployed SMTP worker")


def confirm(public, mail, token, work=False):
    path = "/public/price-approvals" + ("/work" if work else "")
    preview = request(public, "POST", path + "/preview", {"token": token})
    before = mailbox_ids(mail)
    request(public, "POST", path + "/request-code", {"token": token})
    code = receive(mail, before, r"Confirmation code: ([0-9]{6})")
    result = request(public, "POST", path + "/confirm", {"token": token,
        "expected_version": preview["version"], "snapshot_hash": preview["snapshot_hash"],
        "signer_name": "Runtime Factory Representative", "accepted": True, "verification_code": code})
    assert result["status"] == "CONFIRMED" and result["affects_earnings"] is False
    return result


def main():
    fixture = seed()
    with httpx.Client(timeout=30) as admin, httpx.Client(timeout=30) as installer, \
            httpx.Client(timeout=30) as public, httpx.Client(timeout=10) as mail:
        for client, email in ((admin, fixture["owner_email"]), (installer, fixture["installer_email"])):
            login = request(client, "POST", "/auth/login", {"company_id": fixture["company"],
                "email": email, "password": fixture["password"], "device_id": "runtime-acceptance"})
            client.headers["Authorization"] = "Bearer " + login["access_token"]
        contact = request(admin, "POST", "/admin/price-lists/factory/contact", {"expected_contact_id": None,
            "factory_name": "Runtime Factory", "recipient_name": "Runtime Factory Representative",
            "recipient_email": "factory.runtime@example.com", "authority_reference": "Isolated acceptance authorization"})
        price = request(admin, "POST", "/admin/price-lists", {"request_id": str(uuid4()),
            "expected_latest_version": 0, "reason": "Initial runtime factory offer",
            "agreement_reference": "Runtime agreement", "items": [{"kind": "DOOR",
                "target_id": fixture["priced_type"], "installer_price": "250.00"}]})
        before = mailbox_ids(mail)
        request(admin, "POST", f'/admin/price-lists/{price["id"]}/approvals', {
            "factory_name": "Runtime Factory", "recipient_name": "Runtime Factory Representative",
            "recipient_email": "factory.runtime@example.com", "send_email": True})
        token = receive(mail, before, r"/price-approval#([A-Za-z0-9_-]{43})")
        confirm(public, mail, token)
        request(admin, "POST", f'/admin/price-lists/{price["id"]}/activate', {"request_id": str(uuid4()),
            "expected_active_price_list_id": None, "reason": "Reviewed runtime transition", "reviewed_transition": True})
        seed_new_work(fixture)
        proofs = []
        total = Decimal("0")
        for kind, amount in (("DOOR", "9.01"), ("ADDON", "13.52")):
            event_id = str(uuid4())
            at = datetime.now(timezone.utc)
            payload = ({"door_id": fixture["door"], "status": "INSTALLED", "base_version": 0}
                       if kind == "DOOR" else {"addon_type_id": fixture["addon"], "qty_done": "1.50"})
            event = {"client_event_id": event_id, "project_id": fixture["project"],
                     "type": "DOOR_SET_STATUS" if kind == "DOOR" else "ADDON_FACT_CREATE",
                     "happened_at": at.isoformat(), "payload": payload}
            queued = request(installer, "POST", "/installer/sync", {"device_id": "runtime-offline", "events": [event]})
            assert queued["acks"][0]["error"] == "CONFLICT_FACTORY_PRICE"
            problems = request(admin, "GET", "/admin/sync/problems?status=price_conflict")["items"]
            row = next(item for item in problems if item["client_event_id"] == event_id)
            proposals = f'/admin/sync/price-conflicts/sync_event/{row["id"]}/work-price-proposals'
            review = request(admin, "POST", proposals + "/review", {})
            proposal = request(admin, "POST", proposals, {"request_id": str(uuid4()),
                "review_token": review["review_token"], "rate": "9.01",
                "reason": "Missing rate for recorded runtime work", "agreement_reference": "Runtime factory discussion",
                "execution_evidence": "Runtime site record with execution and assignment verified",
                "confirm_execution_evidence": True})
            before = mailbox_ids(mail)
            invitation = request(admin, "POST", f'/admin/sync/work-price-proposals/{proposal["id"]}/invitations', {
                "request_id": str(uuid4()), "factory_contact_id": contact["id"], "proposal_hash": proposal["snapshot_hash"]})
            token = receive(mail, before, r"/work-price-approval#([A-Za-z0-9_-]{43})")
            accrual = f'/admin/sync/work-price-approvals/{invitation["id"]}/accrual'
            request(admin, "GET", accrual, expected=409)
            confirm(public, mail, token, work=True)
            ledger = request(admin, "GET", "/admin/earnings/ledger")["items"]
            assert sum(Decimal(item["amount_snapshot"]) for item in ledger) == total
            check = {"events": [], "price_resolution_checks": [event_id]}
            assert request(installer, "POST", "/installer/sync", check)["acks"] == []
            preview = request(admin, "GET", accrual)
            body = {"request_id": str(uuid4()), "approval_hash": preview["approval_hash"],
                    "reason": "Runtime administrator verified factory decision", "confirm_accrual": True}
            request(installer, "POST", accrual, body, expected=403)
            receipt = request(admin, "POST", accrual, body)
            assert Decimal(receipt["amount"]) == Decimal(amount)
            assert request(admin, "POST", accrual, body) == receipt
            request(admin, "POST", accrual, {**body, "request_id": str(uuid4())}, expected=409)
            ack = request(installer, "POST", "/installer/sync", check)["acks"]
            assert ack == [{"client_event_id": event_id, "ok": True, "applied": False, "error": None}]
            replay = request(installer, "POST", "/installer/sync", {"events": [event]})
            assert replay["acks"][0]["ok"] is True
            total += Decimal(amount)
            day = at.astimezone(ZoneInfo("Asia/Jerusalem")).date().isoformat()
            earnings = request(installer, "GET", f"/installer/earnings/summary?period=day&date={day}")
            assert Decimal(earnings["total"]) == total
            proofs.append({"kind": kind, "amount": amount, "receipt": receipt["id"]})
        original = request(admin, "GET", "/admin/earnings/ledger")["items"]
        assert len(original) == 2 and all(item["work_price"] and not item["can_correct"] for item in original)
        request(admin, "POST", f'/admin/doors/{fixture["door"]}/override', {"new_status": "NOT_INSTALLED",
            "reason_id": fixture["reason"], "override_reason": "Runtime exact cancellation check"})
        ledger = request(admin, "GET", "/admin/earnings/ledger")["items"]
        assert len(ledger) == 3 and sum(Decimal(item["amount_snapshot"]) for item in ledger) == Decimal("13.52")
        assert all(item["work_price"] for item in ledger)
        assert request(admin, "GET", "/admin/price-lists/state")["active_price"]["price_list_id"] == price["id"]
        assert len(request(admin, "GET", f'/admin/price-lists/{price["id"]}')["items"]) == 1
        proof = {"status": "PASS", "transport": "real HTTP and SMTP; deployed worker; no mocks",
                 "external_https_verified": False, "physical_phone_verified": False,
                 "work": proofs, "ledger_rows_after_reversal": 3, "net_after_reversal": "13.52"}
        Path("/proof/result.json").write_text(json.dumps(proof, indent=2), encoding="utf-8")
        session_file = Path("/proof/private-session.json")
        session_file.write_text(json.dumps(fixture), encoding="utf-8")
        session_file.chmod(0o600)
        print(json.dumps(proof))


if __name__ == "__main__":
    main()
