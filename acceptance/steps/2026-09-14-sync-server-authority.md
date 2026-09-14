# Offline conflicts: authoritative server door state

## Scope and finding

Follow-up to native offline completion, limited to lost acknowledgements and
assignment/status conflicts. No new phone installation, reassignment, payroll
correction or acceptance fixture was created in this step.

A High mobile consistency defect was reproduced: server installation at version
N+1 is indistinguishable from an optimistic installation at version N+1 if only
status and version are compared. A rejected event in a delta response could undo
the server state locally. Even after a cold snapshot preserved it, later removing
the rejected event from the queue could undo it. Manual retry could overwrite the
server's reason/comment while awaiting the duplicate acknowledgement.

## Correction

Mobile commit `2bd4b4f`:

- SQLite schema 11 adds `pending_events.server_state_received`, default 0.
- Snapshot/delta application records server authority transactionally with door
  data. Delta marking is restricted to queued door events for that door.
- Rejection, discard and manual retry preserve a received server state, even at
  the same version as the optimistic operation.
- Reapplying compatible optimistic work after a snapshot clears the local marker,
  so cancelling a genuinely local change still works.
- Original event ID, payload and timestamp remain unchanged and the marker is not
  sent through the API. Existing queue/account separation and financial logic stay
  intact. No backend API or PostgreSQL migration is required.

This is not a repair of previously corrupted caches or a retrospective review of
old conflicted events. A fresh sync establishes authority for migrated events.

## Completed source checks

- Three new reproductions failed before the correction, exit 1.
- Initial focused run: 91 PASS in four files, 13.40 seconds, exit 0.
- Final complete mobile Vitest run: 401 PASS in 32 files, 52.09 seconds, exit 0.
- TypeScript, test discovery (32 files) and whitespace validation PASS.
- Actual migration SQL executed against an in-memory copy of the old phone DB:
  original queued fields unchanged, default marker 0 and integrity check OK.
  Actual delta SQL checked for door scoping, unrelated/add-on events, malformed
  JSON and transaction rollback. This did not modify either phone database.

## Backend check limitation

A separate six-case PostgreSQL run requested the snapshot duplicate-delivery
tests, bulk reassignment notification and batch reassignment/no-accrual test.
The command had a 600-second process limit and produced progress but no pytest
summary; shell exit 1. No individual result or exact termination cause is inferred
from progress dots. It is NOT counted as PASS. The temporary test container
`dimax_acceptance-api-run-d978794cf1c4` was removed. No backend source was changed.

## Native verification

Consistent temporary snapshots were taken with DIMAX stopped. Baseline: old
account schema 10 with one failed event, current A-1 schema 10 with zero queued
events and four installed doors. Both integrity checks passed.

The first cold launch showed A-1, four installed doors and an empty queue, but
the database remained schema 10. Direct bundle inspection confirmed that Metro
was serving old code, without the new column or schema version. This launch is
NOT evidence of successful deployment.

Metro recovery on this 4 GB host encountered startup/request timeouts. Available
physical RAM was approximately 263 MiB. Only the acceptance API was temporarily
stopped; the database, admin preview and normal API were not stopped. Metro was
restarted in CI mode with one worker. Hot reload/file watching is disabled in this
temporary acceptance runtime: subsequent source changes require a Metro restart.
No project environment file was changed and auto-login remains disabled.

The cold Android compilation took 290.372 seconds, exceeding its 240-second
request timeout. Its completion was subsequently observed in the Metro log. The
actual Hermes URL from the phone manifest was then verified: HTTP 200, 8,677,083
bytes, schema 11 and new metadata present, no test password embedded. No bundle
file or APK was saved. Both USB tunnels remain unchanged (8081 and 8001).

The updated native cold launch displayed A-1 and four installed doors. Final
SQLite inspection confirmed schema 11 and integrity OK in both account databases.
The legacy-owner probe also legitimately migrates the old database; it is not
expected to remain at schema 10. All 13 original old-account tables match the
baseline exactly; its one FAILED event remains unchanged, with the new marker 0.
The current account has zero queued events and its four doors, project, owner,
cursor and business caches match the baseline. Only `last_sync_at`, cache
`updated_at` and cache payload `generated_at` changed. Earlier strict comparisons
that expected schema 10 for the old DB or unchanged cache refresh timestamps were
not passes; the final structured comparison verified those precise differences.

Acceptance API was restarted and `/ready` returned HTTP 200/database ready.
Read-only PostgreSQL reconciliation: five INSTALLED and four NOT_INSTALLED doors;
A-1 ledger total 1,000.00 ILS and A-2 250.00 ILS. No new ledger operation occurred.
The final earnings-screen capture was skipped because DIMAX was not foreground;
no other application was inspected. Earnings cache content was verified against
its baseline instead. This is not a final visual earnings-screen acceptance.

Temporary SQLite snapshots and comparison metadata were removed after checking
the exact resolved directory and rejecting reparse points: 22 files, 4,628,525
bytes. The directory is verified absent. Phone databases remain untouched by
cleanup; no additional APK, saved bundle, screenshot or test container remains.
The small reused Metro stdout/stderr logs remain necessary for the running server.

No physical lost-ACK injection, offline reassignment on the device, full release
or production approval is claimed. Commits are local; no GitHub backup is claimed.
