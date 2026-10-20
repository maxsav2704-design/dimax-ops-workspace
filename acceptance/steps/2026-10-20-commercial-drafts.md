# Commercial contract and price drafts

Status: first backend preparation increment completed and tested in isolated
PostgreSQL. This is not an activated accounting or billing system.

Backend commit: `11a92c9` on `codex/release-hardening-20260908`, local only.
No GitHub push or working-database migration was performed.

## Scope and business boundaries

Factory-to-DIMAX commercial prices are separate from the existing installer
`factory_price_lists`. Installer rates, earnings, work status, journal signatures,
payments and sync were not changed.

OWNER can prepare a contract draft and append price draft versions. This initial
OWNER-only restriction is conservative; the detailed accounting permission
matrix remains a later decision. Every request rechecks active membership,
company and OWNER scope within its transaction.

Draft lines can describe full installation, named stages or add-on work, using
existing tenant-scoped catalog types. Catalog names and units are snapshotted.
ILS amounts exclude VAT and use bounded Decimal values, including explicit zero.
Full installation and stages are catalog alternatives: this API does not choose
an execution plan or grant simultaneous full and stage billing.

The database permits only DRAFT. Responses report `factory_confirmed=false` and
`usable_for_billing=false`. There are no activate, approve, edit or delete routes.
`proposed_from` is a requested date, not an effective-price selector.
There is no admin UI or mobile exposure in this increment.

Invented prices exist only in a synthetic test fixture:
full installation 400.00 ILS; proposed stages 150.00, 200.00 and 50.00 ILS;
additional adjustment 60.00 ILS/hour. These are not negotiated or market prices.
APP_ENV=test creates contracts with durable `is_demo=true`; clients cannot set
or remove the flag. No production seed/import of these prices was implemented.
Future activation and exports must enforce this marker.

## Implementation

- `backend/app/modules/accounting`: models, scoped repository, application DTOs
  and service, five OWNER-only API operations and module README.
- `backend/alembic/versions/0084_commercial_drafts.py`: contracts, versions and
  lines; tenant/version uniqueness, relational constraints and bounded amounts.
- `backend/app/api/v1/routers.py`: narrow router registration.
- `backend/app/shared/infrastructure/db/model_registry.py`: model registration.
- `backend/tests/integration/test_commercial_drafts.py`: 42 new test cases.
- `backend/tests/fixtures/commercial_demo_prices.json`: synthetic commercial
  terms only, with no user identities, secrets or real customer data.
- `DIMAX_FACTORY_ACCOUNTING_SPEC.md`: consolidated decisions, current-code map,
  implementation sequence and the explicit test-only commercial-price rule.
- `acceptance/references/brand/.gitattributes`: keep supplied PDF/PNG branding
  binary, preventing text conversion of the original artwork.

UoW owns commit/rollback. Company locking serializes writes; expected version
checks reject stale edits. Request UUIDs bind canonical payload fingerprints:
replays are safe, altered payloads conflict. Audit writes share the transaction,
so audit failure cannot leave a saved draft behind.

## Confirmed by tests

Runtime: `dimax-backend-workspace:local`, PostgreSQL 16 in a temporary container,
isolated network and tmpfs database named `dimax_commercial_tests`; APP_ENV=test.
No test database port was published and no persistent volume was created.

The migration chain upgraded a fresh database through 0084 successfully.
The first regression command passed 90 tests in 406.63 seconds:

```text
python -m pytest -q \
  tests/integration/test_commercial_drafts.py \
  tests/integration/test_factory_price_lists_api.py \
  tests/integration/test_openapi_contract.py \
  tests/architecture/test_module_structure.py \
  tests/architecture/test_transaction_boundary.py
```

Five real-JWT cases were then added and passed separately in 9.53 seconds:

```text
python -m pytest -q tests/integration/test_commercial_drafts.py -k real_jwt_authority
```

Total: 95 distinct passing cases, including 42 for commercial drafts.
Covered: OWNER/OPERATIONS/FINANCE/VIEWER/INSTALLER, access revocation with the
same token, tenant isolation and foreign catalogs, inactive companies/catalogs,
immutable API snapshots, invalid amounts/fields, idempotency, concurrent writes,
audit rollback, non-promotion of drafts, existing installer price API regression,
OpenAPI responses and architecture transaction boundaries.

Migration round trip after tests:

```text
alembic downgrade 0083_import_inbox
alembic upgrade head
alembic current
```

Inspection confirmed all three commercial tables absent after downgrade and
present after re-upgrade. Final head: `0084_commercial_drafts`.
`git diff --cached --check` passed before the backend commit.

## Integration prerequisites and remaining gates

0084 follows `0083_import_inbox`, the other agent's current uncommitted work.
That predecessor was included in the isolated runtime checks but deliberately
excluded from this commit. Before integration, preserve and commit its valid
migration chain with its owner; do not deploy 0084 from a checkout missing 0083.

Not checked in a live browser or phone: no frontend/mobile changes were made.
No full backend suite, admin build or mobile release run was claimed for this
bounded backend increment. No real factory agreement, signature, email, tax
document or payment was created. External infrastructure is not needed for
draft preparation but remains required for real external delivery.

Next: admin contract/price preparation UI with clear draft/demo states, existing
RU/EN/HE conventions and API integration tests. Then legal factory identity and
contract terms, project-specific agreed exceptions and the separate commercial
approval/effective-date flow. Only after those gates should work allocations,
claims, opening balances and accountant packages use these terms.

Accounting launch remains November 10, 2026 in Asia/Jerusalem; opening amounts
must be reconciled with the factory and approved by OWNER, disputes separately.

## Cleanup and collaboration

Removed the test runner, temporary PostgreSQL container, isolated Docker network,
4,357,120-byte source archive and disposable verification script. The test DB
used tmpfs and left no volume. Normal DIMAX services were not stopped.

Other-agent AI/import-inbox changes, compose files and admin working-tree changes
were neither reverted nor included in the backend commit. Shared registration
files contain only this module's narrow additions.
