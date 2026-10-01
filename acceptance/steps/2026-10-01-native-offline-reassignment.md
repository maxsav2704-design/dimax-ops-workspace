# Native offline completion after reassignment: PASS

Follow-up to `2026-10-01-native-offline-delivery.md`. This checkpoint covers
one real phone action rejected after the office changes the assigned installer.
It is not a full release, admin UI, or signed native-build approval.

## Scope and preparation

- Existing phone `a269dc99`, package `com.dimax.operations.installer`.
- DIMAX Acceptance A, isolated API 8001, database `dimax_acceptance` only.
- Project `6423143b-4122-4685-8f8f-20fe848bc8b7`.
- Door `be7cf067-eafd-441d-81bc-26cc16c8743c`, `B-2-201-dira-EN-201`.
- A-1 installer `4e946dc5-e084-57ac-a298-f9d74238df30`.
- A-2 installer `6971ffa7-3f62-5063-a87d-0acce1a4b437`.
- Backend revision `9b236ac`; mobile revision `f3ce4b0`.

The door initially belonged to A-2: NOT_INSTALLED/version 0/unlocked, no work
or accrual. It was temporarily assigned to A-1 and later returned to A-2 via
`ProjectAdminService.assign_installer_to_door` and `SqlAlchemyUnitOfWork`, the
same use case called by the admin API. Both calls checked the test environment,
database, company, project, current installer and door state before committing.
There were no direct SQL writes or manufactured completion/sync events.

The admin preview session was expired. These fixture assignments did not use
the browser or authenticated HTTP endpoint, so admin login/assignment UI is
not claimed as tested. No passwords, tokens or account permissions changed.
An initial preparation attempt stopped before any write because its guard used
the nonexistent `settings.APP_ENV`; the corrected guard reads the environment.

## Observed native sequence

1. Online cold launch delivered the sixth assigned door to A-1. The exact
   B-2-201 card showed NOT_INSTALLED/version 0 and its Installed action.
2. Removed only the phone's API 8001 reverse mapping; Metro 8081 stayed available.
   The user physically pressed Installed once and confirmed the queued action.
   USB-injected taps are not functional on this phone; no security settings
   were changed to bypass that limitation.
3. The UI showed one queued action and the previous 250.00 ILS daily earnings.
   Stopped DIMAX before exporting SQLite. Integrity check passed; A-1 had one
   project, six doors and one PENDING event, attempts 0. The target's optimistic
   local state was INSTALLED/version 1/locked.
4. Exact native event: `1790880635522-ezs7bt1akt`, DOOR_SET_STATUS / INSTALLED,
   previous version 0, happened_at `2026-10-01T18:50:35.522Z`.
   No payload, time, retry state or SQLite row was edited.
5. With the phone still disconnected, returned the server door from A-1 to A-2
   using the same guarded application service. Server state was still
   NOT_INSTALLED/version 0/unlocked with zero work rows.
6. Restored direct `tcp:8001 -> tcp:8001` and cold-launched the native sync queue.
   The real phone submitted the saved event. PostgreSQL recorded exactly one
   rejected sync event with `apply_error=CONFLICT_ASSIGNMENT_CHANGED`.
7. Native UI showed the assignment-changed explanation, one BLOCKED action,
   zero ready to send, no retry button and no navigation to the unavailable door.
   It advises contacting the office before discarding the action. The native
   screenshot was inspected, not a memory-backed browser preview.
8. A second stopped-app SQLite snapshot confirmed five remaining assigned
   doors, one project, and the reassigned door absent. The original event remains
   BLOCKED with the assignment conflict, attempts 1 and no scheduled retry.
   Its identity, type, project, original payload and timestamps are unchanged.
9. Cold-launched the queue again. The same conflict survived, attempts remained
   1, and the successful sync time advanced. The action was not silently dropped
   or automatically retried. It is deliberately left visible for review.

## Financial and isolation reconciliation

Read-only PostgreSQL verification after reconnect and the second cold launch:

- Target remains assigned to A-2, NOT_INSTALLED/version 0/unlocked.
- Target has **zero** completed-work rows.
- A-1 net total remains **1,250.00 ILS**; A-2 remains **250.00 ILS**.
- The previous B-1-101 installation and its 250.00 ILS accrual are untouched.
- Exactly one rejected server event for this native client_event_id.

`sync_events.applied_at` is also stamped by `mark_failed`; here it is
`2026-10-01T18:53:15.832475+00:00`. It is not proof of a successful installation.
The first read-only verifier incorrectly expected NULL; the final verifier
uses the repository's actual contract, the conflict code, unchanged door state
and zero completed-work rows. No production defect is inferred from that
verifier assumption.

Both SQLite snapshots passed integrity checks. All 13 legacy-account tables
are unchanged, canonical SHA256:
`bf95547abf1af9bb525949b2b5be1d73ed68c53187d15250f2cc366a16250a0c`.
Ordinary API 8000, real customer data and external notifications were not touched.

## Fresh automated checks

- Mobile: **98 passed / 3 files**, 10.80 s, exit 0. Existing Node 20 runtime,
  `vitest run src/modules/sync/service.test.ts
  src/modules/sync/presentation.test.ts
  src/modules/sync/sync-queue-screen.test.ts --maxWorkers=1`.
- Backend: **16 passed**, 46.97 s, exit 0. Assignment atomicity suite plus
  reassigned-install/no-accrual, assignment-conflict, incremental assignment
  delivery and previous-installer removal tests. Existing acceptance image,
  `docker compose -f docker-compose.acceptance.yml run --rm --no-deps -T`,
  both database URLs explicitly targeting `dimax_acceptance_tests`, plugin
  autoload disabled, `timeout 300 python -m pytest -q -p no:cacheprovider`.

No application code or migration change was required for this passing scenario.
Full backend/admin/mobile release gates were not rerun in this checkpoint.

## Cleanup and next step

Removed this check's stopped-app SQLite copies, tar archives, screenshot and
capture logs: **18 files / 13,307,584 bytes**. Cleanup checked resolved absolute
paths and reparse points. Removed the owned phone UI XML. No APK/export added.
The one-off test container completed and was run with `--rm`.

Phone API 8001 and Metro 8081 mappings are restored. No loss relay is armed.
The temporary browser login tab was closed; the user's preview tab was retained.
The existing-artifact admin preview on 4173 was started for the attempted UI
preparation, not rebuilt or certified as the latest source. This report is a
local Git checkpoint only, not a GitHub backup.

Next: native issue reporting/resolution without false installation/accrual,
then add-on quantity/rate/replay reconciliation. After those, native journal,
test signing, PDF/local-mail delivery and current-revision release gates remain.
Do not mark all A12, all sync/offline, or production readiness complete from
this single fixture. The visible test conflict is intentional and retained.
