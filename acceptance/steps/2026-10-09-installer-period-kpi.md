# Installer Period KPI: Recorded Work

## Scope

This step aligns `/api/v1/admin/reports/installers-kpi` and its CSV export.
Installer detail statistics are a separate, still-open step. No price activation,
earning write, migration, mobile change or external delivery is included.

## Changes

- The application service validates company price mode through the existing
  factory timeline service. Confirmation without activation remains LEGACY;
  an invalid active confirmation fails closed rather than falling back to rates.
- FACTORY KPI remains door-only performance, filtered by the effective work's
  completion timestamp, with inclusive start and exclusive end. It is not a
  dated payroll movement statement. Later reversals remove cancelled work from
  the earlier performance period; corrections preserve execution time and the
  original client-price snapshot reference.
- Historical recorded performers retain installations and amounts after changes
  to assignment, installer activity, rates or the active factory price list.
  Addon earnings remain outside this endpoint's established scope.
- Installed doors without active earning evidence become reconciliation gaps.
  They do not invent an installation count, revenue or payroll from legacy rates.
  Evidence lookup is independent of the selected period, preventing false gaps
  when the door timestamp differs from the recorded execution timestamp.
- Revenue keeps the existing saved-client-price basis, falling back to the
  current door's client price only when no snapshot exists. Missing client price
  invalidates profit, but does not discard recorded installer earnings.
- Unknown profit is null. Null profit sorts last in either direction, with stable
  name/UUID ties. Total/incomplete installer counts and unassigned missing-work
  counts are computed before pagination. Current assignee is used only to direct
  reconciliation of work without a recorded performer.
- API mode/coverage/total fields are additive; nullable `profit_total` is an
  intentional contract correction for incomplete FACTORY data. LEGACY money
  calculations and sorting remain unchanged.
- CSV keeps its first seven columns and adds record type, accounting mode,
  coverage counters, period bounds and accounting basis. FACTORY exports include
  a `summary` row even when there are no installer rows, so unassigned gaps are
  not hidden. Summary financial cells and unknown profits remain blank. Consumers
  must distinguish `summary` from `installer` rows using `record_type`.
- Admin renders EN/RU/HE period-accounting explanations and missing-data notices
  in both compact and desktop views, including empty results. Exact totals stop
  pagination at the last full page. Existing brand tokens and controls remain.

## Verification

- Initial focused backend run: 14 PASS, 36 deselected, 87.61 seconds.
- Expanded final backend regression: 73 PASS in 367.35 seconds, exit code 0:
  14 new factory-period cases, 38 existing report cases, 21 OpenAPI/access cases.
  The disposable test container was automatically removed after process exit.
- Final admin component tests: 29 PASS across two files in 48.17 seconds
  (12 notice/helper tests and 17 report page tests). Coverage includes the legacy
  door-only counter when addon fields are absent. The initial run had 11 notice
  tests before this final regression case was added.
- During the earlier admin verification, 28 tests passed (11 notice and 17 report
  page tests). The initial combined run timed out starting the ReportsPage worker;
  it did not execute that file. Retrying that file alone after stopping only the
  DIMAX preview/acceptance API passed in 39.96 seconds. The existing JSDOM
  document-navigation warning is not a real-browser navigation test.
- Changed-file ESLint passed without errors or warnings.
- Main acceptance ledger read-only check: 11 rows, 1513.50 ILS, digest
  `873b5115c8e2e320f325b1b8ff7ad96e`, unchanged. Schema remains
  `0067_sync_price_resolution`. All financial fixtures use `dimax_acceptance_tests`.
- Browser automation failed twice to initialize; the second error identified the
  Windows sandbox helper setup failure. No pixel or authenticated browser
  acceptance is claimed.
- Next.js 16.2.11 webpack production build PASS, TypeScript PASS, all 26 pages
  generated. Compilation: 2.9 minutes; TypeScript: 3.0 minutes. Output:
  `.next-acceptance/installer-kpi-20261009`.
- New standalone preview running at `http://127.0.0.1:4173`, PID 18784 when
  verified. `/login`, `/projects` and `/reports` return 200 with nonempty content.
  All four root-main JavaScript assets return 200 with JavaScript content types.
  Runtime stderr is empty. HTTP checks do not replace authenticated UI acceptance.
- Acceptance API restored at `http://127.0.0.1:8001`; `/ready` is OK with database
  ready. Live OpenAPI includes coverage metadata and nullable KPI profit.
  Anonymous KPI access returns 401; authorized/forbidden behavior is covered by
  integration tests. No installer/mobile endpoint changed.
- A second read of the main ledger after API restoration matches the same count,
  amount and digest above. No actual price activation or financial write occurred.
- Removed only this build's reproducible cache after resolved-path containment
  and reparse-point checks (269976491 measured file bytes). Runtime and the
  preceding rollback build remain. `/reports` still returns 200 after cleanup.
- Restored only the type paths generated by this build. Pre-existing changes to
  `next-env.d.ts` and `tsconfig.json` remain exactly as before and are not committed.

Local implementation checkpoints: backend `12d4714`, admin `43eaacb`.
The root protocol checkpoint follows these verified changes.

## Remaining Release Gates

1. Align installer detail statistics with recorded performers and earnings.
2. Align company order aggregates and remaining global risk/exposure reports;
   certify the complete executive CSV only after all its sections are aligned.
3. Finish the reviewed factory-price activation API/UI and its acceptance flow.
4. Complete real delivery/infrastructure and native-mobile release acceptance.

Separate UI debt observed during review: the older installer insight tile still
uses page-limited totals and legacy wording; its KPI shortcut targets the cross
view (`reports-installers-kpi`) instead of the actual period table
(`reports-order-numbers-kpi`). Normalize report-section anchors and those summary
labels in the next report-navigation pass. This step certifies the scoped API,
CSV and period-table behavior, not the complete ReportsPage or installer detail.

GitHub publication remains restricted by the prior public-repository decision.
Use local checkpoints only; no publication workaround or secret publication.
