# Commercial contracts and prices: isolated runtime acceptance

Status: live browser, security and restart checks passed. This accepts the draft
workflow, not operational accounting.

## Scope and isolation

- Backend `11a92c9`, admin `fb5a9ba`; local source snapshots include the existing
  uncommitted import-inbox dependency. No application code changed in this step.
- Standalone Compose project `dimax-commercial-20261021`, never combined with
  working Compose files. PostgreSQL database `dimax_commercial_runtime_tests`
  uses tmpfs and has no published port or working volume.
- API source is mounted read-only, with no .env. API/database are on an internal
  network. A separate Caddy gateway exposes only `127.0.0.1:8003`.
- An independent Next development snapshot on `127.0.0.1:4194` calls that API.
  Existing admin builds, working services and databases are not changed.
- Email, WhatsApp, AI and external webhooks are disabled. No delivery workers
  run in this stand. Only two synthetic companies and invented terms are used.
- Random test credentials stay in an ignored temporary proof directory; no
  tokens, passwords, real accounts or customer files belong in the commit.

## Verified against real PostgreSQL and HTTP

1. Fresh Alembic upgrade through `0084_commercial_drafts` succeeded, including
   `0083_import_inbox`. This was not a migration of the working database.
2. Normal browser login, JWT authentication and OWNER access succeeded. No
   fake API responses, auth overrides or direct database commercial writes.
3. UI created a contract and two immutable price versions: installation
   400.50 then 410.00 ILS, stage FRAME 150.00, addon 60.00, all excluding VAT.
   Input `400,50` was correctly normalized. Catalog names/units came from API.
4. Two simultaneous real HTTP writers at version 2 produced exactly one
   success and one 409. The stale UI editor showed the conflict, disabled
   saving and closed through the unsaved-draft confirmation.
5. Browser reload retrieved three versions from the server. Selecting the
   original version returned its exact original snapshot. RU screenshot was
   visually inspected; fields/table were readable and no blocking overlay
   remained. No browser pageerror or API request to a working origin occurred.
6. Real OPERATIONS, FINANCE, VIEWER and INSTALLER tokens received 403 on
   contract/price list and create operations. Anonymous access was rejected.
   Demoting only the synthetic OWNER blocked its already-issued token; the
   test restored its role in a finally block.
7. Exact request replay returned the same contract/price, without duplicates.
   Stale versions returned 409; foreign catalog IDs returned 422; editing a
   saved version returned 405; an activation endpoint was not available (404).
8. All prices remained DRAFT, demo, unconfirmed and not usable for billing.
   Audit counts were exactly one commercial contract and three price versions.
9. Full row-content hashes and counts of installer_rates, completed_work,
   client_price_snapshots, factory_price_lists, factory_price_list_items and
   doors remained unchanged. Baseline included a real synthetic 250 ILS
   installer rate and 250 ILS completed-work entry, not just empty tables.
10. The source-snapshot .env guard was exercised with a synthetic sentinel:
    container exited 1 before starting the API. No real .env was read.

11. API was recreated without recreating PostgreSQL. A second normal browser
    login/reload and the server-side persistence check passed. The foreign
    company's OWNER saw an empty own list and received 404 for reading/writing
    the first company's contract. All three snapshots, audit counts and
    financial baseline hashes were unchanged after restart.

## Reproduction

New tracked harness files: `acceptance/commercial-runtime.compose.yml`,
`commercial-runtime.Caddyfile`, `commercial-runtime.py`,
`commercial-runtime-browser.mjs`. Existing local images were used; no pulls.

Prepare a new ignored `.tmp` directory. Copy backend app/alembic/tests Python
and JSON source, scripts Python source and alembic.ini, without .env, uploads,
databases or credentials. Include scripts: runtime_guard imports them. Copy
admin app/src/public plus package manifests and existing Next/TS/Tailwind/
PostCSS/proxy configuration. Reuse installed dependencies with a junction,
not a second node_modules copy. Never recursively delete through that junction.

Set DIMAX_COMMERCIAL_SOURCE to the backend snapshot and DIMAX_COMMERCIAL_PROOF
to a fresh proof directory. Every Compose command must explicitly use:

```text
docker compose -p dimax-commercial-20261021 -f acceptance/commercial-runtime.compose.yml
```

Run `up -d db --no-build --pull never`, then `run --rm --no-deps -T api alembic
upgrade head`, then `run --rm --no-deps -T api python /acceptance/check.py seed`.
Start API/gateway with `up -d --no-build --pull never`. Start the separate admin
snapshot with NEXT_PUBLIC_API_BASE_URL=http://127.0.0.1:8003 and
`node node_modules/next/dist/bin/next dev --webpack -H 127.0.0.1 -p 4194`.

```text
node acceptance/commercial-runtime-browser.mjs
# Compose prefix above:
exec -T api python /acceptance/check.py verify
up -d api --force-recreate --no-build --pull never
# Wait for /ready at 8003, then:
exec -T api python /acceptance/check.py persisted
node acceptance/commercial-runtime-browser.mjs --persisted
```

Do not rerun seed against existing data. Login throttling stays enabled; the
five role logins and post-restart checks are intentionally separate phases.
The browser uses Playwright/Edge from existing admin dependencies and only
continues real API requests to the disposable origin; it never fulfills mocks.

## Honest limitations

- This turn used a development UI snapshot, not a second production build.
  Earlier production build and mocked UI/unit suites are recorded separately
  in `2026-10-20-commercial-drafts-ui.md` and were not rerun here.
- Initial harness attempts exposed a missing fixture address, omitted scripts
  in the snapshot, Docker Desktop internal-network port publishing, and slow
  cold startup. Fixture/snapshot/gateway setup and bounded test waits were
  corrected. Failed pre-write browser attempts made no commercial records.
  The first post-restart browser attempt timed out on the auth loading screen
  during simultaneous server checks; the separate rerun, explicitly waiting
  for the page before its version selector, passed. No assertions were removed.
- Next dev logged a non-fatal script nonce hydration warning on login. This
  step does not claim a globally warning-free admin or a performance pass.
- 0084 depends on another agent's still-uncommitted 0083. Its exact tested SHA256:
  `34c4d9a3e15972b57ea7512f837fc9e55d5cb70f9e2ca7342be34bb7cb41b84c`.
  Commit/reconcile that predecessor before any working deployment.
- Contract legal identity/terms, project exceptions, factory confirmation,
  effective dates, billing allocations, claims, opening balances and accountant
  packages remain later increments. A proposed date never activates a draft.
  Full installation and stage prices are alternatives, never additive earnings.
- No mobile behavior, installer rates, actual earnings, external recipients,
  working account or production deployment was changed. No GitHub push.

## Cleanup and handoff

Compose down removed the three disposable containers and both networks; a
project-label query confirmed zero remaining containers. The tmpfs database
was destroyed. The isolated Next process tree was stopped and port 4194 had
no listener. Working DIMAX containers remained up for 11 hours, with API and
PostgreSQL healthy; none were restarted by this acceptance.

After removing only the dependency junction, deleted the validated temporary
snapshot directory: 1,108 files, 104,051,374 bytes, including generated test
credentials, synthetic request payloads, logs and Next cache. Original admin
node_modules remained intact. Retained two inspected screenshots (289,356
bytes total) under ignored `artifacts/acceptance/commercial-runtime-20261021/`.

Only the four harness files and this report belong to this increment's local
commit. Other-agent import-inbox/configuration changes remain untouched.
The next business increment is contract identity and versioned terms before
project-specific commercial exceptions or any actual billing activation.
