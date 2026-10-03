# Factory Price Application Check

## Scope And Architecture

Inspection of the current payroll paths showed that factory confirmation only
records a decision. Door earnings still prefer legacy saved/per-installer rates;
additional-work earnings use project-plan prices. Mobile sync supplies plan
quantities but not confirmed price versions or rates. Switching payroll before
that offline contract exists could silently change what a worker expects to earn.

This bounded step therefore adds a readonly pre-application check to the existing
selected-version reconciliation response and dialog. Authorization and company
scope remain in the existing rates API. The application service evaluates the
decision and prerequisites; repositories own SQL. There is no activation endpoint,
new table, migration, payroll mutation or mobile rollout in this step.

`application_check` is null for company inventory without a selected version.
For a selected version it returns BLOCKED, REVIEW_REQUIRED or VERIFIED, reasons
with company-wide counts, recorded confirmation time and `affects_earnings=false`.
VERIFIED describes checked price data, not an active payroll version.

## Implemented

- A CONFIRMED status alone is insufficient: the recorded factory receipt and
  its exact hashed snapshot must match the selected version and current lines.
  Malformed snapshots fail closed; public preview returns a conflict instead
  of an accidental internal error.
- Receipt timing must be credible. Expiry of the sharing link does not undo an
  already recorded decision. A newer confirmed version blocks preparing an older
  version, but a newer unconfirmed draft does not disqualify the previous one.
- All active company work types, pending doors and operative additional-work
  plans/facts must be covered. Referenced unavailable types, empty lists, missing
  prices, catalog name/unit changes and installer surcharges outside the list
  are identified. Foreign catalog names are never exposed.
- Saved door rates, different legacy prices, scheduled rates, unaccrued work
  and separate urgency agreements remain explicit transition-review items.
  Existing financial functionality is retained, not removed or overwritten.
- Filters and pagination cannot hide these company-wide prerequisites. The
  selected-version dialog displays localized RU/EN/HE reasons and explicitly
  says that the prices are not active in earnings. Missing checks or failed
  refreshes cannot retain a successful-looking stale result.

This is an advisory multi-query read, not an atomic authorization to change
payroll. Future activation must recheck the applicable prerequisites inside the
company-locked mutation transaction. Catalog reachability is scoped to operative
same-company projects; this is not a substitute for a complete data-integrity audit.
The current-version check must not be reused to reject a historical version
valid at execution time or the agreed first-list transition exception.

## Agreed Offline Rules

The user explicitly chose both rules on October 3:

1. New offline work uses the confirmed price effective at execution time, not
   upload time. The server validates the work and stores version/rate evidence;
   a device-supplied monetary amount is never authoritative.
2. At the first rollout, old queued offline work without a confirmed price
   version uses the first confirmed company list, not a later amendment.
   Already recorded earnings are unchanged. Assignment, replay/conflict and
   quantity validation still apply. A missing first-list price must remain
   unresolved rather than be guessed or replaced with a later price.

These are recorded business decisions, not payroll functionality implemented
by this readonly step. Old queued work is distinct from facts already uploaded
without an accrual; their reconciliation must not silently reprice history.

## Verification

- Final selected PostgreSQL regression: **218 passed**, exit 0, 452.47 seconds.
  Includes the 19 new check cases, existing reconciliation, immutable draft and
  factory-confirmation API cases, and architecture gates. Readonly table
  snapshots, tenant scope, filtering, receipt/snapshot tampering, missing prices,
  catalog changes, pending amendments, expired links and legacy transition flags
  are covered. This is selected regression, not the full backend release suite.
- Final Vitest: **51 passed in four files**, exit 0, 35.29 seconds:
  `PriceReconciliationDialog`, `PriceListsPage`, `PriceApprovalPage` and
  `factory-prices`. VERIFIED is explicitly distinguished from active earnings;
  missing checks and failed refreshes do not retain a successful stale result.
  Changed-file ESLint passed without warnings; the strengthened browser spec
  passed lint again after adding viewport assertions.
- Next.js webpack production build/TypeScript: PASS, exit 0, 26 generated pages.
  Reused installed Node 20, dependencies and `.next-acceptance-preview`, with
  one heavy verification process at a time and a 768 MB Node heap limit.
- Final Playwright: **7 passed**, exit 0, 1.4 minutes. Tests cover EN desktop,
  RU/HE at 390px, readonly finance access, inventory without a draft, filters,
  pagination, failed refresh/retry and modal close/Escape. The updated cases
  explicitly scroll to the table and verify the table and close control are in
  the viewport. Both summary and scrolled-row screenshots were inspected in all
  three languages: no incoherent overlap, contained horizontal table scrolling,
  readable source rows, correct RTL and a reachable footer. APIs are mocked;
  this is not a live factory or physical-phone acceptance test.
- Restarted only acceptance API 8001. `/ready` returned database ready, the live
  OpenAPI includes the new field/three states with `affects_earnings=false`, and
  an unauthenticated report request returned 401. The first OpenAPI request
  exceeded 15 seconds; a subsequent strict check with a 60-second timeout passed.
  The failed request's empty schema result is not counted as a successful check.
- Acceptance and test schemas remain at `0064_factory_price_approval`. No model
  or migration changed, so no fresh/rollback migration smoke was added here.
  Acceptance still has zero factory price lists and invitations. All five
  business-table checksums match the previous checkpoint before and after API
  restart. Normal API 8000 and its database were not restarted or migrated.

Preserved acceptance data, using `md5(jsonb_agg(to_jsonb(t) ORDER BY id)::text)`:

| Table | Rows | Checksum |
| --- | ---: | --- |
| completed_work | 11 | d972af6ed54536ef21a9d1abc9f1ec2c |
| installer_rates | 8 | 7ffab959007f5746bb9cc74f13fac706 |
| doors | 9 | 23ddc04087c8a06023ce96bc52cb92dc |
| project_addon_plans | 1 | 05d1630d4faf1ed8e44fb61f1ec698b0 |
| project_addon_facts | 1 | ffad0b2f2f4243935a4c215c69d175bc |

The initial backend run stopped at an invalid synthetic `.test` email. The
fixture was corrected to the existing suite's `example.com` convention; email
validation was not relaxed and no message was sent. The first frontend run
caught a missing JSX brace in the newly added reason list. It was corrected and
all four suites rerun; those earlier partial/failed runs are not release PASS.

After visual inspection, the exact owned browser output directory was checked
for workspace containment and reparse points, then removed: 10 files, 828565 bytes.
No APK, archive, dependencies or database was added; unrelated outputs were not
removed. Mobile remains unchanged and was not built or tested natively here.
The test image uses Python 3.12; Python 3.11 was not separately verified this step.

The final loopback preview returned HTTP 200 at
`http://127.0.0.1:4173/price-lists`, connected to acceptance API 8001 (owned PID
7808). Existing `next start`/standalone warnings remain; this preview is not a
production deployment-command certification. Prior unrelated/generated edits in
`next-env.d.ts` and `tsconfig.json` stay outside the feature commit.

## Next Block

Implement an explicit active-version timeline and immutable ledger provenance,
guard all door/additional-work completion paths, and sync readonly versioned
prices to mobile before enabling the new payroll contract. Verify a queued work
item across a price change, the first-list transition exception, amendments,
replays and assignment conflicts in an isolated end-to-end scenario.

Controlled factory delivery/HTTPS, physical-phone acceptance and full release
gates remain open. No external message, real factory decision, APK or new database
is needed here. The public-remote backup restriction remains unresolved; commits
are local only and no GitHub backup or complete production readiness is claimed.
Local backend implementation/tests/checklist: `e4dac1a`. Local admin
implementation/tests: `f38d109`. Mobile remains unchanged at `f5eaeae`.
