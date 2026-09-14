# Native offline completion and payroll time

## Scope

One controlled completion in DIMAX Acceptance A, Test Installer A-1. The user
pressed Installed on the real phone after API port 8001 was isolated. ADB touch
injection remains unavailable; no device security setting, app reinstall,
SecureStore export or direct SQLite/server work insertion was used.

- Project: `QA-IMPORT-20260910`, `6423143b-4122-4685-8f8f-20fe848bc8b7`.
- Door: `A-2-201-dira-EN-201`, `8e221753-3e55-47a4-978d-5cf4c14fb223`.
- Initial server state: NOT_INSTALLED, version 0, unlocked, no completed work.
- Effective installer rate: 250 ILS; A-1 total 750, project total 1,000 ILS.
- Native event: `1789391227346-9eoirtsxms`, happened at
  `2026-09-14T13:07:07.346Z`, previous version 0.

## Device and server evidence

| Check | Observed result |
| --- | --- |
| Offline native action | One local event, optimistic INSTALLED/locked, version 1 |
| Failed offline delivery | Event retained with network error and retry schedule |
| Server while disconnected | NOT_INSTALLED/version 0, zero events and accruals |
| Offline cold restart | Four installed locally, one queued; event identity/payload/time unchanged |
| Reconnection | Existing automatic retry delivered the event, no queue manipulation |
| Server delivery | One applied event, one completed work, one history entry, 250 ILS |
| Same original event replayed twice via actual API | Both ACKs `ok=true, applied=false`, no second accrual |
| Final native SQLite | Queue empty, cursor 24, all four door IDs/statuses/versions match PostgreSQL |
| Old account | All 13 tables and its one failed event unchanged |
| Admin after Refresh | 5/9 installed, revenue 5,400, payroll 1,250, profit 4,150 ILS |
| A-1 earnings API and native cache | Today 250, month 1,000 ILS |

The native earnings screen initially displayed 1,000 ILS with an explicit saved-copy
warning after a refresh failed during the resource-constrained backend check. On
the final post-restart check it displayed the same 1,000 ILS with Current data,
without the warning. Its six effective ledger rows include prior correction history;
this is not six installations. The full database ledger has five ORIGINAL, one
CORRECTION and two REVERSAL rows, net 1,000 ILS. The final four door records and
the single new completed-work row were independently reconciled.

The replay used a separate diagnostic login, revoked through logout-refresh.
It reused the original event from the native SQLite snapshot, not a fabricated
replacement. The phone first received its real successful ACK before these API
replays: a lost HTTP response on the physical transport was NOT injected.
Offline restart here means API isolation with Metro still serving the development
client, not a fully disconnected release APK.

## Confirmed High defect

The server stored installation time `2026-09-14T13:12:36.169702Z` instead of the
native work time `13:07:07.346Z`. Code inspection confirmed that both sync paths
dropped `happened_at` for door completion, although add-on completion already
receives it. This can move offline work into the delivery day's/month's earnings
and select a newer effective rate. Current acceptance totals were unaffected
because this event stayed within one day and tariff period.

Two PostgreSQL reproductions failed before the fix, one per sync transport:
work at 23:59 Jerusalem time on August 31 was booked after September 1 with the
later tariff. The run stopped after these two failures, exit 1, 46.81 seconds.

## Scoped correction

- Pass the existing optional `happened_at` through both sync paths into door
  completion. Existing requests and online completion without it retain server time.
- Resolve completion time once, shared by door time, rate lookup and ledger time.
  Legacy naive values mean UTC, consistent with existing sync replay comparison.
  Future client times are capped at receipt time. The phone's snapshot-sync event
  retains its raw client timestamp for audit; no new timestamp column was added
  to the legacy batch queue. This avoids future earnings from an incorrect clock.
- Keep existing stored rate snapshots, locks, version conflicts, tenant/assignment
  checks and idempotency. No new endpoint or DTO field; no schema migration.
- Do not rewrite past completed-work rows or replay old failed work. Historical
  cross-period cases need an explicit audit/correction, not an automatic backfill.

Ten added regressions cover both transports, UTC/offset/legacy-naive work times,
missing time and a future device clock. They compare actual stored completion time,
rate and amount across a Jerusalem month boundary and repeat every request.

Temporary SQLite snapshots were removed after comparison: 22 files, 3,871,576
bytes; the exact temporary directory was verified absent. Phone databases and
the old queue remain untouched. No new APK, bundle, screenshot or heavy artifact.

Post-fix backend verification: 33 PASS, 118.05 seconds, exit 0. This includes all
10 new time regressions, snapshot/batch repeats, missing rates, reassignment,
rollback, concurrent completion, as-of rates, direct/admin completion, financial
constraints and OpenAPI. Mobile sync regressions: 74 PASS in 3 files, 9.60 seconds,
exit 0. Backend repository-boundary verification and whitespace checks PASS.
A broad post-fix run reached its 600-second process limit without a pytest
summary. Docker recorded exit 124 and removed the temporary container; the shell
reported exit 1. It is NOT counted as PASS. The completed 33-test named set above
is the separate final verification, not a reinterpretation of that interrupted run.

Backend commit: `37059ea`. Only the acceptance API was restarted to load it.
The first 240-second readiness wait expired during slow startup; the same process
subsequently returned HTTP 200 on host `/ready`, with database ready, without a
second restart or observed OOM termination. The final phone screen shows current
earnings and the admin refresh still shows 5/9 installations and 1,250 ILS payroll.
Metro and both USB tunnels remain available; temporary test containers are absent.
The normal API on port 8000 was not restarted. No production deployment, new
post-fix native installation or retroactive rewrite of the accepted event occurred.
No full release, production approval or GitHub backup is claimed.
