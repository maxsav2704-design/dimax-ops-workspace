# Button audit, 2026-09-14

## Scope and safety

Admin at `http://127.0.0.1:4173`, isolated API at port 8001, company
DIMAX Acceptance A. Physical installer device uses the same acceptance company.
This is a workflow audit, not a claim that every control has passed.

No real project, door, assignment, completion, accrual, signature or outgoing
message was changed. One temporary unassigned calendar inspection was created,
edited and deleted in Acceptance A. Unsaved test forms were discarded. No phone security
setting was changed. Legacy-account SQLite/outbox data was not modified.

## Confirmed findings and changes

1. Calendar creation/editing used an unbounded custom overlay. At 509 x 468,
   the form extended from y=-186 to y=654; the submit button was below the
   viewport. Reused the existing scrollable Radix dialog and kept action
   errors inside it. Closing/reopening clears previous mutation errors.
2. Calendar view switching normalized the selected day to the start of the
   displayed month/week. Preserve the selected day independently of range
   normalization so switching Month/Week/Day does not lose it.
3. Project validation/request errors appeared behind the modal. Project-submit
   errors now belong to the form, with an alert and reset on reopening.
4. Installer creation had the same clipped-form defect (763px form, y=-147
   in a 468px viewport). Bound the existing shared `.modal-shell` and add
   internal scrolling. Its only remaining consumers are installer modals.
5. Journal status filtering sent READY/SIGNED while the backend domain and
   database accept DRAFT/ACTIVE/ARCHIVED. Selecting the signed filter produced
   a real server DataError/HTTP 500. Correct filter values and KPI comparisons;
   disable activation for a non-draft journal. Validate the backend query using
   JournalStatus before repository access. Invalid filters return 422 instead
   of reaching PostgreSQL. No enum/schema migration or state transition changed.

## Observed UI coverage before rebuilt preview

| Surface | Actions and observed outcome |
| --- | --- |
| Projects | Create opens; empty submit rejects name but exposed hidden-error bug; cancel works; edit opens existing data and cancels. |
| Project doors | Selecting B-1-101 and opening/closing its detail panel work. No status or assignment button was invoked. |
| Calendar | Day/Week/Month, previous/next/today and filter expansion react; view switching exposed date bug. Add-event form exposed clipping. No calendar event was saved. |
| Issues | Navigation and closed filter load one existing issue. Existing mixed-language labels remain. |
| Installers | Navigation initially encountered a connection error; Retry loaded both A-1/A-2. Inactive filter loaded an empty result. Create form opens, empty Save is disabled; clipping reproduced. |
| Journal | Navigation loads the project and empty queue. Refresh/filter actions exposed the invalid status request. No draft, signature or message was created. |
| Phone | ADB touchscreen tap at the observed Profile control exits 0 but leaves UI unchanged. Native button acceptance remains unverified. |

Backend request durations reached tens of seconds during local checks.
The connection error recovered through Retry; its root cause was not proven.
The journal DataError is a separate, code-confirmed contract defect.

## Verification checkpoint

- Three new Calendar/Projects regressions: PASS.
- Calendar/Projects/Dialog full focused batch: 52 PASS, one existing duplicate
  manual-door test timed out at 20 seconds. Two focused retries also timed out;
  this is NOT a green suite. No assertion or timeout was weakened.
- Dialog/CSS regressions after test-path correction: 3 PASS.
- Journal filter/activation regressions: 2 PASS.
- ESLint on Calendar/Projects and their tests plus Dialog test: PASS.
- Production compilation succeeded; TypeScript/build finalization and rebuilt
  browser verification were still pending at this checkpoint.
- Backend filter contract tests were running at this checkpoint.

## Remaining acceptance

Complete rebuilt-browser verification and final test outcomes below. Broader
CRUD, PDF/Excel exports, sending/retry, permissions, imports, mobile button input
and native offline/lost-ACK acceptance are not covered by this button pass.
The pre-existing release blockers remain. No 100% or production GO is claimed.

Only local commits may be made while the existing public GitHub publication
restriction remains. Do not describe a local commit as a GitHub backup.

## Follow-up results

- Backend `b6e7a1d`: 8 contract tests PASS in 38.64 seconds, running with
  `--confcutdir=tests/architecture` and a 180-second bound. The initial run
  with the shared integration conftest took 587.73 seconds and failed four
  assertions because the test expected the context's value instead of the
  unit-of-work wrapper actually passed by the router. Corrected that test
  fixture; invalid-status rejection already passed. No database fixture used.
- Admin `27ad76a`: production Next.js/webpack build PASS, including TypeScript
  and all 24 generated pages. New standalone preview PID 10060 is running on
  port 4173. Only the old verified DIMAX preview process was replaced.
- Journal full test file: 7 PASS after waiting for the selected template to
  load before pressing Apply. No request/payload assertion was removed.
- Changed-file ESLint and `git diff --check` PASS. Pre-existing local changes
  to next-env.d.ts/tsconfig.json were preserved and excluded from commits.
- Rebuilt calendar: viewport 509 x 468; dialog y=16..452, height 436,
  scrollHeight 876, overflow auto. Screenshot confirms usable scrolling and
  visible footer actions. Selecting September 15 and cycling Month/Week/Day
  retains September 15 in the event date field.
- Calendar creation and editing persisted. Native keyboard time input showed
  the invalid-range alert and disabled Save. CUA fill alone changed the native
  time field's displayed value without committing React state; that attempt
  is not a validation pass/failure. Keyboard input verified the real behavior.
- Temporary `QA BUTTON TEST 20260914` inspection was renamed with EDIT and
  saved at 09:00..09:01 on September 15, without installers. The first delete
  encountered a connection error displayed correctly inside the modal. Retry
  returned HTTP 200. Read-only SQL confirms ZERO matching events; the calendar
  shows no events and zero unassigned events after closing the editor.
- Existing project data in the event frame remained 5/9 installed, 1250.00
  payroll total. No completion or payroll mutation was performed.
- Removed only the verified cache directory from this turn's completed build:
  264,490,937 bytes. Kept the standalone runtime/static assets required by the
  running preview. No APK, database copy or screenshot file was added.
- Rebuilt journal UI: selecting the signed filter sends ARCHIVED and finishes
  with an empty queue without HTTP 500/error text. No journal was created.
- Rebuilt project UI: an empty Create submission shows the required-name alert
  inside the dialog above its footer. Screenshot confirms the error is visible.
  Cancel closes the form; no project was created.
- Rebuilt installer UI: creation form bounds y=16..452 in the same 468px
  viewport; overflow auto, scrollHeight 762/clientHeight 435. Cancel works;
  subsequent DOM observation confirms zero remaining custom modals.

## Additional unresolved findings

- Medium: an already-open event information frame retains the old title/time
  after successful editing; choosing the updated event card refreshes it.
- Medium: successful calendar deletion clears the event but does not close
  its editing dialog automatically. Cancel closes it. These are confirmed
  follow-up defects, not covered by the five fixes above.
- Medium: journal template Apply/Delete remain enabled before a template has
  loaded even though their handlers guard against missing selection.
- The duplicate manual-door timeout was subsequently resolved by scoping
  form-field/button queries to the active dialog. The exact original validation
  and no-POST assertions remain, and the 20-second limit is unchanged. Targeted
  rerun PASS in 9.19 seconds (44.58 seconds including setup/collection). The
  initial batch was not green; every case in that focused batch now has a
  successful result across follow-up runs. This is not the full release gate.
- Physical phone clicks, broader CRUD and exports/delivery acceptance remain
  unverified. The request to test every button is not fully completed.
