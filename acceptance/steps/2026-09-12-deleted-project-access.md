# Installer access after project deletion

## Scope and Reproduction

Started September 12; verification continued September 14, 2026.
Baseline backend: `2e98c2f`; verified fix: local commit `53189d0`.
This follows the phone queue investigation: an old
queued installation refers to a deleted smoke project. That event was neither
sent nor removed. Initially ADB reported no device. On September 14, the owner
connected model 2210129SG; ADB authorized it and found the installed DIMAX app.

Priority: P1 / High access and payroll defect. Installer project snapshots
already excluded soft-deleted projects, but individual door operations loaded
the remaining door rows without checking their parent project. An authenticated
installer could still complete work, create an issue or submit an offline event
after the administrator deleted the project.

The regression uses real installer JWT login, real PostgreSQL and the existing
project deletion use case. Before the fix: **8 FAIL, 8 PASS, 36 deselected**, exit
1, 164.95 seconds. All eight deleted-project variants incorrectly succeeded;
the corresponding active-project variants passed. The failure is reproduced
for snapshot sync installation/non-installation/issue creation, batch sync
installation and all four online door/issue mutation routes.

## Implementation

- `app/modules/doors/infrastructure/repositories.py`: opt-in
  `active_project_only` lookup joins the parent project and enforces both tenant
  and soft-deletion boundaries. Locking installer reads hold the door and parent
  project locks until the existing unit-of-work transaction ends. Cached door
  state is refreshed after a competing writer, as before.
- Installer door guards/services and installer-scoped legacy completion use
  this lookup. Sync prechecks use the same locking boundary and return the
  existing `CONFLICT_ASSIGNMENT_CHANGED` result for an unavailable door.
- Installer issue creation, listing, media access and comment updates enforce
  parent project availability. Creation/comment writes use the locking lookup.
- Default repository lookup remains unchanged for administrative financial
  history. A deleted project does not erase completed work or prevent an
  administrator from creating an audited reversal/correction.

No endpoint, DTO, rate, accrual formula, status enum or database schema changed.
No migration is needed: `deleted_at` and the relevant relationships exist.
No event is silently marked applied or discarded because its project vanished.

## Verification

Added 23 regression cases: 16 active/deleted operation variants, two issue
visibility/edit variants, cached-read and stale-request-guard checks, a
PostgreSQL NOWAIT project-lock check and a historical payroll correction case.

Completed checks:

- Targeted backend run: **24 PASS, 56 deselected**, exit 0, 206.33 seconds.
- Related backend/architecture run: **76 PASS**, exit 0, 250.50 seconds. Covers
  assignment/completion races, batch sync, tenant isolation, payroll lifecycle,
  financial constraints, OpenAPI and all architecture tests. The two assignment
  snapshot cases also passed, including the case reached by the interrupted run.
- There are four overlapping transaction tests: **96 unique backend checks**,
  not 100. The earlier interrupted run is not counted as a completed gate.
- Mobile compatibility: **249 PASS in 27 files**, exit 0, 52.47 seconds, using
  Node 20.19.5 and Vitest 4.1.10 with one worker. TypeScript and test discovery
  also passed. These are source tests, not native SQLite/reconnect acceptance.
- `git diff --check` passed. Schema remains `0060_installer_journal_handoff`.

Runner: the existing `docker-compose.acceptance.yml` image and source mount,
separate `dimax_acceptance_tests` database, one pytest process, 384 MiB container
limit. The mutation checks use synthetic company fixtures. No normal
workspace or acceptance UI-demo records are used for mutation tests.

The interrupted imported-assignment fixture is absent from the test DB. Other
existing test-database data was retained; no broad cleanup/truncation was run.

## Resource Recovery

The original broad run spanned a host interruption and was explicitly stopped
after losing progress. It has no completed PASS result. Two fresh attempts
failed during Python imports with `OSError: [Errno 12] Cannot allocate memory`,
before running tests. Windows reported 264,936 KiB free physical memory out of
3,978,360 KiB total. This is not a business-logic test failure or a performance
benchmark.

Metro and the normal/acceptance API, MinIO and Mailpit services were temporarily
stopped, leaving both database containers and all volumes intact. Both successful
backend runs then completed. No image rebuild, cache purge or data-volume removal
was used. Runtime restoration and native launch are checked separately below.

## Commands

The initial broad invocation below was interrupted and is not a completed full
backend gate. Successful reruns used the same isolated runner with verbose
output, `PYTHONUNBUFFERED=1` and `-o faulthandler_timeout=90`.

The targeted run selected the three modified test files with:
`-k 'project_deletion or project_deleted or deleted_project or locks_project or admin_earnings_correction_creates_reversal'`.
The related run selected assignment atomicity, batch sync, multi-tenant isolation,
payroll lifecycle, financial constraints, OpenAPI, `tests/architecture`, plus
`test_installer_incremental_sync_receives_door_after_admin_assignment` and
`test_imported_door_assignment_reaches_installer_sync_without_leaking_unassigned`.

```powershell
docker compose -f docker-compose.acceptance.yml run --rm --no-deps `
  -e DATABASE_URL=postgresql+psycopg2://postgres:postgres@db:5432/dimax_acceptance_tests `
  -e TEST_DATABASE_URL=postgresql+psycopg2://postgres:postgres@db:5432/dimax_acceptance_tests `
  api python -m pytest -q `
  tests/integration/test_sync_installer_snapshot_api.py `
  tests/integration/test_door_assignment_atomicity.py `
  tests/integration/test_earnings_corrections_api.py `
  tests/integration/test_sync_batch_api.py `
  tests/integration/test_installer_phase2_api.py `
  tests/integration/test_multi_tenant_isolation.py `
  tests/integration/test_payroll_lifecycle.py `
  tests/integration/test_financial_integrity_constraints.py `
  tests/integration/test_openapi_contract.py tests/architecture `
  --tb=short --show-capture=no
```

## Runtime Restoration

After testing, all six API/MinIO/Mailpit services stopped for resource recovery
were started again. Both API readiness requests completed successfully:

- `http://127.0.0.1:8000/ready`: HTTP 200, database ready.
- `http://127.0.0.1:8001/ready`: HTTP 200, database ready.

The initial startup probes returned an empty reply/502 while imports and the
existing Alembic startup check were running; later probes above passed. Both
API containers reported no OOM kill and no restart loop. Mail delivery was not
exercised or granted acceptance by these readiness results.

## Connected Phone Follow-Up

Metro was restored on port 8081 with one worker, automatic login disabled and
API `http://127.0.0.1:18082`. The current Android bundle returned HTTP 200,
8,655,767 bytes. It was inspected in memory, not saved as another bundle file.
The first literal-inlining assertion did not match Expo's development format;
inspection of the actual `Object.defineProperties(process.env, ...)` preamble
and config binding confirmed the isolated URL and `false` auto-login value.
No application source correction was needed for that probe assumption.

Only USB port 8081 was forwarded. No tunnel to either live API was enabled.
Android launch of the installed `com.dimax.operations.installer/.MainActivity`
completed with `Status: ok`, `LaunchState: COLD`, total time 1,444 ms. Metro
also completed the device's bundle request. No install, app-data reset, account
switch, signing or delivery operation was performed.

The limited process log sample contained one error line:
`FrameInsert open fail: No such file or directory`. No fatal/ReactNativeJS error
was seen in that sample; the line's origin was not established. At the final
activity check another application was foreground, while DIMAX remained alive
in the background. The other application was not operated or captured. This
does not grant visual acceptance or prove complete native/offline behavior.

The old queue was not delivered to a working API. No SQLite copy/comparison was
made in this follow-up, so byte-identical local state is not claimed: automatic
offline retry/cache metadata may change. No queued work was manually discarded.

All temporary pytest containers were confirmed absent. No new APK, image build,
database dump or screenshot was created. Metro keeps two small runtime logs in
Windows Temp outside the project; its development server remains running.

## Remaining Limits

- This is server-side regression acceptance, not an end-to-end phone test.
  Device reconnect/ACK, fully offline restart and owner-signed release remain
  open. Phone API isolation is retained; queued work was not sent to the server.
- No administrator frontend source or mobile source changed. No new image,
  APK, dependency installation or database copy was required.
- Full backend/admin/mobile release acceptance and production approval are
  still open. Frozen acceptance criteria and readiness weights are unchanged.
- Local commits only. No GitHub push or remote backup is claimed; the earlier
  public-destination publication restriction remains in effect.
