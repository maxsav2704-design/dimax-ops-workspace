# Payroll lifecycle and project amount verification

This continues `2026-09-11-payroll.md`. No production approval, native-device
acceptance or readiness-percentage increase is implied by this checkpoint.

## Persisted UI Lifecycle

The second, previously uncertain correction was checked before any new mutation.
PostgreSQL contained only the original 250 ILS entry for synthetic door
`A-1-102-dira-EN-102`. A fresh owner login loaded the same four-entry ledger.
The following actions then completed through the acceptance admin at port 4173:

| Action | Door accrual | Company ledger total | Ledger rows |
| --- | ---: | ---: | ---: |
| Initial state | 250 | 1000 | 4 |
| Correct the rate to 300 | 300 | 1050 | 6 |
| Cancel installation, with reason and administrator justification | 0 | 750 | 7 |
| Reinstall using the current 250 rate | 250 | 1000 | 8 |

Independent read-only database queries confirmed each transition. The door's
immutable history is `+250, -250, +300, -300, +250`. Cancellation reversed the
corrected 300, not the initial 250. No extra correction was submitted while a
previous request outcome was unknown. This used only the synthetic acceptance
company and did not send customer email, record a bank payment or require a photo.

## Project Financial Display Defect

Observed in the live project page: revenue/payroll/profit appeared as hyphens,
while margin remained visible. The backend schemas use Decimal monetary fields;
their JSON representation is a string. `ProjectsPage.tsx` accepted only JavaScript
numbers in its formatter and hard-coded USD with zero decimal places.

The scoped frontend fix:
- accepts both string and numeric amounts in the report DTOs;
- uses the existing locale-aware formatter and ILS, matching installer earnings;
- preserves two decimal places instead of rounding away cents;
- keeps missing/invalid amounts distinct from zero;
- explicitly converts decimal quantity strings for display-only subtraction.

No API, database schema, accrual calculation or permissions changed in this fix.
No migration is needed. Other known UX text and historical client-price snapshot
questions are not declared resolved by changing this formatter.

## Completed Checks

- Backend `3c9c01e`: all 9 payroll lifecycle tests PASS, exit 0, 234.69 seconds.
  Includes corrected/uncorrected cancellation, day/month reconciliation,
  repeat confirmation, reinstall, addon snapshots and both concurrent lock orders.
  Run in a separate temporary container against `dimax_acceptance_tests`.
  Evidence: `artifacts/acceptance-20260909/payroll-lifecycle-complete.xml`.
- Focused project display regression: 2 PASS, 40 deselected, exit 0.
  Both numeric and Decimal-string responses preserve fractional monetary amounts.
- Admin related regression: 62 PASS across ProjectsPage, EarningsLedgerPage,
  ReportsPage and InstallerEarningsPage, exit 0, 111.54 seconds.
  Evidence: `artifacts/acceptance-20260909/payroll-admin-complete.json`.
  Existing jsdom navigation and localStorage-path warnings remain visible.
- Backend related regression: 60 PASS, exit 0, 97.65 seconds: existing earnings
  corrections, reports, financial integrity constraints, transaction boundaries
  and module structure. Combined with the lifecycle run: 69 passing checks.
  Evidence: `artifacts/acceptance-20260909/payroll-related-complete.xml`.
- Production Next.js 16.2.11 build: PASS, exit 0; TypeScript and 24 static pages.
  Separate output: `.next-acceptance/payroll-20260911`; normal `.next` retained.
- ESLint: PASS for the changed page, page tests and standalone runtime test.
- Fresh browser on the new standalone output: revenue 4400 ILS, payroll 1000 ILS,
  profit 3400 ILS, 4/9 installed. RU/EN/HE amounts verified; RU and HE screenshots
  inspected. Test data names are not translated. Final preview is back in Russian.

An earlier frontend attempt hit Node's explicit out-of-memory error. It also
exposed an asynchronous test assumption: the financial section heading renders
before its data. The test now waits for the actual plan/fact content. The successful
sequential rerun used one worker and bounded Node heap settings; failed attempts
are not counted as successful gates.

## Standalone Startup Defect

The generated `standalone/server.js` uses `require`, while its copied package.json
declares `type: module`. Actual startup failed with `require is not defined in ES
module scope`, despite a successful build. The existing Dockerfile selected this
same entrypoint. The runner now copies the generated entrypoint as `server.cjs`
and starts it explicitly; the application remains an ESM project.

A new Node test asserts the Docker copy/CMD contract and executes a CommonJS
entrypoint inside an ESM package. Before the fix it failed; after the fix the new
test and six existing production-environment tests pass (7 total). It is included
in `quality-gate`, which the existing frontend CI workflow invokes. The actual new
Next standalone output also starts with `.cjs` and serves the browser successfully.
This is a local Node 25.5 runtime check, not a rebuilt Node 22 Docker-image gate.

## Outcome and Limits

The scoped payroll lifecycle and project monetary-display checks are complete.
No financial retry remains unresolved. No new backend or mobile source change was
needed in this continuation. Frontend checkpoints: `dcfc1c5` (amount display),
`2f2e848` (standalone startup). Existing generated next-env.d.ts and tsconfig.json
changes were left uncommitted and were not reverted.

The new preview is `http://127.0.0.1:4173/projects`, connected only to the synthetic
acceptance API on port 8001. Both return HTTP 200. The ordinary API on port 8000
was restored and its `/ready` also returned HTTP 200 after normal startup.

The normal local stack was gracefully stopped to reduce concurrent load, without
deleting its named volumes. Docker was no longer running after the interruption;
standard startup exceeded its wait, but the engine subsequently became available.
The acceptance stack and normal services were restarted on their existing images
and volumes. Delivery workers remain outside this check.
No public GitHub push is retried without the explicit publication permission
required after the previous refusal. Local commits are not GitHub backups.

Remaining scope is explicit: native/offline acceptance, journal/signing/delivery,
broader historical client-price snapshot reconciliation, full current-image release
checks and public CI are not approved by this result. A separate existing display
issue was observed in risk-driver badges: lowercase count codes can be formatted as
money (for example `open_issues` / `data_risk`). That counter/label cleanup is not
part of the completed accrual reconciliation and remains open. No 100% claim.
