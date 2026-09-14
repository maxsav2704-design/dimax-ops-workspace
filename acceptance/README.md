# DIMAX release acceptance, 2026-09-09

## Baseline

Branch in all repositories: `codex/release-hardening-20260908`.
Clean starting trees: workspace `d7025b4`, backend `697a1d0`, admin `51fa91d`,
mobile `c17810e`. Historical results are context, not current acceptance.

Criteria and weights were frozen in `criteria.json` before this run.
Each criterion is counted once per applicable scope. Functional verification,
live demonstration and production acceptance are separate scores, not averages.
Missing results mean NOT TESTED. A test suite is not a replacement for a UI run.
An open P0/P1 blocks approval regardless of percentage.

## Isolation

`docker-compose.acceptance.yml` uses a separate Docker project, network, database,
storage volume, test JWT secret and local Mailpit. No working .env is inherited.
API, workers, database, storage and Mailpit stay on an internal Docker network
without an external delivery path. Mailpit does not relay. Only the stateless
Caddy gateway joins the ingress network and publishes loopback-only HTTP ports.
This avoids relying on host port publication from an internal-only network on
Docker Desktop. The gateway has no credentials, SMTP route or forward-proxy route.
API: `http://localhost:8001`; admin: `http://localhost:4173`;
captured email: `http://localhost:8026`.

Run `docker compose -f docker-compose.acceptance.yml up -d --wait --wait-timeout 360 db minio mailpit api gateway`.
This full-stack command requires a separate resource check first. Do not run it
alongside native builds on the current 4 GB host.
Never use the normal workspace seed or business smoke against the working company.
Never reset working volumes or use global Docker cleanup. Keep automated fixtures
in database `dimax_acceptance_tests`, separate from UI demo `dimax_acceptance`.
Outbox worker is opt-in and restricted to this isolated environment.
The gateway waits for API `/ready`, including a database query. A running process
alone is not readiness; verify host `http://127.0.0.1:8001/ready` as well.
Gateway service discovery uses Docker's IPv4 resolver with a 30-second cache;
it does not pin a container IP. After container recreation, allow this cache to
refresh before diagnosing the new address. Its four-second idle connection limit
is below Uvicorn's five-second default. Proxy write retries remain disabled.
Gateway transport errors preserve their HTTP failure status and allow browsers
to read the JSON from the two configured admin origins; this does not replace
API authorization or restrict non-browser clients.
After a lost write response, read the saved state before repeating the action.

Run the disposable gateway regression with existing local images and Node 20:

```powershell
$env:DIMAX_GATEWAY_CHECK = "1"
node --test scripts/acceptance-gateway.test.mjs
Remove-Item Env:DIMAX_GATEWAY_CHECK
```

The test uses its own labelled internal network, fake HTTP API and loopback proxy.
It never joins the acceptance application network or mounts a database. It covers
lost-response non-replay, origin restrictions, validation and outage recovery.
It removes its containers and network in `finally`; after an interrupted process,
inspect resources with label `dimax.acceptance.gateway-check` and remove only
the confirmed run's resources. Never substitute a global Docker prune.

Test account addresses use the reserved example domain `example.com`, because
the real login validator rejects `.test`. SMTP remains confined to Mailpit;
no external delivery is authorized. Bootstrap updates only the known legacy
fixture addresses in the isolated database, preserving account and rate IDs.

## Constrained Local Checks

The September 10 resource check found 8.48 GiB free on C but only about 230 MiB
free physical RAM. During the sequential test run, free disk space decreased to
3.88 GiB. This host has NOT passed a full release-build resource preflight.
Do not delete installed dependencies, SDKs, Docker volumes or project data to
force a build. Use the existing GitHub quality gates for full source checks.

For a narrow backend regression only, the API/check container is capped at
384 MiB and one CPU, with no extra swap. PostgreSQL is capped at 256 MiB with
32 MiB shared buffers and 30 connections. Run just one check container at a time:

```powershell
docker compose -f docker-compose.acceptance.yml up -d --no-deps --wait db
docker compose -f docker-compose.acceptance.yml exec -T db psql -U postgres -d dimax_acceptance_tests -c "SELECT current_database(), version_num FROM alembic_version;"
docker compose -f docker-compose.acceptance.yml run --rm --no-deps -T -e PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 -e PYTHONDONTWRITEBYTECODE=1 -e DATABASE_URL=postgresql+psycopg2://postgres:postgres@db:5432/dimax_acceptance_tests -e TEST_DATABASE_URL=postgresql+psycopg2://postgres:postgres@db:5432/dimax_acceptance_tests api timeout --kill-after=10s 300s python -m pytest -q -p no:cacheprovider tests/integration/test_installer_phase2_api.py tests/integration/test_earnings_corrections_api.py tests/integration/test_financial_integrity_constraints.py tests/integration/test_calendar_api.py --tb=short
docker compose -f docker-compose.acceptance.yml stop db
```

These commands require the separate `dimax_acceptance_tests` database migrated
to head. On a new acceptance volume, create that database using `createdb` in
the acceptance `db` container, then run `alembic upgrade head` with the same
DATABASE_URL override. Never substitute the normal workspace database. Inspect
each command's exit code; a timeout, interrupted or killed run is not PASS.
Stop the test database even after a failed run, preserving its volume.

The full backend gate is `.github/workflows/backend-tests.yml` in the backend
repository. Admin and mobile use their existing `frontend-quality-gate.yml` and
`mobile-quality-gate.yml`. Record exact revisions: remote checks do not certify
uncommitted local files, a physical phone, or external delivery.

UI actions, their expected outcomes and evidence will be recorded in `REPORT.md`.
Generated screenshots, PDFs, workbooks and command logs belong in ignored
`artifacts/acceptance-20260909/`, never secrets or actual customer data.

## Admin Acceptance Preview

The frontend `Acceptance Preview` workflow builds the real admin source with
`NEXT_PUBLIC_API_BASE_URL=http://localhost:8001` and
`NEXT_DIST_DIR=.next-acceptance-preview`. Download its `acceptance-preview` artifact
into that directory inside the frontend repository. Verify `SOURCE_COMMIT`
matches the workflow revision. The artifact omits caches and Linux dependency
copies; local locked Windows dependencies run `next start --port 4173` with the
same `NEXT_DIST_DIR`. Keep this separate from the working admin on port 5173.
Next emits its standalone/start recommendation; this is a local acceptance
preview, not the production deployment procedure.

Use `http://127.0.0.1:4173/login` when binding Next to `127.0.0.1`. Both localhost
and IPv4 origins are permitted by the isolated API. Do not point this preview at
the working API or reuse production accounts.

Control workbooks contain synthetic data only:
- `valid-9-doors.xlsx`: 8 input rows, 9 doors, 5 entrance and 4 fire doors,
  2 buildings, total `our_price` 9800 ILS; same apartment may contain
  different doors. One row expands to two physical doors.
- `invalid-rows.xlsx`: one valid door, its duplicate, fractional quantity 1.5,
  negative price and unknown type. Disable automatic type creation and do not
  authorize partial import when checking atomic rejection.

The seeded door-type codes are lowercase, matching the production catalog and
file importer. Stable synthetic IDs and rate IDs remain unchanged on reruns.
Installer rates are 250 ILS per door; they are independent of workbook prices.

## Inventory

| Area | Roles | Actions/data | Verification |
| --- | --- | --- | --- |
| Auth | All | Login, refresh, logout, account status; identity API | Real login + API failure/revocation tests |
| Dashboard | Admin scopes | Totals, issues, navigation; dashboard/reports API | Reconcile independent scenario totals |
| Projects/doors | OWNER, OPERATIONS, VIEWER read | Forms, import preview/commit/history, floor matrix, list, filters, selection, assignments | UI with synthetic Excel, API/DB reconciliation, 580-door run |
| Installers/rates/catalogs | Scope-dependent | Users, installers, type/library/reason/addon catalogs, prices | Role matrix, edits, historical-rate checks |
| Calendar | Admin/installer | Date/mode navigation, search/filter, event dialog and assignments | UI actions + timezone API tests |
| Issues | Admin/installer | Report, read, assign/resolve, related doors/projects | UI + no false completion/accrual |
| Mobile | INSTALLER | Projects, door execution, addons, calendar, issues, earnings, journal, queue/profile | Source/tests first; native/device evidence separately |
| Earnings/reports | OWNER, FINANCE, permitted readers | Ledger, correction/reversal, project/installer totals, exports | Independent arithmetic, direct permissions, UI |
| Journal/documents | Authorized admin/installer/public token | Drafts, completed items, PDF, test confirmation, delivery | UI, PDF page inspection, local email attachment |
| Operations/settings | Authorized scopes | Audit, sync health, outbox, retry, settings | UI status/action verification, scope API tests |

This inventory is a map, not a claim that every action passed. Detailed action
coverage and unsupported environments must be recorded with explicit statuses.
