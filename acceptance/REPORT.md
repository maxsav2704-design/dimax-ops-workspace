# Release acceptance progress: September 11, 2026

## Decision

Full live-demo, pilot and production approval are NOT granted. This is an
intermediate evidence record, not a completed acceptance report. Criteria and
weights remain frozen in `criteria.json`; no untested workflow is marked PASS.

## Latest Checkpoint

[Mobile cold resync](steps/2026-09-11-mobile-cold-resync.md) records reproduced
P1 defects in full-snapshot optimistic replay, revoked-assignment handling and
stale door rollback. Mobile fix `040c02b` passes 204 tests in 26 files, TypeScript
and test discovery. The updated Android bundle probe passed (HTTP 200, 8,648,489
bytes, exit 0); actual device startup, SQLite/offline persistence and full sync
acceptance remain open.
No backend, admin, money or live project data changed; no remote backup is claimed.

[Current mobile native build](steps/2026-09-11-mobile-native-build.md) records a
successful debug APK build at clean mobile source `515cb12`, with verified
package/SDK/signature and all four native architectures. The debug APK contains
no embedded JavaScript. A separate current Android Metro bundle probe passed:
HTTP 200, 8,646,782 bytes, exit 0; its temporary server and files were cleaned up.
No phone is detected, so installation, native startup and offline operation
remain unverified. This checkpoint is local only, not a GitHub backup.

[Mobile preflight and safe launch](steps/2026-09-11-mobile-preflight.md) records
the first mobile acceptance item: no connected ADB device, an unbooted configured
emulator, available build tools and a saved APK from an older source revision.
Mobile fix `515cb12` removes implicit seeded automatic login and requires an
explicit test API/account for the device launcher. All 189 mobile tests, 14
launcher checks, typecheck and Expo configuration validation pass locally.
At that checkpoint, native launch, a fresh APK, offline workflows and remote CI
were unverified. The build and bundle evidence above supersedes only its build
limitation; the frozen readiness criteria are not advanced.

[Payroll lifecycle verification](steps/2026-09-11-payroll-verification.md) records
the completed live correction/cancellation/reinstallation chain, independently
reconciled ledger totals, 69 completed backend checks and 62 admin tests.
It also records the project page's Decimal-string/USD display defect and its
scoped frontend correction, successful production build and standalone startup fix.
Final build/runtime checks are recorded in that file;
this is not full release or native/offline approval.

[Assignment/completion acceptance](steps/2026-09-11-assignment.md) records a
reproduced ownership/concurrent-completion defect, backend correction `db007e8`,
109 expanded integration checks, 39 architecture/security/OpenAPI checks and 77
mobile source compatibility checks. Actual UI assignment, separate installer
visibility and three completions reconciled with payroll 750 and revenue 3400.
This is web-client evidence, not native/offline acceptance.

[Dashboard window correction](steps/2026-09-11-dashboard-window.md) records the
separate defect discovered during reconciliation: a module-level timestamp kept
new work outside the dashboard's period. Correction `0ffb4f2` passes 32 focused
and related UI regressions plus the TypeScript/24-page production build. A fresh
live route-return check shows the fourth installation and payroll 1000 without
a full reload. Final synthetic state is 4/9 installed, revenue 4400, payroll 1000;
the earlier three-work reconciliation remains recorded as an intermediate state.

[Live Excel and session acceptance](steps/2026-09-11-import-session.md) remains
the evidence for JWT recovery, nine imported synthetic doors, duplicate prevention
and strict invalid-workbook behavior. Earlier workspace/frontend checkpoints were
published through `afbe415`/`52b59fe`. Latest backend/frontend publication was
separately rejected pending explicit permission for the public destinations;
local commits are retained. No full new-revision release or production approval.

## Environment and Resources

- Windows host: 3,978,360 KiB usable physical memory (nominal 4 GB).
- Initial free RAM: 236,040 KiB; available commit headroom: 1,700,192 KiB.
- Initial free C space: 8.48 GiB after the separately approved cache cleanup.
- During checks: 214 MiB free RAM, 1,029 MiB commit headroom, 3.90 GiB free C.
- After stopping the test DB: 3.88 GiB free C. Full concurrent local release
  builds are blocked by resource headroom. No further files were deleted.
- Docker reported about 974 MiB available before the narrow test. Observed
  check-container memory was 148.5 MiB under its 384 MiB hard limit; test DB
  used 32.43 MiB under 256 MiB. No second frontend or emulator was started.
- Isolated database: `dimax_acceptance_tests`, Alembic
  `0060_installer_journal_handoff`. UI-demo DB and working company are separate.
- Normal API/admin were left running. Acceptance DB was stopped after tests;
  its volume was retained. Normal delivery/maintenance/sync workers were already
  stopped before this step and were not exercised or declared operational.

## Defect Register

### P1: Installer earnings use a different day from the workspace

Status: FIXED AND VERIFIED locally and by the full backend CI gate.

Reproduction: create a synthetic completed installation for 250 ILS at
2026-09-06 21:30 UTC (September 7, 00:30 in Jerusalem). Request installer earnings
for September 7. Before the fix, day/week total and month `today_total` omitted
the work. Day grouping also used the stored UTC date.

Cause: `earnings/application/installer_api_service.py` used UTC calendar ranges
and `.date()` directly, while the installer workspace already used Jerusalem.

Fix: local calendar boundaries, local day/week grouping and a single default
anchor date per summary. UTC storage, decimal amounts, rate snapshots,
accrual timing, correction/reversal rules, API fields and permissions unchanged.
No migration required: the stored timestamp already has timezone support.
Cached offline responses refresh on the next successful online earnings fetch.

Files in backend commit `e5b95b4`:
- `app/modules/earnings/application/installer_api_service.py`
- `tests/integration/test_installer_phase2_api.py`
- `TESTING.md`

Evidence:
- Before patch: 9 failures, 23 deselected, 64.23 seconds; exit 1.
- After patch: 76 PASS, 242.50 seconds; exit 0.
- 27 added timezone cases cover day/week/month, midnight, month/year boundaries,
  implicit current date, workspace totals, DST range ends, unchanged stored data.
- Existing correction, financial constraint and calendar tests passed alongside.
- Local ignored logs: `artifacts/acceptance-20260909/timezone-before.log` and
  `timezone-after.log`. These are API tests, not UI or device evidence.

## Timezone Checkpoint Checks

| Gate | Exact revision | Result | Evidence |
| --- | --- | --- | --- |
| Backend full gate | e5b95b4c8af2a7c4a792fdc247cd3ad7242b33b2 | PASS | https://github.com/maxsav2704-design/dimax-ops-backend/actions/runs/34487005870 |
| Admin source gate | 51fa91d21de2f66a85fba563af1747ee5180945e | PASS | https://github.com/maxsav2704-design/dimax-ops-frontend/actions/runs/34486306168 |
| Mobile source gate | c17810e2a13d5bcfb53dd7ee79d8c42bba71df57 | PASS | https://github.com/maxsav2704-design/dimax-ops-mobile/actions/runs/34486343747 |

Backend passed 365 integration tests and 38 architecture/security tests. OpenAPI
and error-contract jobs passed (1 and 30 tests, overlapping integration coverage,
not added again). Clean/legacy migration and separate backup/restore jobs passed.
GitHub's checkout-action Node runtime warning remains a tooling maintenance item;
it did not fail these jobs. No warning was suppressed.

Admin passed its lint/test/TypeScript/production-build workflow (24 generated
pages). The local `next-env.d.ts` and `tsconfig.json` retain generated acceptance
output paths from the interrupted dev run; the remote result covers the commit,
not these uncommitted generated differences. No frontend feature changed here.
Mobile passed 176 Vitest tests, security/config/type checks and 17/17 Expo Doctor
checks. No native build, physical device or signed release was tested this step.

The backend fix was pushed to the existing release branch. The local workspace
API was restarted after CI passed to load it, without rebuilding images or
removing data. The normal workspace command checks Alembic head on startup;
this change adds no migration.

The removed cache directories were not recreated. Read-only follow-up checks
did not identify the entire additional disk-space consumption: the Windows
pagefile remains 11.5 GiB, the logical Docker data VHD size remains 37.896 GiB,
and several protected/reparse directories were excluded or inaccessible. Do not
attribute the decrease to a particular component without allocation evidence.

## Import Checkpoint

The next step is recorded in [the import checkpoint](steps/2026-09-10-import.md).
It supersedes the earlier bootstrap-repeat pending status, records the numeric
import fix and full backend gate, and distinguishes the blocked local UI run
from automated verification. No production approval is implied.

Runtime recovery and subsequent fixture/readiness corrections are recorded in
[the runtime checkpoint](steps/2026-09-10-runtime.md). It supersedes the pending
Docker restart and bootstrap-normalization status above; UI acceptance is separate.

## Remaining Acceptance

The financial lifecycle follow-up is recorded in
[the payroll checkpoint](steps/2026-09-11-payroll.md), including confirmed defects,
local fixes and explicitly pending verification. It does not close A15 by inference.

- Continue the isolated UI demo from the 9 imported doors with calendar actions.
  Assignment, separate visibility, base completions and the corrected dashboard
  route-return were observed; preview counting/locale issues remain open.
- Reconcile the independently calculated base/addon/correction/reversal example
  across admin, mobile and reports; the narrow timezone fix does not prove A15.
- Offline restart/reconnect, retries, reassignment, cold resync and account switch
  require fresh workflow evidence; do not use source tests as a substitute.
- Project journal, every RU/EN/HE PDF page, test signing and Mailpit attachment
  receipt remain unverified in this run. Never sign real customer documents or
  send messages to actual recipients during acceptance.
- Production configuration, external test inbox, HTTPS, owner signing and fresh
  physical-device acceptance remain separate prerequisites.
- Fixture normalization/bootstrap completed after Docker recovery. Complete demo
  reproducibility by another person still requires acceptance evidence.

No readiness percentage is advanced by this intermediate step. Full criteria
results and the investor demo script must be completed from observed workflows,
not inferred from these successful source checks.
