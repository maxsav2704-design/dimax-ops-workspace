# Project financial reports and confirmed prices

## Scope and architecture

Follow the addon price boundary checkpoint. This step covers project plan/fact,
project risk drilldown, their executive CSV sections, and their two admin views.
It does not certify all company-wide financial reports for factory activation.

The application service obtains the validated effective factory snapshot through
the existing timeline service and passes a rate mapping to the reports repository.
SQL does not choose or approve a price version. Existing permission checks, UOW,
ledger, legacy calculations and project ownership checks remain in place.

## Changes

- In factory mode, the project payroll plan uses the currently effective confirmed
  DOOR and ADDON prices. A merely confirmed later version does not change the plan.
  This is a current full-scope estimate, not an immutable original budget.
- Actual payroll uses the project's completed-work ledger, including reversals
  and corrections. It never uses current plan prices or historical urgency rows.
  Changing a list does not update earning rows or the factory evidence attached
  to them. Previously recorded legacy corrections remain in the total.
- A required unpriced door or positive-quantity addon plan invalidates planned
  payroll/profit and dependent gaps. These values are null, not incomplete sums
  presented as a complete total. Zero-quantity addon plans do not require a price.
- Installed doors or addon facts without a ledger entry are counted explicitly.
  They are not assigned an invented earning. Actual payroll remains the recorded
  total; actual profit/margin is unknown until missing work evidence is resolved.
- Removing an addon plan cannot erase earned payroll. Missing client-side addon
  plans make actual profit unknown. Client-revenue formulas otherwise retain their
  existing behavior; this step is not a redesign of client billing snapshots.
- Project risk calculations use current confirmed rates for pending-work cost
  exposure, ledger amounts for earned order/addon cost, and propagate unknown
  sums instead of letting SQL SUM silently ignore unpriced rows.
- Plan/fact and risk responses identify pricing mode and active version and expose
  missing addon prices / work without an earning. CSV preserves unknown cells as
  empty and includes separate price-basis and data-coverage rows for both sections.
- Admin Projects and Reports show the price basis and incomplete-calculation
  warnings in EN/RU/HE. Unknown financial amounts and percentages are not zero.
  Historical urgency remains visible separately and is excluded from the
  factory-mode addon payroll-plan card.

## Compatibility

URLs, access rules and successful legacy-mode amounts are preserved. In factory
mode, incomplete financial fields can now be null; both admin consumers handle
this. Actual payroll remains numeric and is explicitly labelled as recorded
earnings. Calendar only consumes this numeric actual payroll and operational
counts. Mobile does not consume these admin report DTOs and is unchanged.

No migration or new dependency is required. The acceptance database remains at
`0067_sync_price_resolution`. Factory activation is still internal-only.

## Verification

- PostgreSQL initial regression: 62 PASS (200.67s), covering the initial 15 new
  financial scenarios, existing reports and payroll lifecycle.
- Final expanded PostgreSQL regression: 39 PASS (149.17s), covering 18 new
  financial scenarios, OpenAPI contract and admin access/validation. Across the
  two successful runs: 86 distinct tests. The intermediate expanded run exposed
  an invalid fixture: it attempted activation with an existing unpriced active
  catalogue type. The activation guard was preserved; the final test creates a
  new unpriced type after a valid activation.
- Tests include effective versus merely confirmed versions, v2 plans preserving
  v1 earnings, missing/empty price categories, zero quantity, missing ledger work,
  cancellation, legacy correction, deleted plans, separate urgency history,
  other-project isolation, foreign-project 404, installer 403, damaged receipt
  409 and CSV/API price-basis/nullable-total consistency.
- Admin: 64 PASS across ProjectsPage, ReportsPage and ProjectPricingNotice;
  final focused repeat: 2 PASS, 10 unselected (20.54s). EN/RU/HE notices are tested.
  Changed-file ESLint PASS, including a final repeat.
- Production Next.js 16.2.11 webpack build PASS, TypeScript PASS, all 26 static
  pages generated. Output: `.next-acceptance/financial-report-20261008`.
- Acceptance API restarted and `/ready` verified with database ready. There was
  a temporary upstream-unavailable interval during cold start and a first OpenAPI
  timeout while the build was running. Subsequent live OpenAPI check confirms
  LEGACY/FACTORY, nullable planned payroll and the new coverage field.
- Standalone admin is running at `http://127.0.0.1:4173`, PID 12168 at verification.
  `/login`, `/projects`, `/reports` and all four root-main JS assets return 200;
  runtime stderr is empty. This is HTTP/component acceptance, not authenticated
  browser pixel-level or native-phone acceptance.
- Read-only database checks before/after runtime refresh agree: 11 completed-work
  rows, 1513.50 ILS, digest `873b5115c8e2e320f325b1b8ff7ad96e`.
- Removed only this build's cache after resolved-path/reparse-point checks:
  268839942 bytes. Standalone runtime retained. No APK, package install, real
  approval, activation, earning, email or WhatsApp delivery was created.
- Pre-existing admin `next-env.d.ts` and `tsconfig.json` edits were preserved;
  build-added paths were removed and neither file was committed. Mobile unchanged.

## Remaining Release Gates

1. Align company-wide project/installer profitability matrices, KPI detail views,
   order aggregates, risk concentration and their CSV sections. They still contain
   legacy fallback calculations. This checkpoint must not be read as certification
   of the entire executive export or financial module in factory mode.
2. Finish the reviewed activation API/UI only after those read models are aligned.
   Do not activate a real company on the strength of this project-level step.
3. Complete real delivery/infrastructure and native-mobile release acceptance.

Local checkpoints: backend `da4e965`, admin `57b3d31`; this report and protocol
reference are a separate root commit. GitHub publication remains restricted by
the previous public-repository decision. No push or publication workaround.
