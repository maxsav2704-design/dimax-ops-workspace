# Mobile authenticated cache isolation: September 14, 2026

## Scope and decision

Follow-up to the deleted-project backend fix and the earlier sync account guards.
The next bounded step checks non-sync mobile services across an account change.
Mobile source commit: `0a38b0c`.

The reproduced P1 cache-boundary defect is fixed and regression-tested locally.
This is NOT full native account-switch, offline, demo or production acceptance.
The criteria and weights in `acceptance/criteria.json` remain unchanged.

## Reproduced defect

Calendar, earnings, journal and project-detail services awaited an API response
and then used whichever SQLite identity was active at cache access time. The API
already guarded network responses, but this did not serialize subsequent cache
work with account activation. A delayed local phase could target a new account.
Several broad catches also treated `SessionChangedError` as an ordinary failure
and read the current cache or returned stale data as an online result.

Before implementation, 11 new service-level delayed-response/session-error tests
failed (exit 1, 2.25 seconds). These are deterministic tests with mocked API/cache
adapters, not an assertion of observed cross-account leakage on the actual phone.

## Implementation

- `mobile/src/lib/workspace-context.ts`: extracted the existing sync context
  mechanism into a shared helper. It captures the database activation identity
  and login generation and checks them when a local phase enters the existing
  database activation queue. Network requests never hold that local queue.
- `mobile/src/modules/sync/service.ts`: reuses the helper; payloads, retries,
  conflicts, cold-resync behavior and outbox retention are unchanged.
- Calendar and earnings services: bind requests to the originating generation;
  guard cache reads/writes and returned results; propagate session changes instead
  of presenting them as offline/cache availability failures.
- Journal service: the same protection covers list/details, preparation, refresh,
  mark-ready results and opening signed PDF links. A late link is not opened after
  an account change. An already-dispatched server mutation is not retroactively
  canceled by these client checks.
- Project service: hydrate details only inside the captured local context and
  reject a stale completion result.
- Existing valid-session network fallback and cache-write failure behavior are
  preserved. There are no changes to money, rates, statuses, endpoints or DTOs.
  SQLite schema and backend migrations do not need changes for this fix.

## Verification

Commands run from `mobile`, using the existing Node 20.19.5 executable and local
dependencies. No installation or framework upgrade was performed.

| Check | Result |
| --- | --- |
| Initial focused reproduction | 11 failed, exit 1, before the fix |
| Focused regression after fix | 11 passed, exit 0 |
| `vitest run --maxWorkers=1`, final source/tests | 324 passed in 28 files, exit 0, 43.71 seconds |
| `tsc --noEmit`, final | PASS, exit 0 |
| `node scripts/validate-test-discovery.mjs` | PASS, 28 files, exit 0 |
| `git diff --check` | PASS, exit 0 |

There are 75 additional tests: 73 service isolation cases and two checks through
the real database activation queue with mocked Expo SQLite connections. They cover
database changes, logout, login-generation changes, returning to the same owner
with a new activation, late network errors, rejected sessions, cache-phase races,
request generation binding, absent identity and stale journal-link side effects.
The existing sync/auth/offline regression suite also passes in the full run.

The first typecheck rejected dynamic imports in two added tests (four TS1323
diagnostics). Tests were adapted to the existing `vi.importActual` convention;
the project compiler configuration was not weakened. The complete test suite was
rerun after that correction. The earlier failing typecheck is not counted as PASS.

## Runtime and phone evidence

- The authorized Android device remained connected through ADB. USB reverse was
  restricted to Metro (`tcp:8081`); no API reverse was added.
- Before restarting DIMAX, an app-scoped UI inspection showed the cached installer
  workspace and one queued work item. No sync/retry, work completion, sign-out,
  account switch, signature, PDF delivery or queue deletion was requested.
- Metro was restarted after source checks. An initial instance accepted TCP but
  timed out on HTTP requests, including a 120-second bundle probe; the cause of
  that stall is not established. A subsequent launcher attempt failed because
  an empty `EXPO_NO_DOTENV` value is not a valid boolean; that temporary launch
  setting was corrected. These attempts are not successful runtime checks.
- Final Metro process at verification: PID `13004`. `/status` returned
  `packager-status:running`. This is an observation, not a reusable PID guarantee.
- The final Android bundle probe returned HTTP 200 and 8,662,218 bytes, exit 0.
  In-memory inspection confirmed `assertWorkspaceContext`, API base
  `http://127.0.0.1:18082`, and `EXPO_PUBLIC_E2E_AUTO_LOGIN=false`. The bundle was
  not exported to disk. Metro reported 1,304 modules.
- DIMAX was stopped and cold-started without reinstalling or clearing app data.
  Android reported `Status: ok`, `LaunchState: COLD`, TotalTime 1514 ms. Metro
  then reported another Android bundle delivery (11,662 ms, 1,304 modules).
- At the subsequent UI check, another application was foreground. No unrelated
  app content was inspected or manipulated; the DIMAX process was still present.
  A limited error-only sample for that process was empty. Neither observation is
  proof that every screen or account-switch workflow passed.
- The existing queue was NOT sent to port 8000 or 8001. The before-restart queue
  count is not a post-restart SQLite comparison. No claim is made that retry/cache
  metadata or all persisted bytes remained identical.

## Resource and artifact handling

- Tests ran serially with one worker. No Docker services, databases or volumes
  were stopped, recreated, deleted or migrated in this step.
- No new APK, database copy, screenshot archive or exported JS bundle was created.
  Metro reused its two small temporary log paths outside the project; its normal
  cache may update. The active Metro server is intentionally left running.
- The phone-only UI inspection file `/data/local/tmp/dimax-workspace-check.xml`
  was removed, and its absence was confirmed. Only project source/tests and this
  acceptance documentation are added to the repositories.
- The code commit is local. No GitHub push or remote backup is claimed; the
  previously recorded public-destination publication restriction is unchanged.

## Next bounded acceptance item

Verify native account/session transitions and the non-sync screen/local-action
paths on an isolated scenario. Preserve the existing account's outbox before
switching context; do not silently flush it, restore deleted smoke fixtures or
invent rates to make it pass. Then verify offline completion, cold startup,
reconnection and one accrual per accepted event with independent API reconciliation.

The current debug client still needs Metro for its JavaScript. This step does
not establish fully disconnected release startup, owner-signed release readiness,
external PDF/email delivery, full backend/admin release gates or production restore.
