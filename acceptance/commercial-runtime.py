"""Synthetic deployed acceptance. Refuses any non-disposable database."""
from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timezone
from decimal import Decimal
import json
import os
from pathlib import Path
import secrets
import sys
from uuid import UUID, uuid4

import httpx
from sqlalchemy import text
from sqlalchemy.engine import make_url

from app.core.config import settings
from app.core.security.password import hash_password
from app.modules.addons.infrastructure.models import AddonTypeORM
from app.modules.companies.infrastructure.models import CompanyPlanORM
from app.modules.door_types.infrastructure.models import DoorTypeORM
from app.modules.doors.infrastructure.models import DoorORM
from app.modules.earnings.infrastructure.models import CompletedWorkORM
from app.modules.identity.infrastructure.models import AdminProfileORM, CompanyORM, UserORM
from app.modules.installers.infrastructure.models import InstallerORM, InstallerProfileORM
from app.modules.projects.infrastructure.models import ProjectORM
from app.modules.rates.infrastructure.models import InstallerRateORM
from app.shared.infrastructure.db.model_registry import import_all_orm_models
from app.shared.infrastructure.db.session import SessionLocal

PROOF = Path('/proof')
API = 'http://127.0.0.1:8000/api/v1'
CONTRACTS = '/admin/accounting/contracts'
FINANCIAL_TABLES = (
    'installer_rates', 'completed_work', 'client_price_snapshots',
    'factory_price_lists', 'factory_price_list_items', 'doors',
)


def guard():
    url = make_url(settings.DATABASE_URL)
    if (os.environ.get('APP_ENV') != 'test' or url.host != 'db'
            or url.database != 'dimax_commercial_runtime_tests'
            or settings.EMAIL_ENABLED or settings.WHATSAPP_ENABLED or settings.AI_ENABLED):
        raise RuntimeError('Only isolated commercial acceptance is permitted')
    import_all_orm_models()
    with SessionLocal() as db:
        assert db.scalar(text('SELECT current_database()')) == url.database
        assert db.scalar(text('SELECT version_num FROM alembic_version')) == '0085_commercial_terms'


def snapshot(db):
    # Fixed table allowlist; compare row contents, not merely counts or totals.
    return {table: dict(db.execute(text(
        'SELECT count(*) AS count, md5(COALESCE(string_agg(row_to_json(t)::text, '
        "E'\\n' ORDER BY row_to_json(t)::text), '')) AS digest FROM " + table + ' t'
    )).mappings().one()) for table in FINANCIAL_TABLES}


def seed():
    password = secrets.token_urlsafe(24)
    users = {}
    with SessionLocal.begin() as db:
        assert db.query(CompanyORM).count() == 0, 'Refusing an existing database'
        company = CompanyORM(name='Commercial Acceptance A', is_active=True)
        foreign = CompanyORM(name='Commercial Acceptance B', is_active=True)
        db.add_all([company, foreign])
        db.flush()
        for tenant in (company, foreign):
            db.add(CompanyPlanORM(company_id=tenant.id, plan_code='acceptance', currency='ILS', is_active=True))
        for scope in ('OWNER', 'OPERATIONS', 'FINANCE', 'VIEWER', 'INSTALLER', 'FOREIGN'):
            cid = foreign.id if scope == 'FOREIGN' else company.id
            user = UserORM(company_id=cid, email=scope.lower() + '@commercial.example.com',
                           full_name='Synthetic ' + scope, role='INSTALLER' if scope == 'INSTALLER' else 'ADMIN',
                           password_hash=hash_password(password), status='ACTIVE', is_active=True)
            db.add(user)
            db.flush()
            if scope != 'INSTALLER':
                db.add(AdminProfileORM(company_id=cid, user_id=user.id,
                    admin_scope='OWNER' if scope == 'FOREIGN' else scope, can_view_rates=True))
            users[scope] = {'id': str(user.id), 'company_id': str(cid), 'email': user.email}
        installer = InstallerORM(company_id=company.id, user_id=UUID(users['INSTALLER']['id']),
                                 full_name='Synthetic Installer', is_active=True)
        project = ProjectORM(company_id=company.id, name='Commercial acceptance only', address='Synthetic test site', status='OK')
        door_type = DoorTypeORM(company_id=company.id, code='COMM-EN', name='Acceptance entrance', is_active=True)
        addon = AddonTypeORM(company_id=company.id, name='Acceptance adjustment', unit='hour', is_active=True)
        foreign_type = DoorTypeORM(company_id=foreign.id, code='COMM-B', name='Foreign type', is_active=True)
        db.add_all([installer, project, door_type, addon, foreign_type])
        db.flush()
        db.add(InstallerProfileORM(company_id=company.id, user_id=installer.user_id,
                                  installer_id=installer.id, display_name='Synthetic Installer', language='en'))
        door = DoorORM(company_id=company.id, project_id=project.id, door_type_id=door_type.id,
                       installer_id=installer.id, unit_label='SYNTHETIC-101', status='INSTALLED', version=1,
                       our_price=Decimal('500'), is_locked=False)
        db.add(door)
        db.flush()
        db.add(InstallerRateORM(company_id=company.id, installer_id=installer.id, door_type_id=door_type.id,
                                effective_from=datetime(2026, 1, 1, tzinfo=timezone.utc), price=Decimal('250')))
        db.add(CompletedWorkORM(company_id=company.id, project_id=project.id, door_id=door.id,
            installer_id=installer.id, completed_at=datetime(2026, 10, 1, tzinfo=timezone.utc),
            quantity=Decimal('1'), rate_snapshot=Decimal('250'), amount_snapshot=Decimal('250'),
            work_kind='DOOR', entry_type='ORIGINAL'))
        fixture = {'kind': 'dimax-commercial-runtime', 'password': password, 'users': users,
                   'door_type': str(door_type.id), 'addon': str(addon.id), 'foreign_type': str(foreign_type.id)}
    with SessionLocal() as db:
        fixture['baseline'] = snapshot(db)
    (PROOF / 'private-session.json').write_text(json.dumps(fixture), encoding='utf-8')
    print('PASS: fresh synthetic fixture; nonzero installer rate/earning baseline; no working data')


def request(client, method, path, body=None, expected=200):
    response = client.request(method, API + path, json=body)
    assert response.status_code == expected, f'{method} {path}: expected {expected}, got {response.status_code}'
    return response.json() if response.content else None


def login(client, fixture, scope):
    actor = fixture['users'][scope]
    result = request(client, 'POST', '/auth/login', {
        'company_id': actor['company_id'], 'email': actor['email'],
        'password': fixture['password'], 'device_id': 'commercial-runtime-' + scope,
    })
    client.headers['Authorization'] = 'Bearer ' + result['access_token']


def verify(persisted=False):
    fixture = json.loads((PROOF / 'private-session.json').read_text())
    browser = json.loads((PROOF / 'browser-proof.json').read_text())
    terms = json.loads((PROOF / 'terms-proof.json').read_text()) if (PROOF / 'terms-proof.json').exists() else None
    terms_path = CONTRACTS + '/' + browser['contract']['id'] + '/terms'
    assert fixture['kind'] == 'dimax-commercial-runtime'
    path = CONTRACTS + '/' + browser['contract']['id'] + '/prices'
    with httpx.Client(timeout=30) as owner:
        login(owner, fixture, 'OWNER')
        rows = request(owner, 'GET', CONTRACTS)
        assert rows['total'] == 1 and rows['items'][0] == browser['contract']
        if terms:
            assert request(owner, 'GET', terms_path)['total'] == 2
            for row in terms['versions']:
                assert request(owner, 'GET', terms_path + '/' + row['id']) == row
                assert row['is_demo'] and not row['factory_confirmed'] and not row['usable_for_billing']
        for price in browser['prices']:
            assert request(owner, 'GET', path + '/' + price['id']) == price
            assert price['is_demo'] and price['status'] == 'DRAFT'
            assert not price['factory_confirmed'] and not price['usable_for_billing']
        if not persisted:
            checks = []
            for scope in ('OPERATIONS', 'FINANCE', 'VIEWER', 'INSTALLER'):
                with httpx.Client(timeout=30) as other:
                    login(other, fixture, scope)
                    request(other, 'GET', CONTRACTS, expected=403)
                    request(other, 'GET', path, expected=403)
                    request(other, 'POST', CONTRACTS, browser['contract_body'], expected=403)
                    request(other, 'POST', path, browser['price_bodies'][0], expected=403)
                    if terms:
                        request(other, 'GET', terms_path, expected=403)
                        request(other, 'GET', terms_path + '/' + terms['versions'][0]['id'], expected=403)
                        request(other, 'POST', terms_path, terms['bodies'][0], expected=403)
                checks.append(scope)
            assert request(owner, 'POST', CONTRACTS, browser['contract_body']) == browser['contract']
            for body, price in zip(browser['price_bodies'], browser['prices']):
                assert request(owner, 'POST', path, body) == price
            stale = deepcopy(browser['price_bodies'][1])
            stale['request_id'] = str(uuid4())
            request(owner, 'POST', path, stale, expected=409)
            invalid = deepcopy(stale)
            invalid['expected_latest_version'] = 3
            invalid['items'][0]['target_id'] = fixture['foreign_type']
            request(owner, 'POST', path, invalid, expected=422)
            request(owner, 'PATCH', path + '/' + browser['prices'][0]['id'], {}, expected=405)
            request(owner, 'POST', path + '/' + browser['prices'][0]['id'] + '/activate', {}, expected=404)
            assert request(owner, 'POST', path, browser['race_body']) == browser['race_price']
            if terms:
                for body, row in zip(terms['bodies'], terms['versions']):
                    assert request(owner, 'POST', terms_path, body) == row
                stale_terms = {**terms['bodies'][1], 'request_id': str(uuid4())}
                request(owner, 'POST', terms_path, stale_terms, expected=409)
            with SessionLocal.begin() as db:
                db.execute(text("UPDATE admin_profiles SET admin_scope='VIEWER' WHERE user_id=:id"),
                           {'id': fixture['users']['OWNER']['id']})
            try:
                request(owner, 'GET', CONTRACTS, expected=403)
                request(owner, 'POST', path, browser['race_body'], expected=403)
            finally:
                with SessionLocal.begin() as db:
                    db.execute(text("UPDATE admin_profiles SET admin_scope='OWNER' WHERE user_id=:id"),
                               {'id': fixture['users']['OWNER']['id']})
            with httpx.Client(timeout=30) as anonymous:
                assert anonymous.get(API + CONTRACTS).status_code in (401, 403)
            print('PASS: real JWT roles, replay, stale version, foreign catalog, immutable API, live revocation')
        else:
            # A separate phase after the planned API restart keeps the normal
            # five-logins-per-IP limit intact; no test bypass or setting change.
            with httpx.Client(timeout=30) as other:
                login(other, fixture, 'FOREIGN')
                assert request(other, 'GET', CONTRACTS)['total'] == 0
                request(other, 'GET', path, expected=404)
                request(other, 'GET', path + '/' + browser['prices'][0]['id'], expected=404)
                request(other, 'POST', path, browser['price_bodies'][0], expected=404)
                if terms:
                    request(other, 'GET', terms_path, expected=404)
                    request(other, 'GET', terms_path + '/' + terms['versions'][0]['id'], expected=404)
                    request(other, 'POST', terms_path, terms['bodies'][0], expected=404)
            print('PASS: foreign OWNER cannot read or write another company contract')
        assert request(owner, 'GET', path)['total'] == 3
        assert request(owner, 'GET', path + '/' + browser['race_price']['id']) == browser['race_price']
        for price in browser['prices']:
            assert request(owner, 'GET', path + '/' + price['id']) == price
    with SessionLocal() as db:
        assert snapshot(db) == fixture['baseline'], 'Installer finance or door data changed'
        counts = db.execute(text('SELECT entity_type, count(*) FROM audit_logs '
                                 "WHERE entity_type LIKE 'COMMERCIAL_%' GROUP BY entity_type ORDER BY entity_type")).all()
        assert counts == [('COMMERCIAL_CONTRACT', 1), ('COMMERCIAL_PRICE', 3)] + ([('COMMERCIAL_TERMS', 2)] if terms else [])
        print('Commercial audit counts:', counts)
    print('PASS: stored snapshots and nonzero installer financial baseline unchanged' + (' after API restart' if persisted else ''))


if __name__ == '__main__':
    guard()
    {'seed': seed, 'verify': verify, 'persisted': lambda: verify(True)}[sys.argv[1]]()
