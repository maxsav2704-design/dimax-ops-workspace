# Company project margins use recorded earnings

## Scope and architecture

Follow `2026-10-08-project-financials.md`. This bounded step aligns the company
project margin ranking, project rows in risk concentration, and their executive
CSV sections. Installer matrices, order aggregates and global risk exposure are
NOT certified by this checkpoint. Factory activation remains internal-only.

The application layer validates the effective price state with the existing
timeline service. The repository receives a factory-mode flag, not an unverified
price. Existing financial permissions and UOW boundaries are unchanged.

## Changes

- Factory-mode actual payroll is the company/project-scoped SUM of completed-work
  ledger movements, including reversals and corrections. Current door rates,
  addon plan rates, assignment changes and later price versions cannot reprice
  recorded work. Merely confirmed, inactive prices leave legacy reports unchanged.
- Ledger totals are grouped before joining operational counts. Multiple addon
  facts cannot multiply door earnings. The ranking remains a set-based query,
  not a project-by-project loop.
- Installed doors and addon facts without ledger evidence are counted explicitly.
  Actual payroll remains the recorded amount; profit and margin are null when
  work evidence or addon client plans are missing. Missing payroll is not invented.
- Unknown margins sort after known values in both directions. Project ID breaks
  equal-name ties for stable pagination. `incomplete_projects` counts all active
  visible projects, independently of the page limit, so gaps outside the top rows
  remain visible. Soft-deleted and foreign-company projects remain excluded.
- Client-revenue formulas retain their previous current-door/current-plan basis.
  This change is not an immutable client-billing snapshot redesign. Deleted addon
  plans do not remove earned payroll, but make calculated profit incomplete.
- CSV keeps its six-column layout. Project coverage rows include the project ID,
  calculation mode and missing-data counters. The basis row identifies recorded
  earnings and unpaginated coverage. Unknown amounts remain empty cells.
- Admin project rankings and risk-project rows show the basis and missing-data
  warnings in EN/RU/HE. Unrecorded addon work is included in the data-risk count;
  unrecorded doors are not counted twice. No overall risk/installer section is
  labelled factory-ready by the project-specific notice.

## Compatibility

No URL, role or write workflow changes. Project profit/margin and the worst
project profit can now be null for incomplete factory-mode data. New pricing-mode
and coverage fields are additive; legacy calculations remain supported.
`missing_rates_installed_doors` in factory mode identifies doors without recorded
work, matching the preceding project-level checkpoint; the explicit aggregate
field is `unrecorded_completed_works`.

No migrations, dependencies, mobile changes, price activation, real delivery or
financial writes are required. Tests use `dimax_acceptance_tests`, not the live
acceptance dataset. The schema remains `0067_sync_price_resolution`.

## Verification

- Initial report regression: 52 PASS, 2 failed due to a new fixture inserting
  identical project name/address pairs. Fixed only the fixture addresses; the
  uniqueness constraint was preserved. All 38 existing report tests passed.
- Final backend run: 55 PASS (442.25s): 16 new company-margin scenarios, 18
  preceding project-financial scenarios, OpenAPI and admin access/validation.
  Across the two runs, all 93 distinct tests passed at least once; both initially
  failing cases passed in the final run.
- Cases cover inactive confirmation, effective price changes, multiple facts,
  cancellation, reassignment, legacy door/addon corrections, missing ledger work,
  deleted client plans, ascending/descending stable pagination, unpaginated
  missing-data counts, API/CSV/project-plan-fact agreement, company isolation,
  deleted projects, installer 403 and corrupt approval receipt 409.
- Admin component regression: 22 PASS, 3 files (39.07s); EN/RU/HE notices and null
  financial values included. Final changed-file ESLint passed without warnings.
- Read-only acceptance ledger check: 11 rows, 1513.50 ILS,
  digest `873b5115c8e2e320f325b1b8ff7ad96e`, unchanged from the preceding step.
- Next.js 16.2.11 production webpack build PASS, TypeScript PASS, all 26 static
  pages generated. Output: `.next-acceptance/project-margin-20261008`.
- Standalone preview: `http://127.0.0.1:4173`, PID 10444 at verification.
  `/login`, `/projects`, `/reports` and all four root-main JS assets return 200;
  runtime stderr is empty. This is HTTP/component acceptance, not authenticated
  browser pixel-level or native-phone acceptance.
- Preserved pre-existing `next-env.d.ts` / `tsconfig.json` edits and removed only
  newly generated type-path changes. Neither file is part of this step's commit.
- Removed only the completed build's cache after resolved-path and reparse-point
  checks: 275336213 bytes. Current runtime and previous rollback build retained.
- Local host has about 4 GB RAM and experienced severe memory pressure. Only the
  old DIMAX preview and acceptance API were temporarily stopped for build/tests;
  databases, volumes and other projects were untouched. API was started again;
  its cold startup was slow and initial gateway readiness checks failed. Final
  `/ready` returned `status: ok`, database ready. Live OpenAPI verified the
  LEGACY/FACTORY mode, coverage counter and nullable project/worst-project profit.
- A second read-only ledger check after runtime refresh matches the same count,
  amount and digest above. No financial write or real delivery was performed.

## Remaining Release Gates

1. Align installer profitability matrices/details and order aggregates, including
   historical installer attribution and their CSV sections.
2. Align remaining KPI and global risk/exposure calculations. The complete
   executive CSV still contains legacy sections; it is not a release certificate.
3. Finish the reviewed activation API/UI after financial read models are aligned.
4. Complete real delivery/infrastructure and native-mobile release acceptance.

Local checkpoints: backend `5b1f0dc`, admin `4c39534`; root checkpoint follows
final runtime verification.
GitHub publication remains restricted by the previous public-repository decision;
no push or publication workaround.
