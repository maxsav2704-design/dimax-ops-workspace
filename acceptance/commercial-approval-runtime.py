"""Real HTTP approval acceptance, disposable DB and captured mail only."""
import json
import os
import re
import sys
import time
from pathlib import Path
from uuid import uuid4

import httpx
from sqlalchemy import select, text
from sqlalchemy.engine import make_url

import check as base
from app.core.config import settings
from app.modules.accounting.application.approval_email import deliver, KIND, CODE_KIND
from app.modules.accounting.infrastructure.approval_models import CommercialApprovalORM
from app.modules.outbox.infrastructure.models import OutboxMessageORM
from app.shared.infrastructure.db.model_registry import import_all_orm_models
from app.shared.infrastructure.db.session import SessionLocal

PROOF = Path('/proof')
API = 'http://127.0.0.1:8000/api/v1'


def guard():
    url = make_url(settings.DATABASE_URL)
    assert os.environ.get('APP_ENV') == 'test' and url.host == 'db'
    assert url.database == 'dimax_commercial_runtime_tests'
    assert settings.EMAIL_ENABLED and not settings.WHATSAPP_ENABLED and not settings.AI_ENABLED
    assert settings.PUBLIC_APP_BASE_URL == 'https://commercial.example.com'
    assert not Path('/workspace/.env').exists()
    if os.environ.get('DIMAX_COMMERCIAL_MAILPIT') == '1':
        assert settings.SMTP_HOST == 'mailpit' and settings.SMTP_PORT == 1025
        assert not settings.SMTP_TLS and not settings.SMTP_USER and not settings.SMTP_PASSWORD
    import_all_orm_models()
    with SessionLocal() as db:
        assert db.scalar(text('SELECT current_database()')) == url.database
        base.assert_schema_head(db)


def prepare():
    base.seed()
    fixture = json.loads((PROOF / 'private-session.json').read_text())
    with httpx.Client(timeout=90) as client:
        base.login(client, fixture, 'OWNER')
        def post(path, body):
            result = client.post(API + path, json=body)
            assert result.status_code == 200, result.text
            return result.json()
        contract = post(base.CONTRACTS, {'request_id': str(uuid4()), 'factory_name': 'Synthetic factory',
            'reference': 'APPROVAL-TEST-2026', 'reason': 'Isolated confirmation test, no commercial evidence'})
        path = base.CONTRACTS + '/' + contract['id']
        terms = post(path + '/terms', {'request_id': str(uuid4()), 'expected_latest_version': 0,
            'factory_legal_name': 'Synthetic Factory Ltd', 'registration_number': 'TEST-123', 'address': 'Synthetic address',
            'proposed_from': '2026-11-10', 'billing_basis': 'FULL_INSTALLATION',
            'payment_terms': 'Test: 30 calendar days after signed journals', 'retention_terms': 'Test: no retention',
            'reason': 'Isolated acceptance', 'agreement_reference': 'TEST ONLY'})
        price = post(path + '/prices', {'request_id': str(uuid4()), 'expected_latest_version': 0,
            'proposed_from': '2026-11-10', 'reason': 'Invented test prices', 'agreement_reference': 'TEST ONLY',
            'items': [{'kind': 'INSTALLATION', 'target_id': fixture['door_type'], 'unit_price_ex_vat': '400.50'},
                      {'kind': 'ADDON', 'target_id': fixture['addon'], 'unit_price_ex_vat': '60.00'}]})
        post('/admin/price-lists/factory/contact', {'expected_contact_id': None, 'factory_name': 'Synthetic factory',
            'recipient_name': 'Synthetic Representative', 'recipient_email': 'factory@commercial.example.com',
            'authority_reference': 'Synthetic OWNER-approved authority'})
    (PROOF / 'private-approval.json').write_text(json.dumps({'contract': contract, 'terms': terms, 'price': price}))
    print('PASS: synthetic versions prepared through real JWT/API; installer baseline unchanged')


class CaptureSender:
    def send(self, **message):
        self.message = message


def capture(code=False):
    with SessionLocal() as db:
        approval = db.scalar(select(CommercialApprovalORM))
        assert approval is not None and approval.snapshot['is_demo']
        messages = db.scalars(select(OutboxMessageORM).where(OutboxMessageORM.company_id == approval.company_id)
            .order_by(OutboxMessageORM.created_at.desc(), OutboxMessageORM.id.desc())).all()
        kind = CODE_KIND if code else KIND
        msg = next(row for row in messages if row.payload.get('kind') == kind
                   and row.payload.get('approval_id') == str(approval.id))
        pattern = r'Confirmation code: (\d{6})' if code else r'https://commercial.example.com/commercial-approval#([A-Za-z0-9_-]{43})'
        if os.environ.get('DIMAX_COMMERCIAL_MAILPIT') == '1':
            from app.modules.outbox.domain.enums import OutboxStatus
            from app.workers import outbox_worker
            assert outbox_worker.run_once() == 1
            db.refresh(msg)
            assert msg.status == OutboxStatus.SENT and msg.sent_at and not msg.last_error
            received = []
            deadline = time.monotonic() + 15
            with httpx.Client(base_url='http://mailpit:8025/api/v1/', timeout=15) as client:
                while time.monotonic() < deadline:
                    response = client.get('messages?limit=100')
                    response.raise_for_status()
                    for row in response.json()['messages']:
                        if [recipient['Address'] for recipient in row['To']] != ['factory@commercial.example.com']:
                            continue
                        message = client.get('message/' + row['ID'])
                        message.raise_for_status()
                        body = message.json()
                        if re.search(pattern, body['Text']):
                            received.append(body)
                    if received:
                        break
                    time.sleep(0.2)
            assert len(received) == 1, 'Exactly one SMTP message for this step required'
            body_text = received[0]['Text']
            assert 'TEST ONLY' in received[0]['HTML']
        else:
            sender = CaptureSender()
            deliver(msg, sender)
            assert sender.message['to_email'] == 'factory@commercial.example.com'
            body_text = sender.message['body_text']
        assert 'TEST ONLY' in body_text
        if code:
            assert '/commercial-approval#' not in body_text
        value = re.search(pattern, body_text).group(1)
        (PROOF / ('private-code.json' if code else 'private-link.json')).write_text(json.dumps({'code' if code else 'token': value}))
    channel = 'real outbox worker and isolated SMTP mailbox' if os.environ.get('DIMAX_COMMERCIAL_MAILPIT') == '1' else 'local render capture'
    print(f'PASS: encrypted outbox verified through {channel}; no email sent externally')


def verify():
    fixture = json.loads((PROOF / 'private-session.json').read_text())
    saved = json.loads((PROOF / 'private-approval.json').read_text())
    path = base.CONTRACTS + '/' + saved['contract']['id']
    with httpx.Client(timeout=90) as client:
        base.login(client, fixture, 'OWNER')
        result = client.get(API + path + '/approvals')
        assert result.status_code == 200, result.text
        rows = result.json()['items']
        assert len(rows) == 1 and rows[0]['status'] == 'CONFIRMED'
        row = rows[0]
        assert row['terms_id'] == saved['terms']['id'] and row['price_id'] == saved['price']['id']
        assert row['mailbox_verified_at'] and not row['usable_for_billing'] and row['is_demo']
        assert row['agreement_id'] is None
        if os.environ.get('DIMAX_COMMERCIAL_MAILPIT') == '1':
            assert row['delivery_status'] == 'SENT'
        for scope in ('OPERATIONS', 'FINANCE', 'VIEWER', 'INSTALLER', 'FOREIGN'):
            base.login(client, fixture, scope)
            assert client.get(API + path + '/approvals').status_code == (404 if scope == 'FOREIGN' else 403)
        client.headers.clear()
        assert client.get(API + path + '/approvals').status_code == 401
    with SessionLocal() as db:
        assert base.snapshot(db) == fixture['baseline']
        assert db.scalar(text("SELECT count(*) FROM audit_logs WHERE entity_type='COMMERCIAL_APPROVAL' AND action='CONFIRM'")) == 1
    print('PASS: one immutable decision, real JWT roles/tenant isolation, financial row digests unchanged')


if __name__ == '__main__':
    guard()
    {'prepare': prepare, 'link': capture, 'code': lambda: capture(True), 'verify': verify}[sys.argv[1]]()
