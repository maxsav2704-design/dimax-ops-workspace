# Mobile acceptance: cold resync and unresolved work

## Scope and Device Boundary

The next planned item was native startup following the current Android build.
ADB again returned an empty device list. No device installation, login, database
read, offline action or native startup was performed. Work continued on the
adjacent source-level cold-resync item, not a substitute physical-device PASS.

Baseline mobile revision: `515cb12117727a069dab56da04a88039e4b5eeff`.
Source fix and tests: local mobile commit `040c02b`.
Backend, admin, API schemas, migrations and financial calculations are unchanged.

## Confirmed P1 Defects

### Incomplete or stale optimistic replay

`executeSync` previously reapplied only the outgoing batch after replacing the
local snapshot. That batch excludes events in retry backoff and entries beyond
the 500-event limit. It also predates work added or removed while the request is
in flight. The outbox payload could remain intact while the corresponding local
door status, issue or add-on fact disappeared, or an explicitly removed local
entry could be recreated.

### Stale scope after assignment changes

Reset replay previously recreated add-on and issue rows without validating that
their project/door remained in the installer's new authorized snapshot. Removed
door events were skipped but not marked as assignment conflicts. This is a local
cache/conflict-state defect; no server authorization bypass was demonstrated.

### Fresh server state overwritten by an old action

An unsuccessful acknowledgement after the snapshot could restore a door's old
`previous_*` fields over the newer server status/version. Unacknowledged stale
work could likewise overlay a newer unlocked door. A later manual retry/discard
could repeat the version rollback.

## Scoped Fix

- `mobile/src/modules/sync/service.ts`: after the snapshot, acknowledgements and
  missing-ack scheduling, read the current complete outbox, not the sent batch.
  Replay only PENDING/FAILED entries, in creation order; retain retry backoff and
  the 500-event network batch limit.
- Reconcile local optimistic work against the snapshot's project/door scope.
  Preserve revoked work in the outbox as `CONFLICT_ASSIGNMENT_CHANGED`; do not
  recreate its local issue, door update or add-on fact.
- Do not revert server door data on a rejection in a reset response. Completed
  acknowledgements are handled before replay, so accepted work is not recreated
  as a second optimistic entry.
- Preserve current door locks and versions during reset replay. Manual retry and
  discard also check version compatibility. A stale retry remains blocked with
  the existing `CONFLICT_INVALID_TRANSITION` code, rather than rewriting the
  previous-version payload or pretending it is new work.
- Reuse the existing queue, SQLite helpers and retry UI contract. No schema or
  migration change is needed; no business feature was removed.

## Regression Evidence

New `mobile/src/modules/sync/cold-resync.test.ts` has 15 cases. API/SQLite calls
are mocked, consistent with the existing sync suite. These are executable
service regressions, not real SQLite persistence or native-device evidence.

- Initial 13 cases: 11 FAIL, 2 PASS before the source fix.
- Two added follow-up retry/discard cases: 2 FAIL before their version guard;
  the other 13 were deliberately excluded in this narrow reproduction.
- Final focused run: 53 PASS (38 existing + 15 new), no skipped cases.
- Final complete mobile run: 204 PASS in 26 files, no skipped cases; 35.41 sec.
- TypeScript `tsc --noEmit`: exit 0.
- Discovery contract: all 26 test files covered; exit 0.
- Node 20.19.5, installed Vitest 4.1.10; one test worker.

The existing sync tests now allow the extra post-response outbox read. Their
request assertions still verify that forced cold resync sends no pending events.
No behavioral assertion was disabled to conceal a regression.

Local evidence under `artifacts/acceptance-20260909/`:

- `mobile-cold-resync-before-20260911.json`
- `mobile-cold-resync-recovery-before-20260911.json`
- `mobile-cold-resync-after-20260911.json`
- `mobile-cold-resync-full-tests-20260911.json`

Run the project commands from `mobile` with supported Node 20:

```powershell
npm test -- --maxWorkers=1
npm run typecheck
npm run test:coverage-contract
```

## Current Android Bundle

The existing `scripts/mobile-metro.ps1 -Action smoke` probe passed on temporary
port 59877 with isolated API `http://127.0.0.1:8001`, one worker and automatic
login disabled: HTTP 200, 8,648,489 bytes, 67 seconds, exit 0. The size and
error-payload checks passed. After completion, port 59877 had no listener and
no dated probe temporary directory remained. No test credentials were supplied.
Log: `artifacts/acceptance-20260909/mobile-cold-resync-bundle-20260911.log`.

This proves compilation/delivery of the updated Android JavaScript graph, not
native execution, server authentication or actual offline persistence. The
helper's `EXPO_OFFLINE=1` flag is not evidence of app-level offline operation.

The previously verified debug APK contains no embedded JavaScript. No native
files changed in this step and the native APK was not rebuilt again. It must use
the current Metro bundle during subsequent device testing.

## Remaining Acceptance

- Current-device install/startup and actual server authentication remain open.
- Offline restart, SQLite transaction interruption, lost-response replay and an
  account change while a sync request is in flight need separate runtime tests.
- This change is limited to cold-snapshot replay and related recovery actions;
  it does not claim an exhaustive audit of every incremental-sync/cache path.
- No live payroll, actual signing, email delivery, project or door was changed.
- Existing admin preview and Docker data were not stopped, reset or deleted.
- Frozen acceptance criteria and readiness percentages are unchanged. A07/A11/
  A12/A13/A14/A32 are not granted complete PASS on these service tests alone.
- Results and fixes are local only. No GitHub push was attempted; local commits
  do not meet the remote-backup requirement.
