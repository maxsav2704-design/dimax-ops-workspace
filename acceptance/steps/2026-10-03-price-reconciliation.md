# Legacy Price Reconciliation

## Scope And Architecture

This step implements the inspection needed before moving legacy per-installer
and per-project prices to the common factory price list. The rates module's
existing authorization, SQLAlchemy unit of work and price-list repository are
reused. Routers validate filters and authorize the tenant; an application service
builds DTOs; the repository runs a dedicated SQL query. There is no commit,
business mutation, automatic settlement or activation in this report.

Two additive authenticated GET endpoints are available:

- `/api/v1/admin/price-lists/reconciliation`: company inventory before any draft.
- `/api/v1/admin/price-lists/{price_list_id}/reconciliation`: compare existing
  prices with one selected version, including a cancelled historical version.

OWNER/OPERATIONS/FINANCE require rate access. VIEWER, installers and users without
rate access are denied. Company scope comes from the session, not request input;
a known price-list ID from another company returns 404. Invalid filters return
422. Existing mutation APIs remain unchanged. No schema migration is needed:
the report reads existing 0063/0064 and legacy business tables.

## Implemented

- Latest effective installer rates, separate future rates, pending doors with
  saved snapshots or current fallback rates, and installer surcharges rounded
  with the existing completion rules. Installed doors are not repriced.
- Separate project add-on plan prices, catalog defaults for reference, and saved
  add-on facts without a ledger entry. Unpriced/unplanned facts remain visible;
  facts already represented in earnings stay in historical totals only.
- Distinct positive current prices per work type, excluding inactive parents,
  scheduled rates, reference defaults and unaccrued facts. A matching operative
  row still requires review if other current prices for that work differ.
- Missing factory/current prices, unavailable catalog/parents, renamed catalog
  entries and changed units. Unit mismatches do not produce a monetary delta.
  Malformed cross-tenant references never reveal foreign names; an unknown
  add-on unit is shown as unknown rather than guessed.
- One SQL statement returns company-wide totals and the filtered page in the
  same snapshot, including empty/out-of-range pages. Historical earning and
  urgency-charge counts are separate; deltas are not summed into a fake payable
  amount. Pagination, work-kind and review-only filters are server-side.
- Admin comparison dialog in RU/EN/HE with RTL, compact totals, readable source
  details, contained horizontal table scrolling and a reachable close/pager.
  Loading, empty, access/error and explicit refresh/retry states are present.
  Failed refresh hides stale rows. Financial data uses the existing isolated
  workspace query cache and is removed on account change.
- The action is available to a read-only finance user and before the first
  draft. It sends GET requests only. Existing create/invite/cancel/revoke flows
  are retained. No rate editing, factory impersonation or installer input was
  introduced.

## Verification

- Final PostgreSQL regression: **199 passed**, exit 0, 354.06 seconds. Covers the
  26 new reconciliation cases, existing drafts/confirmation and architecture
  gates. Real JWT permissions, cross-company access, filters, decimal rounding,
  cancelled versions, unplanned/paid facts and exact readonly table preservation
  are tested. This is selected regression, not the full backend release suite.
- Final Vitest regression: **57 passed in 4 files**, exit 0, 48.27 seconds.
  Dialog tests run under StrictMode; matching-but-divergent prices, filters,
  pagination, failed refresh/retry, financial scopes/account switch and inventory
  without a draft are covered. Changed-file ESLint passed with no warnings.
- Final Next.js webpack production build and TypeScript passed, 26 generated
  pages. Reused `.next-acceptance-preview` and installed dependencies. An earlier
  build also passed, but only the final build includes the multiple-price flags.
- **7 Playwright cases passed**, exit 0, 2.0 minutes: existing price management
  and the new reconciliation in EN desktop/RU/HE at 390px, plus inventory before
  a draft. APIs are mocked; no real invitation, approval or rate write occurred.
  Reconciliation screenshots were inspected: no incoherent overlap or page
  overflow, contained table scrolling, correct RTL and reachable footer. Refresh
  failure removes the table; close/Escape restores page interaction. This is
  admin browser acceptance, not physical-phone or live factory acceptance.
- Restarted only acceptance API 8001 to load the routes. It briefly returned 502
  during startup under the local build load, then `/ready` confirmed database
  readiness. Both routes appear in OpenAPI; an unauthenticated request returns
  401. Normal API 8000 and its database were not restarted or migrated.
- Read the service in a READ ONLY transaction for DIMAX Acceptance A, without
  creating a draft: 9 sources, all missing a factory price, 11 historical entries,
  zero current operative-price conflicts and zero unaccrued add-on facts. The
  catalog's test add-on default is 50 ILS, while its project plan is 9 ILS: the
  report keeps the reference price separate from the actual earning source.
- Acceptance DB remains at `0064_factory_price_approval`, with zero price lists
  and zero invitations. All five before/after snapshots below match. Checksums
  use `md5(jsonb_agg(to_jsonb(t) ORDER BY id)::text)`; a temporary check with a
  different string-aggregation format was not comparable and was corrected.

Preserved acceptance business data:

| Table | Rows | Checksum |
| --- | ---: | --- |
| completed_work | 11 | d972af6ed54536ef21a9d1abc9f1ec2c |
| installer_rates | 8 | 7ffab959007f5746bb9cc74f13fac706 |
| doors | 9 | 23ddc04087c8a06023ce96bc52cb92dc |
| project_addon_plans | 1 | 05d1630d4faf1ed8e44fb61f1ec698b0 |
| project_addon_facts | 1 | ffad0b2f2f4243935a4c215c69d175bc |

An earlier expanded run was interrupted after 96 passes and one invalid test
fixture: it tried surcharge_pct=0, rejected by the existing database constraint.
The fixture was corrected to valid 100 percent; no production constraint was
relaxed. That interrupted run is not counted as a successful regression gate.

The owned browser output directory was checked for workspace containment and
reparse points, then removed after visual inspection (7 files, 532357 bytes).
No APK, archive, dependencies or database was added. Existing unrelated outputs
were not deleted. The final local preview is running at
`http://127.0.0.1:4173/price-lists` against API 8001; the page returned HTTP 200.
The existing `next start`/standalone warning remains: this loopback preview is
not proof of the production deployment command. Prior generated/configuration
changes in `next-env.d.ts` and `tsconfig.json` remain outside the feature commit.

## Remaining Work

1. Admin/factory review of actual price differences, snapshots, surcharges,
   missing prices and historical unaccrued work. The report makes these visible
   but cannot decide commercial terms on behalf of the factory.
2. Activate only a confirmed version for server-calculated earnings, retain the
   previous active version during amendments and preserve existing accruals.
   Specify how pending door snapshots and work queued offline cross a price
   change; do not silently backfill previously unpriced add-on facts.
3. Sync the active version and read-only rates to mobile, then run live
   confirmation/admin/phone/earnings acceptance, replay/conflict cases and the
   full backend/admin/mobile release gates.
4. Configure HTTPS, verify the factory contact and provide controlled delivery.
   Personal links are bearer capabilities, not independent identity proof.

Mobile implementation and normal API/database were not changed. No APK,
dependencies, archive, new database, real factory decision or external message
is required by this step. Factory confirmation still records a decision only;
legacy rates still drive payroll until the activation step is implemented.

The prior restriction on publication to the public remote is unresolved.
Commits are local only; no GitHub backup or full production readiness is claimed.
Backend implementation/tests/checklist: `d3fdad7`. Admin implementation/tests:
`e4a0119`. Mobile remains unchanged at `f5eaeae`.
