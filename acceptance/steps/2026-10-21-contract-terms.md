# Factory legal details and versioned contract terms

Scope: OWNER-only draft preparation. Not factory confirmation, activation,
accounting accrual, journal sign-off or acceptance of a full production release.

## Implementation

- New `commercial_contract_terms` snapshots belong to an existing commercial
  contract and company. Fields: legal name, registration/tax number, address,
  optional contract contact, proposed dates, full-installation/stage billing
  basis, verbatim payment/retention clauses, reason and agreement reference.
- Every saved version records author ID/name and server timestamp. The original
  contract display name/reference and saved price versions are not overwritten.
- Additive GET/POST `/api/v1/admin/accounting/contracts/{contract_id}/terms`
  and GET `.../terms/{terms_id}`. Live OWNER checks, tenant scoping, atomic audit,
  idempotent requests, optimistic version checks and tenant serialization reuse
  the existing commercial service/repository/UoW patterns.
- Migration `0085_commercial_terms` adds constraints and a PostgreSQL trigger
  rejecting UPDATE/DELETE of terms history. There is no backfill, activation,
  editing or deletion endpoint. Database administrators still control schema;
  the trigger is not a substitute for production database privileges/backups.
- Admin uses a separate accessible tab, version selector and immutable detail
  view. New versions copy selected fields but require a new change reason.
  Existing DIMAX dialog, button, status, color and typography primitives remain.
  RU/EN/HE, RTL, keyboard tabs, dirty-close confirmation, conflict and retry
  handling are included. Stale/error responses do not enable writes.

## Business boundaries

- ILS commercial prices exclude VAT. Installer prices/earnings remain separate.
- Period: 10th inclusive until next 10th exclusive, Asia/Jerusalem.
- Contact details are informational, not an OWNER-approved factory authority,
  accountant recipient or automatic email/WhatsApp destination.
- Payment/retention clauses are text, not guessed formulas. Due-date anchors,
  calendar/business-day rules, retention bases/release rules and VAT rounding
  still require the agreed contract/accountant parameters before computation.
- Terms and prices have independent draft histories. Future confirmation must
  bind exact revisions explicitly, never silently attach old prices to new terms.
- Test contracts remain `is_demo=true`, DRAFT, unconfirmed and not billable.
  Working accounts, client files and financial balances were not used as test
  data. The before/after financial comparison below is for the isolated fixture.

## Verification

- Fresh isolated PostgreSQL upgrade through 0085, downgrade to 0084 and upgrade
  back to 0085 passed. Test cleanup left zero companies/contracts/terms.
- New backend integration suite: 30 passed. Existing commercial-price suite:
  42 passed in the combined run. The first combined run had one new-test fixture
  failure (foreign OWNER lacked its scope); fixed without weakening application
  authorization, then reran all 30 new tests successfully.
- UI: 37 tests passed across ContractTerms and FactoryAccountingPage, using
  one fork outside the Windows temporary-file sandbox restriction. Earlier
  attempts hit worker startup timeout / EPERM before executing tests.
- TypeScript and targeted ESLint passed. Four repository checks passed:
  typography, RTL utilities, locale helper and accessible control labels.
- Production `next build --webpack` passed, including TypeScript and page
  generation. An earlier resource-starved build was deliberately interrupted;
  the successful rerun used one worker and a 1536 MB Node heap limit.
- Real Edge/Playwright login against deployed FastAPI/PostgreSQL passed. UI
  created two terms versions; reload and selection of version 1 returned its
  original complete snapshot. Payment/retention clauses were reachable by scroll.
- Real JWT role checks rejected OPERATIONS, FINANCE, VIEWER and INSTALLER.
  Request replay returned existing snapshots; stale versions returned 409.
  The existing concurrent commercial-price check and visible conflict passed.
- After recreating only the test API, a fresh browser login retrieved the same
  terms and prices. A foreign company's OWNER could neither read nor write them.
  Audit remained exactly 1 contract, 3 prices, 2 terms versions.
- Full row hashes/counts of installer_rates, completed_work, client_price_snapshots,
  factory_price_lists, factory_price_list_items and doors remained unchanged,
  including the nonzero 250 ILS installer rate/earned amount, before and after
  API restart. These are synthetic records, not a working-data migration.
- RU desktop, HE RTL dialog at 768px and EN at 390px were visually inspected.
  No horizontal page overflow, stranded modal or browser pageerror was found.
  The EN capture waits for language state and data refresh, avoiding a misleading
  transient screenshot. Screenshots only (about 405 KB) are retained under ignored
  `artifacts/acceptance/commercial-terms-20261021/`.

Local application commits: backend `9a45060`, admin `179de3b`.
The browser harness now accepts `--terms`, including with `--persisted` for
read-only restart verification. Runtime commands, using the clean snapshots
and proof environment described in the previous runtime acceptance report:

```powershell
docker compose -p dimax-terms-20261021 -f acceptance/commercial-runtime.compose.yml run --rm --no-deps -T api python /acceptance/check.py seed
docker compose -p dimax-terms-20261021 -f acceptance/commercial-runtime.compose.yml up -d api gateway
node acceptance/commercial-runtime-browser.mjs --terms
docker compose -p dimax-terms-20261021 -f acceptance/commercial-runtime.compose.yml exec -T api python /acceptance/check.py verify
docker compose -p dimax-terms-20261021 -f acceptance/commercial-runtime.compose.yml up -d --no-deps --force-recreate api
node acceptance/commercial-runtime-browser.mjs --persisted --terms
docker compose -p dimax-terms-20261021 -f acceptance/commercial-runtime.compose.yml exec -T api python /acceptance/check.py persisted
```

## Isolation and deployment

The disposable stand is `dimax-terms-20261021`, database
`dimax_commercial_runtime_tests`, source snapshots under ignored
`.tmp/commercial-terms-20261021`, no .env, no working volumes. External delivery
and AI were disabled. The ordinary DIMAX containers were temporarily stopped
with explicit user approval after resource exhaustion; their identities and
prior state were captured. All eight original containers were subsequently
started again without recreation or removal of their volumes. API `/health`
and `/ready` both returned 200; API and database health were healthy. No
containers/volumes belonging to other projects were modified.

### Important restoration side effect

The ordinary API command, discovered while diagnosing its slow cold start, is
`sh -c alembic upgrade head && uvicorn ...`, with backend sources mounted at
`/app`. Restoring it automatically applied 0084 and 0085 to the ordinary local
database, from its previous 0083 revision. The earlier assumption that this
database's schema would remain unchanged was incorrect, and the user was told.

Read-only verification found head `0085_commercial_terms` and zero contracts,
zero commercial price versions, zero terms versions. Reviewed 0084/0085 contain
additive schema creation, no business-data backfill or earning updates. No test
fixture was copied there and no automatic downgrade was attempted. We did not
capture a before/after hash of the ordinary ledger; the proven nonzero financial
invariance belongs to the isolated tests, not to a claimed production audit.
Future pause/restore procedures must inspect startup commands and bind mounts
before stopping services and explicitly account for migration/backup effects.

The isolated Compose project and its private test credentials are removed after
verification. The temporary source/build copies are removed; dependency junctions
are unlinked first, including the nested standalone junction. Original admin
dependencies and the previous preview on 4192 are left intact. Only four small
visual-check PNGs remain in the ignored artifact directory.

0085 depends on 0084 and the existing, separately owned workspace 0083 migration.
Do not deploy this commit without its predecessors. Other-agent import-inbox/AI
changes are not included in this step. No GitHub publication is performed.

The local Node runtime is 25.5.0, outside package.json's declared 20.x range;
successful local checks do not replace CI in the declared release runtime.
Mobile code is unchanged; a full backend/admin/mobile release gate was not run.

Next accounting block: bind proposed contract/price revisions and implement
their explicit approval/effective selection. Monthly claims, balances, payments,
retentions and accountant exports are not implemented by this increment.
