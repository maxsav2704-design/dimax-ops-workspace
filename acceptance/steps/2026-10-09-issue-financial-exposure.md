# Issue Financial Exposure and Addon Actuals

## Scope

Align the company issue/delay exposure report, risk summary and their executive
CSV rows with factory price authority. Reuse the existing recorded-work
projection for actual addon finances. No real price activation, migration,
earning write, mobile change or external delivery is included.

## Financial Rules

- Exposure is a forecast valuation of the underlying door installation, not
  earned wages, an invoice, or an estimate of additional repair work.
- FACTORY exposure uses the currently active confirmed company price list and
  current client door prices. A confirmation without activation remains LEGACY.
  Changing the active list changes this forecast, never historical earnings.
- Missing confirmed rates invalidate the affected payroll/profit total. Do not
  substitute an old installer rate or silently omit an unknown price from SUM.
  A missing rate on a non-blocked issue does not invalidate a priced blocked
  subset. Return coverage counts alongside unavailable totals.
- Open issues and NOT_INSTALLED doors are overlapping populations. Keep their
  separate values, but calculate the headline over unique doors using EXISTS.
  The same deduplication applies in LEGACY mode without changing its rate basis.
- Both sides of issue/door and reason joins are company-scoped. A corrupted
  cross-company link cannot disclose the other tenant's prices or labels.
- FACTORY addon earnings are signed ledger movements. Quantities and revenue
  use surviving work; current client addon-plan prices remain the revenue basis.
  Reversals and corrections are not double counted. A reversed fact is not a
  newly unrecorded job. Old plan installer prices are never invented earnings.
- Missing earning evidence or client prices invalidate addon profit, while
  preserving recorded money and showing partial-data counters. Foreign or
  unavailable addon metadata becomes an unnamed group, not a lost amount.
- Coverage totals and group counts precede list limits. Unknown profit sorts
  last with stable name/ID ties. Keep existing LEGACY addon formulas unchanged.

## Architecture and Contracts

- Extract the two existing price/SUM SQL helpers for reuse without changing their
  behavior. Replace duplicated door-risk aggregates with one scoped projection.
- Add only addon-fact identity to the existing financial work projection. The
  installer matrix/detail columns and formulas remain unchanged; addon impact
  aggregates that same projection rather than introducing another ledger engine.
- Mode, price-list identity/version, unique exposure and coverage are additive.
  Nullable affected FACTORY totals are an intentional contract correction. The
  admin renders unknown values as unavailable rather than zero or green success.
- Executive risk and issue/addon sections reuse one exposure result and one
  price version. CSV preserves existing columns/sections and adds explicit
  forecast/actual bases, unique-door totals and completeness. Unknown money is
  an empty CSV cell. This is not an end-to-end audit of every export section.
- EN/RU/HE explanations separate door forecasts from actual addon earnings and
  explain overlap and limited lists. The summary card uses the unique-door
  amount, including API Decimal strings, never adds overlapping populations.

## Verification

- Initial focused backend suite: 14 PASS in 143.54 seconds. Expanded backend
  regression: 145 PASS in 871.26 seconds across issue exposure, order reports,
  installer details/matrices/KPI, existing reports, OpenAPI and access checks.
- After adding single-result executive reuse, final focused backend regression:
  19 PASS, 36 deselected in 128.49 seconds. This includes all 17 new issue/addon
  cases and the existing risk/executive cases. No production guards were weakened.
- The interrupted UI run had no recoverable result. Its replacement with a
  forks pool timed out before executing tests. The project's configured threads
  pool then passed all 27 ReportsPage tests in 73.55 seconds. The existing JSDOM
  document-navigation warning is not an authenticated browser check.
- Financial components: 23 PASS in 16.40 seconds, including 6 new exposure-basis
  cases and EN/RU/HE coverage. Together with ReportsPage: 50 passing UI tests.
- Changed-file ESLint and Git whitespace checks passed.
- Next.js 16.2.11 webpack production build and TypeScript passed; all 26 pages
  generated. Compilation took 2.3 minutes and TypeScript took 2.4 minutes.
  Build: `.next-acceptance/issue-exposure-20261009`.
- Main acceptance ledger baseline: 11 rows, 1513.50 ILS, digest
  `873b5115c8e2e320f325b1b8ff7ad96e`. Financial fixtures use only
  `dimax_acceptance_tests`.
- The post-restoration ledger read matched all three baseline values exactly.
  Schema remains `0067_sync_price_resolution`; this reporting change needs no
  migration and writes no earnings.
- At resumption, the acceptance database, storage, mail sink and gateway were
  also stopped following the interruption. Restored only existing acceptance
  db/minio/mailpit/api/gateway containers. No outbox worker, external delivery,
  unrelated container or production price activation was started.
- Standalone preview restored at `http://127.0.0.1:4173`, PID 3164 when checked.
  Login, projects, reports and all four root-main JS assets returned nonempty
  HTTP 200 responses; runtime stderr was empty.
- API `http://127.0.0.1:8001/ready` returned OK/database ready. Live OpenAPI
  contains the new mode, price version, unique exposure, nullable amount and
  missing-rate coverage in both issue/addon and risk summaries. Anonymous
  requests to both report endpoints returned 401.
- Browser attachment succeeded this time. While the gateway was starting, the
  reports route displayed a retryable connection error. Retrying after API
  recovery led to the login page with `next=/reports` and `auth_required`.
  The expired session was not bypassed or reset. Login was visibly rendered,
  but authenticated report layout/interaction acceptance remains outstanding.
- Removed only this build's reproducible cache after exact-path and reparse-point
  checks: 271003345 measured bytes. Runtime and rollback remain. Removed only
  the new build's generated TypeScript include paths; original user changes in
  `next-env.d.ts` and `tsconfig.json` remain outside the implementation commit.

Local implementation checkpoints: backend `8eadfed`, admin `a92c26c`.
This closes the implemented/tested issue-exposure block, not overall production
acceptance or every executive-export section.

## Remaining Release Gates

1. Final executive export review, including selected-project sections, and
   authenticated browser acceptance. A passing HTTP request is not visual QA.
2. Reviewed factory-price activation API/UI end-to-end acceptance.
3. Real delivery/infrastructure and native-mobile release acceptance.
4. Existing report-navigation and remaining localization debt.

Keep local Git checkpoints only under the existing public-repository publication
restriction. Preserve unrelated user settings and the previous runtime for rollback.
