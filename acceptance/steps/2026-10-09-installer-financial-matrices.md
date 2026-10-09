# Installer financial matrices: recorded performer and earnings

## Scope and architecture

Follow `2026-10-08-company-project-margins.md`. This step aligns the two company
installer profitability matrices, the installer rows in risk concentration and
their executive CSV sections. Period installer KPI, installer detail, order
aggregates and global exposure remain separate release gates. Factory activation
remains internal-only; this checkpoint does not certify the entire product.

The existing application service validates company pricing state through the
factory timeline. A shared set-based SQL projection supplies both factory-mode
matrices. Legacy-mode queries, permissions, tenant scope and UOW boundaries stay
in place. No new write workflow or migration is needed.

## Changes

- Payroll is the sum of recorded ledger movements, including reversals and
  corrections, grouped by the historical installer (and project in cross-view).
  Current assignment, legacy rates and later price changes cannot transfer or
  reprice earnings. Historical work from inactive installers remains visible.
- Performance counts and revenue use surviving original/corrected ledger work.
  Reversed work is not counted again. Current client prices remain the revenue
  basis; this is not a client-billing snapshot redesign.
- Open issue counts remain associated with the current responsible installer,
  not the historical performer. These are financial matrices for installers with
  completed work or missing earning evidence, not the full issues directory.
- Installed doors without active earning evidence and addon facts without any
  earning evidence are reconciliation gaps, not invented performance/payroll.
  Reversed addon facts are not treated as new unrecorded jobs. Unassigned installed
  doors have a separate company-wide counter even when the matrix has no rows.
- Unknown profit/margin/average is null and has an INCOMPLETE band, not zero or
  a poor-performance label. Missing client prices also invalidate profitability
  without discarding recorded payroll. Missing-data counters are not paginated.
- Null profits sort last in both directions, with installer/project UUID
  tie-breakers. Missing/foreign project links are rendered as unavailable;
  historical company earnings are retained without exposing another tenant.
- API metadata is additive. Nullable profit/margin/average and nullable project
  identity are intentional compatibility changes for incomplete factory data.
  Legacy values retain their prior calculations.
- CSV retains six columns and adds basis, coverage and earnings sections for
  both matrices. Unknown values stay blank. The complete CSV still contains
  other, not-yet-aligned financial sections and is not a release certificate.
- Admin desktop and narrow-screen rows show earned amounts separately from
  profit, localized accounting basis and missing-data notices in EN/RU/HE.
  The data-risk count does not double count overlapping legacy compatibility
  fields. Missing projects are named explicitly rather than rendered blank.

## Verification

- Initial focused backend run: 20 PASS, 1 invalid new test fixture failed because
  addon facts require an installer. Preserved the NOT NULL constraint; corrected
  parametrization to test only supported states. Unassigned doors remain covered.
- Expanded backend regression: 92 PASS (1402.07s): 20 installer matrix cases,
  16 company project margins, 18 project financials and 38 existing report cases.
  The Docker CLI connection dropped during the run. Reattached to the same
  container and received its complete passing summary; `docker wait` returned 0.
- Final backend CSV/OpenAPI/access regression: 23 PASS (140.77s). Two CSV cases
  repeat the expanded suite against the final source; 21 are additional contract
  and authorization tests. In total, 113 distinct backend tests passed.
- Coverage includes historical/inactive performers, reassignment/unassignment,
  cancellation and reinstall by another installer, current issue responsibility,
  price changes, multiple addon facts, legacy corrections, missing work evidence,
  missing client plans, stable pagination, unpaginated gaps, unavailable project
  links, company isolation, installer 403 and corrupt factory receipt 409.
- Read-only main acceptance ledger: 11 rows, 1513.50 ILS, digest
  `873b5115c8e2e320f325b1b8ff7ad96e`, unchanged. Schema:
  `0067_sync_price_resolution`. All financial fixtures use the separate
  `dimax_acceptance_tests` database.
- Admin component verification: 32 PASS across four files. Initial threads-worker
  startup timed out for ReportsPage before executing that file; the other three
  files passed 17 tests. Retried ReportsPage alone with one forks worker and a
  768 MB heap: 15 PASS (29.56s). No dependency or permanent runner configuration
  change. JSDOM reported its existing document-navigation limitation; actual
  browser navigation/pixel acceptance is not claimed by these component tests.
- The browser-control tool could not initialize because of the Windows sandbox
  helper setup error. No authenticated browser screenshots or phone verification
  are claimed. Acceptance here is API, component, build and HTTP verification.
- Changed-file ESLint passed without warnings. Next.js 16.2.11 webpack production
  build PASS, TypeScript PASS, all 26 static pages generated. Compilation took
  2.5 minutes and TypeScript 3.7 minutes on the memory-constrained local host.
  Output: `.next-acceptance/installer-matrix-20261009`.
- Standalone preview restored at `http://127.0.0.1:4173`, PID 20872 at verification.
  `/login`, `/projects` and `/reports` return 200 with nonempty page content.
  All four root-main JavaScript assets return 200 with JavaScript content types.
  Runtime stderr is empty. This does not replace authenticated visual acceptance.
- Acceptance API restored at `http://127.0.0.1:8001`; `/ready` reports status OK
  and database ready. Live OpenAPI exposes both pricing modes, missing-data
  counters, nullable installer profit and unavailable project identities.
- A second main-ledger read after runtime refresh matches the same 11 rows,
  1513.50 ILS and digest above. No actual price activation or financial write.
- Only the current build's cache was deleted after absolute-path, containment
  and reparse-point checks. Current runtime and previous rollback build remain.
  No disposable pytest containers remain. Only the DIMAX preview/API were
  temporarily stopped for resource control; databases and other projects stayed.
- Preserved the pre-existing `next-env.d.ts` and `tsconfig.json` changes. Removed
  only this build's generated type-path edits; neither file is in the commit.

Local implementation checkpoints: backend `d64d883`, admin `df77048`.
The root documentation checkpoint follows final verification.

## Remaining Release Gates

1. Align installer period KPI/detail and company order aggregates with recorded
   earnings and historical performer attribution.
2. Align remaining global risk/exposure calculations and complete CSV coverage.
3. Finish the reviewed activation API/UI after all financial read models align.
4. Complete real delivery/infrastructure and native-mobile release acceptance.

No phone changes, real factory activation, emails/WhatsApp or main-database
financial writes. GitHub publication remains restricted by the previous
public-repository decision; local checkpoints only, no publication workaround.
