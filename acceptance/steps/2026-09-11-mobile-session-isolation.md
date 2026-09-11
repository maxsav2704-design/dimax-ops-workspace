# Mobile acceptance: sync across account changes

## Scope

Baseline mobile revision: `040c02b`, following the cold-resync fix. ADB again
reported no device before and after the checks. Native startup/offline restart remains open; this step
verifies asynchronous account isolation in the mobile DB/API/sync layers.

No phone was installed, cleared or uninstalled. No live account was used, and
no real project, door, earnings, document, delivery or server record was changed.

## Confirmed Boundary Defect

Priority: P0 account/data-isolation boundary, reproduced at service level.
The existing API already rejects stale successful responses after a login
change, but that alone did not bind every sync phase to its original database.

- Sync helpers looked up the active database again after network awaits. A late
  response or failure could issue SQL against a newly selected account's cache
  or queue. The regression reproduction uses controlled API/DB test doubles;
  it does not demonstrate an actual server authorization bypass.
- Requests queued for an old account could begin execution in the next account.
- Automatic sync was coalesced globally, without checking database/login scope.
- An event batch prepared earlier was not explicitly bound to the login
  generation that existed when the user requested synchronization.

Initial regression run: all six new sync checks failed before the fix.

## Implementation

- `mobile/src/lib/db.ts`: each activation has a unique database context. It is
  invalidated on close, including A-to-B-to-A switches even when a DB file or
  handle is reused. Refreshing the same already-active identity preserves it.
- `withDatabaseContext` reuses the existing activation queue. Short local phases
  finish before their connection is closed; stale queued phases are rejected.
  It is not an additional SQLite transaction or a power-loss guarantee.
- `mobile/src/modules/sync/service.ts`: capture database and login context when
  sync/cold-resync is requested. Guard preparation, response application and
  failure handling. Network I/O is outside the database activation queue.
- Automatic requests coalesce only within the same database and login context.
  The existing single sync execution queue is retained.
- `mobile/src/lib/api.ts`: optional local `expectedAuthGeneration` binds the
  outgoing batch to its initiating login. Validate before session reading,
  after that await and before dispatch/retry. Never forward this local guard
  to HTTP options or JSON. Existing token-refresh behavior remains covered.
- `mobile/src/lib/errors.ts`: move the existing `SessionChangedError` into the
  shared error layer. Session cancellation does not delete or mark unresolved
  events as a business conflict. A previously recorded send attempt is retained.

No API payload, endpoint, role, financial rule, UI, database filename or schema
was changed. SQLite schema stays at version 10; no migration is needed.
Source fix and tests: local mobile commit `7d9a3fd`.

## Tests and Checks

Added 19 cases: eight sync-context cases, eight DB lifecycle/serialization cases
and three API dispatch-guard cases. Existing cold-resync tests retain their
business assertions and include the new DB/API context interfaces in mocks.

- Initial sync reproduction: 6 FAIL / 0 PASS; exit 1.
- Intermediate focused run: 90 PASS across API, DB and sync; exit 0. Two further
  sync cases were added afterwards for cold reset and session cancellation.
- Final full run: 223 PASS, 27 files, 0 skipped, 30.08 sec; exit 0.
- TypeScript initially found one narrow tuple annotation in the new test. The
  test annotation was corrected; the final `tsc --noEmit` run passed, exit 0.
- Discovery contract: all 27 test files covered; exit 0.
- Node 20.19.5, Vitest 4.1.10, one test worker. Repeated runs are not added to
  the test count.

The DB tests execute the real DB activation/context functions against a mocked
Expo SQLite adapter. Sync tests use controlled database/API doubles. API tests
execute the real API client against mocked fetch/session storage. None is a
physical-device or real on-disk SQLite durability test.

Local logs under `artifacts/acceptance-20260909/`:

- `mobile-session-isolation-before-20260911.json`
- `mobile-session-isolation-focused-20260911.json`
- `mobile-session-isolation-full-20260911.json`

Project checks, using supported Node 20 from `mobile`:

```powershell
npm test -- --maxWorkers=1
npm run typecheck
npm run test:coverage-contract
```

## Android Bundle

Current-source probe passed with `scripts/mobile-metro.ps1 -Action smoke`,
temporary port 63057, one worker, API `http://127.0.0.1:8001`, automatic login off
and no account credentials: HTTP 200, 8,650,804 bytes, 112.9 seconds, exit 0.
The size and error-payload checks passed. After completion, there was no listener
on port 63057 and no remaining dated probe directory. The helper cleaned up its
own temporary server/files; the admin preview was not changed.
Log: `artifacts/acceptance-20260909/mobile-session-isolation-bundle-20260911.log`.

The debug APK verified in the earlier checkpoint has no embedded JavaScript.
Native files did not change and the APK was not rebuilt again. It must load the
current Metro code during device testing. `EXPO_OFFLINE=1` in the build helper
does not prove offline behavior of the application.

## Open Acceptance

- Phone startup, offline restart, native SQLite interruption and account switch
  with persisted work still require runtime acceptance.
- The DB context is applied to sync phases here. Other cache repositories and
  non-sync local actions still need their own account-switch concurrency audit.
- Lost-response/idempotent replay and payroll reconciliation require their
  separate acceptance item. This change does not modify accrual logic.
- Backend/admin were not rebuilt or retested in this mobile-only step. Existing
  preview and working Docker databases were not stopped, reset or modified.
- A14 and overall release readiness are not granted complete PASS on these
  source tests. Frozen criteria/weights and percentages remain unchanged.
- Local commits are not GitHub backups; no push was attempted.

## Connected Phone Follow-Up

Later on September 11, an authorized Android device (model 2210129SG) became
available. The installed debug APK matched the previously verified SHA-256:
`2FF4362630E0E50412000F464FC9AED7341C5C659BD4C178ACB2C35AE61E7FA4`.
No reinstall, app-data reset or new native build was performed.

The owner explicitly approved a temporary database backup. Only the app's
SQLite DB, WAL and SHM were copied, while DIMAX was stopped, to a dedicated
Windows Temp directory outside the project. SecureStore was not exported.
The existing queue contained one failed `DOOR_SET_STATUS` installation event;
it was preserved rather than discarded or sent to an unchecked backend.

Metro served the current source over USB port 8081, with automatic login off.
The app API was deliberately set to unreachable phone loopback port 18082;
there was no API reverse tunnel. The Android bundle returned HTTP 200 and
8,650,803 bytes and contained the current DB/auth context guards and isolated
API address. The bundle was inspected in memory, not saved as an artifact.
This is an API-offline check, not a fully disconnected release-APK test.

Observed native results:

- First cold activity launch: `Status: ok`, total time 1,363 ms. Android reported
  DIMAX as the resumed activity. No fatal or ReactNativeJS error lines were
  observed in that process's filtered error log.
- After stopping only DIMAX, a second temporary DB/WAL/SHM copy was compared
  using read-only SQLite connections, including WAL state. `quick_check` was
  `ok`; schema version remained 10.
- All rows in 11 domain/cache tables were unchanged, including 33 projects,
  67 doors and two issues. Database owner, sync cursor and last-sync timestamp
  were unchanged. Every queued event's ID, type, project, timestamps and payload
  were unchanged. The one event remained `FAILED`; its attempts increased from
  three to five. Retry metadata is not claimed to be byte-identical.
- DIMAX was reopened afterwards: cold launch `Status: ok`, total time 907 ms;
  its resumed activity was confirmed, again with zero observed fatal/JS error
  lines. These observations do not prove successful rendering of every screen.
- All six temporary SQLite copies were deleted after the successful comparison:
  4,045,472 bytes removed, with their exact temporary directory confirmed absent.
  No DB, screenshot, bundle copy or extra APK was added to the project. Metro
  remains running for the debug app, with its small logs outside the project.

Screenshot capture was not authorized, so no screenshot was taken and visual
acceptance is still pending. Online retry/ACK, server idempotency, payroll
reconciliation, a native account switch and disconnected cold startup remain
separate acceptance checks. The existing event is still unsent; restoring API
access requires checking its intended server/account first. This follow-up
does not close A14 or advance the frozen readiness percentage. No GitHub push.
