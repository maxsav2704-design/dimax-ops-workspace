# Live Excel and session acceptance, September 11, 2026

## Scope and Isolation

Continues the September 10 runtime checkpoint. Synthetic company A and project
`QA-IMPORT-20260910` only; project ID `6423143b-4122-4685-8f8f-20fe848bc8b7`.
Browser: `http://127.0.0.1:4173/projects`; API: loopback port 8001. UI database
`dimax_acceptance` is separate from `dimax_acceptance_tests` used by pytest.
No real signatures, external mail, WhatsApp, or physical-device actions.
No volumes or customer data were removed. Production approval remains withheld.

## P1: Expired Access Token Prevented Import

Actual browser reproduction: selecting the Excel file took longer than the access
token lifetime. Analyze returned HTTP 403 with `Token expired`. The admin client
correctly refreshes HTTP 401, not permission-denied HTTP 403, so the operation
failed repeatedly. No doors were written by the failed request.

Backend commit `c7b6e56` changes only JWT expiry to `Unauthorized` (HTTP 401).
Invalid signatures, incorrect token types, roles, tenancy, TTLs and refresh-token
rotation remain unchanged. Stored data is unchanged; no migration is needed.

Evidence:
- Before fix: regression test failed, expected 401 but received 403.
- After fix: 47 integration tests passed in 98.88 seconds, exit 0. Includes
  expired access for admin/installer, expired refresh, refresh rotation/reuse,
  real multipart retry without duplicates, auth guards and tenant isolation.
- Admin commit `154ee6b`: multipart refresh/replay and no retry on permission 403.
  All 25 API client tests passed using one fork, exit 0. Targeted ESLint passed.
  An earlier default-thread run timed out starting its worker; it is not a pass.
- Mobile API compatibility: 16 tests passed using one fork, exit 0. No mobile
  runtime change, Expo export, native build or phone acceptance in this step.
- Acceptance API restarted with the fixed source and passed `/ready`. Without
  logging in again or losing the selected file, the same browser made an expired
  request (401), refreshed successfully (200), retried successfully (200), then
  completed Excel analysis. This is observed UI evidence, not only mocked tests.
- Normal local API on port 8000 was also restarted to load `c7b6e56`. Before
  restart its database head was confirmed as `0060_installer_journal_handoff`;
  no migration was pending. Early readiness probes failed during startup;
  the subsequent host `/ready` request returned 200 with database ready.
  Only the API was restarted, not delivery/maintenance/sync workers.

The earlier 399-test full backend CI gate covers `1acf70d`, not `c7b6e56`.
Do not describe the new revision as having passed the full release gate yet.

## Live Excel Results

Source workbooks remain local under the ignored directory
`artifacts/acceptance-20260909/import-fixtures/`.

| Action | Independently expected | Observed |
| --- | --- | --- |
| Analyze `valid-9-doors.xlsx` | 8 source rows, 9 doors, no writes | PASS: 9 prepared, 0 errors, DB still 0 doors |
| Import the valid workbook | 9 doors, client total 9800 | PASS: DB count 9, `sum(our_price)` 9800.00 |
| Two types at A / 1 / 101 | Two separate doors | PASS: entrance and fire markings kept separately |
| Quantity 2 at B / 2 / 202 | Two separate doors | PASS: identifiers end in `/1` and `/2` |
| Repeat analysis and import | No new doors | PASS for data safety: idempotency notice, count still 9, total 9800.00, still two runs |
| Analyze `invalid-rows.xlsx` | 1 valid row, 1 duplicate, 3 errors; no writes | PASS: quantity 1.5, price -5 and unresolved type reported; DB still 9 doors |
| Strict UI behavior | Import blocked without explicit partial consent | PASS: Import disabled, partial checkbox unchecked; automatic type creation unchecked |

The 9 doors comprise 5 entrance and 4 fire doors, in 2 buildings and 7 distinct
building/apartment positions. Imported client prices are not installer rates;
this step does not prove assignment, earnings or accounting reconciliation.

The disabled Import button was not bypassed. Strict API rejection is covered by
automated tests from the numeric-validation checkpoint; it was not a new browser
submission of the invalid file. Partial import was not requested in this scenario.

## UI Findings and Follow-Up

- FIXED in frontend `52b59fe`: at the default 859px viewport the old fixed-width
  toolbar overflowed (576px content inside 525px) and its missing-type checkbox
  label overlapped the next row. Controls now wrap by available container width;
  the label has natural height. The file input remains keyboard-accessible with
  a localized accessible name instead of `display:none`. No import rules or
  permission checks changed.
- FIXED in `52b59fe`: unresolved type errors no longer leak the English API
  message in RU/HE. Uses the existing row-error formatter, including saved
  history, without rewriting the backend error contract or stored diagnostics.
- Preview structural headers still show Hebrew in RU. This remains open.
- Preview summary counts distinct apartment/floor labels, whereas the actual
  project matrix counts building-qualified positions: 4 vs 7 apartments and
  2 vs 4 floors in this fixture. Wording/count consistency remains open.
- Repeated analysis returns the cached original preview and an idempotency
  notice. It should distinguish historical counts from fresh projected writes
  more clearly. The repeat import itself did not duplicate any door.
- Error row numbers refer to parsed data rows, not physical XLSX rows including
  the header. The UI should make that distinction clear to the operator.

## UI Correction Verification

- `node node_modules/vitest/vitest.mjs run --pool=forks --maxWorkers=1
  src/lib/import-row-error.test.ts src/test/ProjectsPage.test.tsx`: 54 PASS,
  221.49 seconds, exit 0. Includes the accessible file input and import flows;
  13 formatter tests cover RU/EN/HE. Existing jsdom download tests emitted two
  unsupported document-navigation notices; these are not real-browser evidence.
- Targeted ESLint for the four changed files: exit 0. `git diff --check`: exit 0.
- Production-mode Next build with `--webpack`, one configured worker and
  `NEXT_DIST_DIR=.next-acceptance/ui-20260911`: PASS, exit 0. TypeScript and all
  24 generated pages passed. No normal `.next` cleanup script was run.
- The new preview replaced only the previously verified process on port 4173.
  Real browser inspection confirmed the new source classes and localized error
  in the saved invalid-file history in RU, EN and HE. Imported doors still show 9.
- Screenshots and DOM measurements were checked at actual CSS widths 389, 859
  and 1288px. Toolbar/options client widths equal scroll widths: 271, 525 and
  955px respectively. RU narrow label height equals its scroll height (52px).
  Hebrew RTL was checked at 389 and 1288px; no toolbar/options overflow.
- Temporary viewport override was reset and RU restored. Browser warning/error
  log for the new page was empty at the final check. No whole-site or device
  visual acceptance is claimed by this form-level inspection.

Next still warns about using `next start` with standalone output. This loopback
preview serves correctly, but is not the production deployment command. Existing
uncommitted `next-env.d.ts`/`tsconfig.json` generated paths were preserved; the
build added its own generated paths. None were staged in the frontend commit.

## Backup and Next Acceptance

New commits are local only. The existing workspace GitHub repository is public;
publication was rejected by the permission reviewer despite the standing backup
request. Explicit permission for publication to that public destination was
requested, but has not been received. No alternative upload path was attempted.
This is not a completed GitHub backup.

Next business workflow: assign imported doors to two installers, verify restricted
visibility, complete selected work, and independently reconcile accruals. Journal,
signing/PDF, local delivery and offline/device acceptance are still separate gates.
Frozen criteria weights and readiness percentages have not been advanced here.
