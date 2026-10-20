# Commercial contract and price draft UI

Status: implemented; focused tests, production build and five browser scenarios
passed. This increment prepares drafts, not an activated accounting system.

Admin commit: `fb5a9ba` on `codex/release-hardening-20260908`, local only.

## Scope

The OWNER-only `/factory-accounting` page is a separate navigation entry from
the existing `/price-lists` installer remuneration workflow. It uses the five
commercial draft API operations introduced by backend commit `11a92c9`.

- Paginated contract selection, immutable version selection and line snapshots.
- Contract preparation with factory name, reference and reason.
- New commercial price versions copied from a selected draft or prepared empty.
- Full installation, installation stages and additional work, using existing
  tenant catalog items; stage codes and duplicate rows are validated.
- Decimal strings in ILS excluding VAT; explicit zero is valid, blank is not.
- Expected-latest-version concurrency checks and request UUIDs on writes.
- Unknown write results lock the form and retry the identical request; 409
  requires refreshing instead of silently replacing another user's version.
- OWNER guard, isolated session query cache, abort on unmount, stale-data/error
  handling, unavailable-catalog guard and unsaved-change confirmation.
- RU/EN/HE copy, RTL, shared DIMAX typography/colors/status components, labelled
  controls and responsive dialogs/tables. No new visual library or dependency.

The UI sends no installer rate, company ID, confirmation, demo flag or billing
status. The server remains authoritative. Draft/demo/not-confirmed/not-billable
states are explicit. No approval, activation, editing/deletion of saved
versions, billing, journal, payment or mobile behavior is introduced.

Full installation and stage prices remain alternatives, not a sum. The proposed
date is not an effective date. Synthetic fixture prices are never automatically
inserted into a working company or treated as negotiated terms.

## Verification

Focused Vitest run: 80 passed across the new UI/helper, module access, sidebar
and RequireAuth tests. Existing PriceListsPage regression: 24 passed separately.
New UI coverage includes all non-OWNER scopes, contract switching/pagination,
catalog failure, zero/stage/addon payloads, duplicate rows, exact ambiguous-write
replay, 403/409 handling, auth loss, dirty-form closure and RU/HE text.

ESLint on all changed source/test files passed. Existing type-scale, RTL,
local-copy and unlabeled-control ratchets: four passed.

Final workspace `npx tsc --noEmit -p tsconfig.json` passed. Production
`node node_modules/next/dist/bin/next build --webpack` passed in a separate
source snapshot, including Next's TypeScript check and all 29 static pages.
The first sandbox build failed on Google Fonts DNS and a directory permission;
the retry with permitted font access succeeded without changing font sources.

Playwright: five passed in 1.0 minute, with one Edge worker:

```text
node node_modules/@playwright/test/cli.js test e2e/commercial-drafts.spec.ts \
  --workers=1 --output=test-results/commercial-ui-20261020
```

Verified RU at 1440px, HE at 768px and EN at 390px, dialogs within the viewport,
horizontal overflow, runtime errors, Escape/overlay cleanup, contract creation,
two successive immutable price versions and unavailable-backend behavior.
Screenshots of the desktop page, RTL editor and narrow-screen price table were
visually inspected. Initial browser failures were ambiguous test locators
(region/select and Next route-announcer/alert); selectors were corrected and
all five cases rerun successfully, without weakening their assertions.

Browser tests use intercepted synthetic HTTP responses, not a live database.
They are intentionally distinct from the 95 backend/PostgreSQL cases recorded
in `2026-10-20-commercial-drafts.md`; those backend tests were not rerun here.

## Deployment and remaining boundaries

The normal database was not migrated and normal services were not stopped.
0084 depends on the other agent's uncommitted `0083_import_inbox`. Integration
must preserve and commit that predecessor before deploying the new API. A page
without the new API displays an unavailable-service state and disables writes;
it does not fabricate an empty contract list.

Next accounting increments remain contract identity/terms, project exceptions,
commercial confirmation and effective dates, then eligible work allocations,
claims, reconciled OWNER-approved opening balances and accountant packages.
The agreed launch remains 2026-11-10 in Asia/Jerusalem. This UI does not claim
these later processes are complete.

## Collaboration

Only this increment's explicit paths may be committed. Other-agent import-inbox,
OperationsPage, configuration and test changes are preserved. No backend,
mobile, installer earnings, working data or external recipient was changed.
No GitHub push is part of this increment.

## Local preview and cleanup

The isolated build is served at `http://127.0.0.1:4192/factory-accounting`, bound
to loopback. It uses the ordinary API origin `http://127.0.0.1:8000`; outside the
automated tests it requires a real OWNER session and the deployed draft API.
The preview is not a fixture-backed operational system.

Snapshot: `.tmp/commercial-ui-20261020`, with a junction to the existing admin
node_modules, no copied .env or secrets. Source configuration, original .next
and existing services were preserved. Retained one runtime build and small
test screenshots; removed its disposable build cache (342,073,139 bytes).
Never recursively delete through the node_modules junction during later cleanup.
