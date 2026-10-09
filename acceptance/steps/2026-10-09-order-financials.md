# Order Financial Reports

## Scope

Reconcile company order-number reports with recorded earnings in FACTORY mode.
This covers the direct API/CSV and the order subsection of risk concentration
and executive CSV. It does not certify the remaining global issue/delay exposure
calculations. No price activation, financial write, migration or mobile contract
change is included.

## Accounting Rules

- Keep current door statuses for operational counts and completion percentage.
  Show surviving recorded installations separately; a status alone is not
  evidence of an earning.
- Payroll is the sum of signed DOOR ledger movements, including cancellations
  and corrections. Never fill a missing earning from a legacy installer rate.
- Revenue uses surviving work and its original client-price snapshot, falling
  back to the current door client price when no snapshot exists. This preserves
  the order report's established basis, not an invoice/revenue ledger.
- Installed doors without earning evidence are reconciliation gaps. Keep their
  operational progress, disclose the count and return unknown profit as null.
  Do not turn unknown profit into zero or a ranked financial result.
- Membership uses current project/order metadata on the door. Normalize outer
  spaces in FACTORY order groups. Exclude blank order numbers and all addons.
  Consequently this door-only report is not the full company payroll statement.
- Scope all financial and issue joins by company. Aggregate relations before
  joining, so movements/issues cannot multiply amounts or door counts.
- Count incomplete orders before pagination. Unknown profit sorts last in either
  direction, with stable order-number ties. Search treats wildcard characters
  literally. Preserve existing LEGACY financial formulas.

## API and Interface

- Add mode, recorded-installation and coverage fields to order rows/envelopes
  and risk summary. Nullable FACTORY profit is an intentional contract correction;
  the admin renders it as unavailable rather than zero.
- Preserve existing direct CSV columns and append metadata. FACTORY exports
  include an explicit summary row, including empty results. Consumers must use
  `record_type` to distinguish it from an order row. Blank profit means unknown.
- Add order financial/basis/coverage sections to executive CSV. They are a limited
  sample, with shown/total counts, not the complete order list. The rest of that
  export still needs its separate release review.
- Escape formula-leading order labels only at CSV output; JSON and stored order
  numbers remain unchanged. This is not an audit of every CSV field in the system.
- Explain the basis and incomplete counts in EN/RU/HE. Keep existing filters,
  pagination, exports and responsive rows. Label the low-profit sample honestly:
  its presence alone does not mean every order is loss-making or at risk.

## Verification

- Initial new backend suite: 19 passed, 2 failed during fixture setup. The fixture
  violated the existing unique company/door issue constraint by adding two issue
  cards to one door. It now uses two doors in the same order. No production guard
  or database constraint was weakened.
- Expanded backend regression: 80 PASS in 421.36 seconds. This includes 21 order
  cases, 38 existing report cases and 21 OpenAPI/access cases. Fixtures ran only
  in `dimax_acceptance_tests`.
- ReportsPage: 24 PASS in 89.57 seconds. Covers incomplete/empty data, null profit,
  risk propagation, pagination, filter reset and CSV download completion.
- Financial notice components: 17 PASS in 19.05 seconds, including 5 new order
  basis tests in EN/RU/HE. The existing JSDOM document-navigation warning in the
  ReportsPage suite is not authenticated browser acceptance.
- Changed-file ESLint passed. Next.js 16.2.11 webpack production build and
  TypeScript passed, with all 26 pages generated. Compilation took 110 seconds;
  TypeScript took 3.3 minutes. Build: `.next-acceptance/order-financials-20261009`.
- Main acceptance ledger baseline: 11 rows, 1513.50 ILS, digest
  `873b5115c8e2e320f325b1b8ff7ad96e`; schema `0067_sync_price_resolution`.
- The post-restoration ledger read matched the baseline exactly.
- Standalone preview restored at `http://127.0.0.1:4173`, PID 20064 when checked.
  Login, projects, reports and all four root-main JS files returned nonempty
  HTTP 200 responses. Runtime stderr was empty.
- Acceptance API restored at `http://127.0.0.1:8001`. The first request preceded
  completed startup and returned upstream unavailable. Once healthy, `/ready`
  returned OK/database ready; live OpenAPI included mode, recorded installations,
  coverage and nullable profit. Anonymous order-report access returned 401.
- Browser automation failed before attachment with `windows sandbox failed:
  helper_unknown_error: setup refresh had errors`. No authenticated visual
  acceptance or screenshot is claimed; HTTP and component checks are narrower.
- Removed only this build's reproducible cache after exact-path and reparse-point
  checks: 270604159 measured bytes. Runtime and rollback remain. Removed only
  this build's generated TypeScript include paths; pre-existing user edits in
  `next-env.d.ts` and `tsconfig.json` remain excluded from commits.

Local implementation checkpoints: backend `20ce0df`, admin `12542f4`.

## Remaining Release Gates

1. Global issue/delay exposure and the remaining executive CSV sections.
2. Reviewed factory-price activation API/UI end-to-end acceptance.
3. Real delivery/infrastructure and native-mobile release acceptance.
4. Authenticated browser acceptance and existing report-navigation debt.

Keep local Git checkpoints only under the existing public-repository publication
restriction. Preserve unrelated user configuration changes and runtime rollback.
