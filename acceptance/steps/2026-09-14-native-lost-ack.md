# Native lost-acknowledgement acceptance

## Scope

Continue the open physical delivery check without replaying old failed work or
rewriting an installed door. Use only DIMAX Acceptance A and its existing project
`6423143b-4122-4685-8f8f-20fe848bc8b7` (nine-door Excel acceptance fixture).

Selected door: `3b4a31b4-f872-4ca1-9373-69530af2bc71`,
`B-1-101-dira-EN-101`, previously NOT_INSTALLED, version 0, assigned to A-2.
It was assigned through the real admin UI to Test Installer A-1, whose rate for
its type is 250.00 ILS, effective 2026-01-01. No completion was simulated in SQL.

## Automated checks completed

The previously unfinished backend reassignment test was rerun alone in
`dimax_acceptance_tests`, with a 180-second bound and a 45-second diagnostic
traceback timer. It PASSED: one test, 23.92 seconds, exit 0. Setup 4.31 seconds,
call 7.83 seconds, teardown 3.69 seconds. This confirms the old installer's batch
completion cannot create earnings after reassignment. It is not a full backend
suite result and does not retroactively turn the earlier incomplete run into PASS.

`scripts/acceptance-sync-relay.mjs` is an acceptance-only loopback HTTP relay.
Its CLI forwards to the isolated API on port 8001, never the normal API on 8000.
It drops exactly one successful APPLIED acknowledgement for one event matching
company, user, project, door and INSTALLED status. Other scopes, multi-event
batches, non-applied responses and unrelated routes pass through. JWT claims only
select fault scope; authentication remains entirely the backend's responsibility.
The original request body and authorization reach the backend unchanged. The
relay logs event ID/result only, not credentials or request/response payloads.

Fourteen Node HTTP tests PASS, final duration 2.31 seconds. These test the relay
with a fake upstream; their accrual assertion is not native/PostgreSQL evidence.
The tests are also included in the workspace quality-gate workflow.

## Native preflight

Phone `a269dc99`, package `com.dimax.operations.installer`.
Baseline SQLite schema 11 and integrity checks PASS. Current A-1 database had
four installed doors and zero queued events. The old account's failed event and
all tables were copied for later integrity comparison, not submitted or deleted.

The missing USB Metro mapping initially caused a native dev-bundle loading error.
Host Metro was healthy. Restoring `tcp:8081 -> tcp:8081` and opening the existing
dev client fixed startup without clearing app data or building/installing an APK.
The target project then displayed A-1's five assigned doors, four installed,
zero queued events and a search restricted to B-1-101-dira-EN-101.

Admin remains on the direct API. Only the phone's API is routed through loopback
port 18001 for the controlled check. An observer will isolate its API tunnel and
stop DIMAX after the first dropped ACK, before the automatic retry, so the real
queue can be read consistently. A physical tap was requested from the user;
USB taps are not used and no event is manufactured in SQLite.

## Follow-up results

The 600-second observation window ended without a matching completion. The relay
log contained only its startup line, not an `ack_dropped` event. The observer
exited 2 without disconnecting or stopping the phone. The direct API tunnel was
then restored (`tcp:8001 -> tcp:8001`) before stopping the verified relay PID.
Metro remains on `tcp:8081 -> tcp:8081`. Fault injection is no longer armed.

The user authorized operating all controls remotely. A fresh shell touchscreen
tap at the observed Profile button returned exit 0, but the project screen
remained unchanged. This is not evidence of a successful press. No cause of the
ignored input was established, and no Android security setting was changed.
Registered deep links still navigate successfully. Windows window discovery
eventually recovered after two timeouts and a helper reset; it exposed no open
phone-control window. No new mirroring software was installed.

A separate four-case backend replay attempt exceeded its 180-second bound.
Docker's `die` event recorded exitCode 124 and execDuration 186 seconds; the
outer Compose shell returned 1. It is NOT counted as PASS.

The remaining five cases were rerun together with a 450-second process bound:

- `test_sync_lost_response_replay_keeps_one_installation_and_accrual`: all four
  timestamp variants PASS, including two repeated deliveries per variant.
- `test_bulk_reassignment_notifies_previous_installer_removed_from_you`: PASS.
- Final pytest summary: **5 passed in 156.88 seconds**, shell exit 0.

A 45-second diagnostic traceback during bulk reassignment showed FastAPI route
and response-field construction; the test subsequently passed (51.90 seconds for
its call). This is not a proven production performance cause or a database-lock
diagnosis. Together with the single batch/no-accrual test above, all six cases
from the earlier incomplete checkpoint now have successful follow-up results.
This does not constitute the complete backend release suite.

## Data reconciliation and cleanup

Consistent final SQLite copies were read with DIMAX stopped. Both integrity
checks passed. All 13 old-account tables equal their baseline rows, including
the one FAILED event. Current A-1 ownership is correct: one project, five doors
(four INSTALLED, one NOT_INSTALLED), zero queued events and no foreign-project
door. The selected B-1-101 door remains NOT_INSTALLED, version 0.

Read-only PostgreSQL confirms the same target assignment/state. Across the whole
project there are five installed and four uninstalled doors. Net ledger totals
remain A-1 = 1,000.00 ILS and A-2 = 250.00 ILS. No new work or accrual occurred.
The selected uncompleted door remains assigned to A-1 for the pending native
check; A-1 has five assignments rather than the earlier four. No project or door
was created or removed, and no completion was manufactured through SQL/API.

Removed the exact owned temporary snapshot/log directory after verifying its
resolved path, parent and absence of reparse points: 15 files, 3,485,767 bytes.
The directory and all one-off acceptance test containers are verified absent.
No APK, exported bundle or screenshot was retained. The existing Metro logs and
server remain necessary for the dev client. DIMAX was reopened; its final UI
shows the target project, 4/5 installed, zero queued events and the target filter.

## Status

Server replay/reassignment checks and relay isolation tests PASS. The physical
lost-ACK and offline-reassignment workflows remain **NOT VERIFIED** until actual
button input can be executed and observed. Re-arm the relay and observer before
attempting that completion; the current phone connection is deliberately normal.
No native lost-response PASS, full release or production readiness is claimed.
Local commits only; no GitHub publication is implied.
