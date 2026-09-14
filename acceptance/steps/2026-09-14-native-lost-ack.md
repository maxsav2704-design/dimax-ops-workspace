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

## Status

Physical completion and lost-ACK verification are pending the requested tap.
No native lost-response PASS, new accrual, full release or production readiness
is claimed at this checkpoint. The result and cleanup must be recorded before
closing the physical check. Local commits only; no GitHub publication is implied.
