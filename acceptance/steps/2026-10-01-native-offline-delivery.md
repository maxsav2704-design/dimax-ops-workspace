# Native offline completion and lost-ACK replay: PASS

Follow-up to `2026-10-01-native-chain-check.md`. The user physically pressed
Installed on the selected test door and reported no earnings. This was the
deliberately disconnected API phase of the acceptance check, not a lost work
record. No application code or database rows were manually changed in this step.

## Exact scope

- Phone `a269dc99`, existing package `com.dimax.operations.installer`.
- DIMAX Acceptance A / Test Installer A-1 only, isolated API on port 8001.
- Project `6423143b-4122-4685-8f8f-20fe848bc8b7`.
- Door `3b4a31b4-f872-4ca1-9373-69530af2bc71`, `B-1-101-dira-EN-101`.
- Native client event `1790878916862-ppw2ohti2d`.

## Observed sequence

1. Before reconnecting, native UI showed one failed queued door-status action,
   zero earnings today/month. Only USB Metro port 8081 was mapped.
2. DIMAX was stopped before copying its SQLite directory. The saved event
   survived process termination: DOOR_SET_STATUS / INSTALLED, previous version
   0, `happened_at=2026-10-01T18:21:56.862Z`, attempts 2, network failure.
   The local door was INSTALLED/version 1/locked. PostgreSQL still had
   NOT_INSTALLED/version 0 and no work/accrual for that door.
3. Started the existing exact-scope acceptance relay on loopback 18001 and mapped
   phone port 8001 to it. Cold-started the real native sync-queue route without
   modifying the queued event, its timestamps, payload or retry metadata.
4. Relay recorded, for the same native event ID:
   `ack_dropped`, then `ack_forwarded` with `applied: false`. The first successful
   server acknowledgement was deliberately lost; the actual phone resent the
   event and received an idempotent acknowledgement. No SQL/API substitute event.
5. Native queue became empty with successful last-sync time 21:27. PostgreSQL
   contained exactly one ORIGINAL/DOOR work row: quantity 1, rate 250.00 ILS,
   amount 250.00 ILS. Door INSTALLED/version 1. A-1 net total changed from
   1,000.00 to 1,250.00 ILS; A-2 remained 250.00 ILS.
6. `completed_at` is the original offline time, 18:21:56.862 UTC / 21:21 local.
   Server `created_at` is 18:27:16.794079 UTC. Completion time was not replaced
   by delivery time.
7. Restored the direct phone mapping `tcp:8001 -> tcp:8001` and stopped the
   verified relay process. Native Earnings / Today / selected project visibly
   showed **250.00 ILS**, one work row, current data.
8. A second stopped-app SQLite snapshot confirmed zero pending events, one
   project, five installed assigned doors, and the target at version 1/locked.
   Both databases passed integrity checks. All 13 legacy-account tables matched
   the pre-delivery snapshot and the previous checkpoint's canonical SHA256:
   `bf95547abf1af9bb525949b2b5be1d73ed68c53187d15250f2cc366a16250a0c`.
9. Cold-started Earnings again: the same 250.00 ILS and one work row remained
   visible. The phone is left on that screen with normal acceptance API access.

## Boundaries and cleanup

This closes the physical offline-completion, durable queue, reconnect, lost ACK,
native resend, exactly-once accrual and visible earnings chain for this fixture.
It does not close every-button, native journal/signature/delivery, reassignment
while offline, all locales, or full-release acceptance. Prior automated test
counts are not reported as newly rerun here. Ordinary API/database on port 8000,
other companies/accounts and real notifications were not modified.

No fault injection remains armed. Temporary SQLite copies, relay logs and phone
UI XML were removed after reconciliation with absolute-path/reparse checks.
No APK/export created. Local Git record only; no GitHub push.
