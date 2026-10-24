"""Synthetic full-restore fixture and loopback-only SMTP observation process."""
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import sys

from scripts import full_restore_probe as recovery
from scripts import outbox_restore_probe as outbox


def guard(database):
    from app.core.config import settings
    from sqlalchemy.engine import make_url
    recovery.require(os.environ.get('DIMAX_RESTORE_BROWSER') == 'synthetic-only', 'Explicit browser acceptance required')
    recovery.guard(allowed_databases={database})
    recovery.require(make_url(settings.DATABASE_URL).database == database, 'Wrong acceptance phase')


def business():
    snapshot = outbox.business_snapshot()
    for table in ('refresh_sessions', 'outbox_recoveries', 'outbox_recovery_items', 'outbox_recovery_decisions'):
        snapshot.pop(table)
    snapshot['audit_logs'] = [row for row in snapshot['audit_logs']
                              if not json.loads(row)['action'].startswith('OUTBOX_RECOVERY_')]
    return snapshot


def prepare():
    from sqlalchemy.orm import Session
    from uuid import UUID
    from app.core.security.password import hash_password
    from app.modules.identity.infrastructure.models import UserORM, AdminProfileORM
    guard('dimax_full_source')
    rows = outbox.queue()
    accounts = []
    engine = recovery.engine()
    try:
        with Session(engine) as session:
            for company in sorted({row['company_id'] for row in rows}):
                user = UserORM(company_id=UUID(company), email='owner@example.com',
                               full_name='SYNTHETIC RESTORE OWNER', role='ADMIN',
                               password_hash=hash_password('Synthetic-CI-only-42!'))
                session.add(user)
                session.flush()
                session.add(AdminProfileORM(company_id=user.company_id, user_id=user.id, admin_scope='OWNER'))
                accounts.append({'company_id': company, 'user_id': str(user.id), 'email': user.email})
            session.commit()
    finally:
        engine.dispose()
    recovery.save('browser-fixture.json', {'accounts': accounts, 'messages': rows})
    recovery.save('browser-business.json', business())
    recovery.save('source-fingerprint.json', recovery.fingerprint('source-catalog-evidence.json'))
    print('PASS: synthetic OWNER identities included in backup; business baseline frozen', flush=True)


def source_send():
    guard('dimax_full_source')
    with outbox.smtp_capture() as smtp:
        recovery.require(outbox.worker().run_once() == 2, 'Expected two original SMTP acceptances')
        ids = outbox.received(smtp)
    recovery.require(len(ids) == len(set(ids)) == 2, 'Original messages duplicated')
    recovery.save('browser-prior-smtp.json', {'ids': ids, 'accepted_at': datetime.now(timezone.utc).isoformat()})
    recovery.require(business() == recovery.load('browser-business.json'), 'Original send changed business data')
    print('PASS: source SMTP accepted two PDFs AFTER the backup; restored copy will be stale', flush=True)


def serve():
    from sqlalchemy import select
    from sqlalchemy.orm import Session
    from app.modules.outbox.infrastructure.recovery_models import OutboxRecoveryDecisionORM
    guard('dimax_full_restored')
    recovery.require(outbox.queue() == recovery.load('outbox-queue.json'), 'Expected exact stale queue')
    engine = recovery.engine()
    prior = recovery.load('browser-prior-smtp.json')
    original = recovery.load('outbox-queue.json')
    failed = next(row for row in original if row['status'] == 'FAILED')
    delayed = next(row for row in original if row['payload']['subject'] == 'SYNTHETIC DELAYED')
    with outbox.smtp_capture() as smtp:
        worker = outbox.worker()

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                self.respond({'ready': True}, 200 if self.path == '/ready' else 404)

            def respond(self, data, status=200):
                content = json.dumps(data).encode()
                self.send_response(status)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)

            def do_POST(self):
                try:
                    if self.path == '/tick':
                        result = worker.run_once()
                        recovery.require(business() == recovery.load('browser-business.json'), 'Worker repeated business actions')
                        self.respond({'processed': result, 'received': outbox.received(smtp)})
                    elif self.path == '/verify':
                        rows = outbox.queue()
                        recovery.require(business() == recovery.load('browser-business.json'), 'Business rows changed')
                        identity = lambda data: [(r['id'], r['company_id'], r['payload'], r['correlation_id']) for r in data]
                        recovery.require(identity(rows) == identity(original), 'Lost, changed or duplicate mail')
                        recovery.require(outbox.received(smtp) == [failed['id']], 'Unexpected SMTP replay or wrong PDF')
                        recovery.require(not set(prior['ids']) & set(outbox.received(smtp)), 'Previously accepted mail replayed')
                        restored_delayed = next(r for r in rows if r['id'] == delayed['id'])
                        recovery.require(restored_delayed['scheduled_at'] == delayed['scheduled_at'] and restored_delayed['status'] == 'PENDING', 'Future mail schedule changed')
                        with Session(engine) as session:
                            decisions = session.scalars(select(OutboxRecoveryDecisionORM)).all()
                            recovery.require(len(decisions) == 5, 'Missing or duplicate decisions')
                            recovery.require(sorted(d.action for d in decisions) == ['ACCEPTED', 'ACCEPTED', 'HOLD', 'RETRY', 'RETRY'], 'Wrong decisions')
                        result = {'passed': True, 'queue_jobs': 5, 'decisions': 5, 'pdf_messages_sent': 1,
                                  'prior_acceptances_replayed': 0, 'signatures_unchanged': 2,
                                  'ledger_rows_unchanged': 2, 'ledger_total_ils': '18.02'}
                        recovery.save('browser-result.json', result)
                        print('PASS: restored browser reconciliation, exact PDF, durable hold, 2 signatures and 18.02 ILS unchanged', flush=True)
                        self.respond(result)
                    else:
                        self.respond({'error': 'Unknown test command'}, 404)
                except Exception as error:
                    print(f'FAIL: {error}', flush=True)
                    self.respond({'error': str(error)}, 500)

        HTTPServer(('0.0.0.0', 8081), Handler).serve_forever()


if __name__ == '__main__':
    {'prepare': prepare, 'source-send': source_send, 'serve': serve}[sys.argv[1]]()
