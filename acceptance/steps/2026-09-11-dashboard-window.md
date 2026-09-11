# Live dashboard window, September 11, 2026

## P1: New Work Was Missing from the Dashboard

The assignment/completion UI scenario produced three installations, revenue
3400 and payroll 750. Installer earnings and the project plan/fact report agreed
with read-only PostgreSQL queries. The main dashboard nevertheless showed zero
installations, zero revenue and zero payroll for its rolling seven-day period.
Navigating away/back and automatic refresh did not advance it. A full browser
reload showed three installations and payroll 750 without any database changes.

`src/views/Index.tsx` created `DASHBOARD_TIME_WINDOW` at module load. Every
refetch reused that end timestamp, excluding work completed after the module
loaded. The upcoming calendar window was frozen the same way. The dispatcher
query refreshed independently, making the page look fresh despite stale totals.

## Correction

Frontend commit `0ffb4f2`:
- Build report/calendar time windows inside their query functions on each fetch.
- Keep stable query keys so advancing time does not create an unlimited cache.
- Derive the displayed current date from successful query update times, using
  the component opening time only until a response arrives.
- Preserve the rolling seven-day definition, 30-second polling, cached-data
  warnings, permissions, existing layout, routes and API contract.
- Add refetch/remount regressions and document the live verification procedure.

No data migration, rate changes, accounting changes or customer data edits.

## Verification

- Before fix: 2 FAIL / 4 PASS, 18.19 seconds. Both regressions received the
  module's original `date_to` instead of the advanced clock.
- After fix: 6 PASS, 21.58 seconds. Report bounds and calendar bounds advance;
  newly completed work and payroll appear; the cache remains at three queries.
- Targeted ESLint and staged `git diff --check`: PASS.
- Expanded admin regression: 32 PASS across Index, DispatcherBoard,
  InstallerProjectPage and InstallerEarningsPage, 84.96 seconds, single fork.
  This count includes the six dashboard tests above.
- Production-mode Next build with webpack, one worker and the isolated output
  `.next-acceptance/live-window-20260911`: PASS, exit 0. Compilation, TypeScript
  and all 24 generated pages passed. Normal `.next` output was not deleted.
- Replaced only the verified preview process on loopback port 4173. New preview
  PID 18988 uses the isolated API on 8001; it does not point to customer data.
  Existing `next start`/standalone warning remains a local-preview limitation,
  not evidence of a verified production deployment. Logs are local and ignored:
  `artifacts/acceptance-20260909/preview-live-window.{stdout,stderr}.log`.

## Fresh Live Check

After loading the new build, owner saw three installations and payroll 750 on
the main dashboard. In the same browser, without another full reload, owner
logged out, A-1 logged in and completed `A-1-102-dira-EN-102`, then owner logged
in again. The main dashboard showed four installations, five remaining and
payroll 1000. The old module-constant implementation had failed this scenario.

Read-only SQL confirmed four installed doors worth 4400, five pending worth
5400, and exactly four completed-work entries: A-1 = 750, A-2 = 250. There are
still nine doors worth 9800 in total. The dashboard intentionally retains its
existing compact revenue formatter (`4k NIS`), so the exact 4400 is checked
against the detailed report/database rather than inferred from that rounded tile.
The actual project plan/fact screen also showed 4/9 (44.44%), actual revenue
4400, payroll 1000 and profit 3400; planned totals remained 9800/2250/7550.

Screenshot inspection found the new dashboard populated and interactive; browser
error/warning logs were empty at the check. This is observed route-return evidence.
The auto-refetch path and calendar bounds are covered by the clock-advance tests;
no separate simultaneous native-device/browser polling scenario is claimed.

Full current-revision frontend CI has not run. Its previous successful result
covers `52b59fe`, not this commit. Publication of `0ffb4f2` to the public frontend
repository was rejected by the permission reviewer. Explicit permission naming
the commit and destination was requested; no alternate upload was attempted.
The commit remains local. Backend publication remains separately pending.

This is not whole-dashboard visual/locale acceptance or production approval.
