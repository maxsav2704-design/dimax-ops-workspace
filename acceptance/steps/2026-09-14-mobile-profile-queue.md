# Mobile profile queue state: September 14, 2026

## Scope and decision

Mobile commit: `1e20ebb`. Follow-up to the account-bound cache guards.
The profile's misleading queue state is corrected and tested. The current
Android bundle and its local queue read were also checked on the connected phone.
This is not complete native gesture, sign-out or account-switch acceptance.
Release criteria and weights are unchanged; full release approval is not granted.

## Finding and changes

P2, misleading execution status: `profile.tsx` previously used `queue?.total` to
choose between pending work and "All local work is synchronized". The initial
`null` summary and a failed SQLite read therefore looked like successful sync.
The sign-out dialog reused the old summary without a fresh local check. The
screen also did not refresh its queue summary after background sync updates.

- `app/profile.tsx`: separate loading/error/ready states using the existing queue
  presentation rules; never equate an unread queue with successful delivery.
  Read again before opening sign-out confirmation. A failed check produces an
  explicit unknown-queue warning rather than an empty-queue confirmation.
- Keep account exit possible after a failed read, with a clear warning. Do not
  require successful synchronization before leaving an account: that would trap
  an installer with a blocked action or unavailable network.
- Pending/failed/blocked actions are included in the warning. RU/EN/HE text says
  that work stays on this phone for the same account, and exit does not send it.
  A verified zero count is described only as an empty outgoing queue, not proof
  that all business work or all server state is synchronized.
- Add a local-only retry control after a queue-read error. Its handler reads
  SQLite and does not dispatch sync or modify pending events.
- Reload on sync version changes, after successful or failed manual sync, and
  before sign-out confirmation. Manual sync still refreshes the authenticated
  user as before. Show the persisted last-sync value, not an inferred success.
- `getSyncStatusSnapshot` reads queue summary and last-sync state within the
  captured account's existing database activation queue. It propagates failures
  and checks the context again before returning. UI request sequencing and owner
  checks discard old results after identity changes.
- Existing theme/components, roles, API, money, work states, queue payloads and
  retry policy are preserved. No migration, dependency update or new feature area.

## Code verification

Commands used the existing Node 20.19.5 runtime and project dependencies, from
`mobile`, with no package installation.

| Check | Result |
| --- | --- |
| `vitest run --maxWorkers=1` | 354 PASS in 29 files, exit 0, 46.91 seconds |
| `tsc --noEmit` | PASS, exit 0 |
| `node scripts/validate-test-discovery.mjs` | PASS, 29 files, exit 0 |
| `git diff --check` | PASS, exit 0 |

Thirty tests were added: 27 queue-presentation cases across RU/EN/HE and three
local snapshot checks covering failed/blocked counts, SQLite failure and a login
change during a read. These service tests use mocked SQLite/network adapters;
they are not a physical-device SQLite fault-injection or React rendering test.
The remaining auth, sync, cache, project, journal and earnings tests still pass.

## Device verification and limits

- Authorized ADB device `a269dc99` was present. Before the change, its DIMAX
  workspace showed one queued work item. No sync/retry or work-action button was
  activated, and the existing event was not deliberately sent, discarded or edited.
- ADB taps on the bottom profile control did not produce a visible route change.
  The profile did open using the app's registered `dimax-installer://profile`
  deep link. This does not establish that the bottom navigation works by touch.
- Metro was restarted with the same isolated API base
  `http://127.0.0.1:18082` and automatic login disabled. Final bundle inspection
  returned HTTP 200, 8,668,666 bytes and confirmed both profile helper functions.
  The bundle was checked in memory, not saved as an artifact. Metro reported
  1,304 modules; the final server PID observed was `1504` (not a stable identifier).
- DIMAX was cold-started directly into the profile without reinstalling or
  clearing app data. Android reported `Status: ok`, `LaunchState: COLD`, TotalTime
  1243 ms. Metro delivered the current Android bundle in 3515 ms.
- The updated native profile displayed "Мой профиль" and "Ожидают действий: 1".
  This confirms visible local reading after that startup. It is not a byte-level
  comparison of the existing event payload, cache or retry metadata.
- ADB swipe commands also did not visibly scroll the profile, despite the app
  having focus, display 0 being active and input dispatch being enabled/not frozen.
  The exact cause is not established. One malformed display/source command was
  corrected, but successful command exit alone is not treated as a gesture PASS.
- A nonblocking question asks whether ordinary finger scrolling works on this
  phone. At this checkpoint that distinction remains unverified; do not label
  either the navigation code or device input restrictions as the proven cause.
- The actual sign-out confirmation, its cancellation, real account switch,
  reconnection/ACK and one-accrual-per-event scenario remain NOT VERIFIED through
  the phone UI. No credentials were cleared or replaced to force a pass.

## Cleanup and continuity

- The temporary app screenshot was inspected and then removed from Windows
  Temp (782,873 bytes). Its exact resolved path was checked before deletion.
- `/data/local/tmp/dimax-profile-check.xml` was removed from the phone, and its
  absence was verified. No new APK, database backup or exported bundle remains.
- Metro reuses the existing temporary log pair outside the project and is left
  running. Its normal cache may update. Docker, backend and admin were not changed
  or stopped; their full release gates were not rerun in this mobile-only step.
- The commit is local only. No GitHub push or remote backup is claimed under the
  existing public-destination publication restriction.

Next: establish a working, verifiable native input path; complete profile
confirmation/cancellation and navigation checks, then the isolated account-switch
and offline lifecycle acceptance without flushing the existing smoke-work queue.
