# Installer Detail Statistics: Recorded Work

## Scope

Align `/api/v1/admin/reports/installers-kpi/{installer_id}` with recorded
performers and earnings in FACTORY mode. Keep LEGACY calculations unchanged.
No activation of a real price list, financial write, migration, mobile change
or external delivery is included.

## Changes

- Reuse the installer financial projection already used by the two financial
  matrices. Net ledger movements determine earnings; surviving work determines
  door counts and addon quantities. Reversals/corrections are not double counted.
- Assignment, installer activity and price-list changes do not transfer or
  reprice historical earnings. Open issues remain the current assignee's duty.
- Work without earning evidence is a reconciliation gap, never an estimated
  earning from an old rate. Missing client prices invalidate profit without
  discarding recorded earnings. Addon profit has its own completeness check.
- Project and order breakdowns use company-scoped joins. Missing/foreign project
  metadata remains an unavailable project group with its recorded earnings,
  rather than disclosing a foreign label or losing the amount.
- Detail is all-time, independent of the period door KPI. Revenue preserves the
  financial matrices' existing current client-price basis, not a new invoice or
  immutable client-revenue ledger. Order numbers are current door metadata;
  blank numbers and addons are outside the order-number breakdown.
- Project groups contain financial activity/reconciliation gaps, not all current
  assignments. An issue-only assignee can have open issues and no financial rows.
- Preserve the top-five projects/top-eight orders limits and expose pre-limit
  counts. Stable project name/UUID and order-number ties make these lists repeatable.
- Mode/coverage/count fields are additive. Nullable FACTORY profits and unavailable
  project metadata are intentional API corrections; the admin consumer handles
  them explicitly. No installer/mobile API contract changed.
- Admin shows EN/RU/HE accounting explanations, recorded earnings, missing-data
  notices and limited-list counts in the existing design system.
- Detail selection uses a paginated installer directory, not only the current
  door-KPI page. Addon-only and historical performers can be selected. A direct
  link fetches that exact installer; a wrong-person response is rejected rather
  than silently substituting someone else. Explicit selection updates the link
  and does not reset on period-table refresh. Directory failure is disclosed.
- Installer directory ordering now has an ID tie-breaker for equal names.

## Verification

- Initial backend run: 13 passed, 2 failed. One failure was duplicate name/address
  in the new pagination fixture; addresses now differ. The other was a factory
  activation Conflict during test setup, not a detail-report assertion. Its exact
  blocker was not captured. A diagnostic exception note was added, without retry
  or weakened production validation. A focused rerun passed all four selected
  cases (11 deselected, 21.56 seconds). Do not infer its root cause from the rerun.
- First combined UI run: 12 financial-notice tests passed; ReportsPage's worker
  failed to start within its timeout. ReportsPage alone then passed 21 tests in
  62.72 seconds. The next run passed 20 tests and hit the default one-second
  Testing Library wait while the directory was still loading. New async assertions
  now use the five-second wait already used by neighboring tests. The final run,
  including selection retention on period refresh, passed all 21 in 36.23 seconds.
  The existing JSDOM document-navigation warning is not browser acceptance.
- Final expanded backend regression: 108 PASS in 691.01 seconds (15 new detail
  cases, 20 matrix cases, 14 period KPI cases, 38 existing report cases and 21
  OpenAPI/access cases). The initial activation-setup Conflict did not recur;
  its underlying cause remains unproven. No guard was weakened or test skipped.
- Changed-file ESLint passed again after the final test adjustment.
- Next.js 16.2.11 webpack production build PASS, TypeScript PASS, all 26 pages
  generated. Compilation: 2.5 minutes; TypeScript: 2.6 minutes. Output:
  `.next-acceptance/installer-details-20261009`.
- Main acceptance ledger baseline: 11 rows, 1513.50 ILS, digest
  `873b5115c8e2e320f325b1b8ff7ad96e`; schema `0067_sync_price_resolution`.
  A second read after runtime restoration matched this baseline exactly.
  Financial fixtures ran only in `dimax_acceptance_tests`.
- Standalone preview restored at `http://127.0.0.1:4173`, PID 20244 when checked.
  `/login`, `/projects`, `/reports` and all four root-main JavaScript assets
  returned HTTP 200 with nonempty content. Runtime stderr was empty.
- Acceptance API restored at `http://127.0.0.1:8001`. The first readiness request
  reached the gateway before API startup completed and returned upstream unavailable.
  After startup, `/ready` returned OK/database ready. Live OpenAPI includes the
  new coverage/count fields and nullable total/addon profit. Anonymous detail
  access returned 401. Role and tenant checks were covered by integration tests.
- Browser automation failed before attachment twice; the second attempt reported
  `windows sandbox failed: helper_unknown_error: setup refresh had errors`.
  No screenshot, pixel comparison or authenticated browser acceptance is claimed.
- Removed only this build's reproducible cache after exact resolved-path and
  reparse-point checks: 278901769 measured bytes. Runtime/rollback remain.
- Restored only generated type paths from this build. Pre-existing user changes
  in `next-env.d.ts` and `tsconfig.json` remain and are excluded from commits.

Local implementation checkpoints: backend `9e4fa46`, admin `7ce8764`.
The root protocol checkpoint follows these verified changes.

## Remaining Release Gates

1. Company order aggregates and remaining global risk/exposure reports; complete
   executive CSV acceptance only after all sections share the intended basis.
2. Reviewed factory-price activation API/UI and its end-to-end acceptance.
3. Real delivery/infrastructure and native-mobile release acceptance.
4. Authenticated browser acceptance and report-navigation debt recorded in the
   preceding period-KPI checkpoint. This is not a full ReportsPage certification.

GitHub publication remains restricted by the preceding public-repository decision.
Use local checkpoints only; do not publish secrets or work around that restriction.
