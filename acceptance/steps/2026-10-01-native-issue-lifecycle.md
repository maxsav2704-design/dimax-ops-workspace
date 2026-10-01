# Native issue lifecycle and incremental sync: PASS

Follow-up to `2026-10-01-native-offline-reassignment.md`.
This checkpoint covers a real phone issue report, offline persistence, delivery,
office closure and assignment cleanup without an installation or accrual.
It is not full production, admin-browser, or signed native-build approval.

## Scope

- DIMAX Acceptance A: `d1861479-addc-5655-b5c4-f86456bb04d8`.
- Isolated API 8001 and `dimax_acceptance`; automated tests use
  `dimax_acceptance_tests`. Normal API 8000 and its database were not changed.
- Phone `a269dc99`, package `com.dimax.operations.installer`.
- Project `6423143b-4122-4685-8f8f-20fe848bc8b7`.
- Door `c39a5cab-a712-4431-ae33-983178dfe08d`, `B-1-102-fire-FR-102`.
- A-1: `4e946dc5-e084-57ac-a298-f9d74238df30`.
- A-2: `6971ffa7-3f62-5063-a87d-0acce1a4b437`.
- Backend commit `9fe3081`; mobile commit `d6eb432`.

The initially uninstalled, unlocked door was temporarily assigned A-2 -> A-1
and returned A-1 -> A-2 using `ProjectAdminService.assign_installer_to_door`.
Office closure used `IssuesAdminApiService.update_issue_workflow` and the normal
unit of work. Each fixture operation checked the test environment, exact database,
company, target, assignment and state before committing. No business SQL writes,
manufactured phone events, SQLite edits, token edits or account resets were used.
These office operations are not claimed as authenticated browser interactions.

## Defects fixed

1. Issues had no incremental sync change type, so office changes could remain
   invisible until a cold snapshot. Added scoped ISSUE events and mobile upsert.
2. Closing an issue left an uncompleted door in ISSUE_OPEN. Closure now restores
   its preceding IN_PROGRESS or NOT_INSTALLED state and recalculates project health;
   it does not create completed work. Door history and sync use existing services.
3. Reporting a defect on an installed door overwrote its completed status. The
   installed/locked state and earnings are now retained.
4. Contradictory status/workflow closedness is rejected. Door-first locking and
   issue refresh prevent a stale comment response from republishing OPEN after
   office closure. Bulk operations use deterministic door lock order.
5. Completion, reopening and assignment changes now publish the issue. Sync
   checks the current door assignment even when an older event targeted a former
   installer. Closed issues are retained in assigned cold snapshots.
6. PROJECT_BASE filtering discarded lifecycle/health fields; these now reach mobile.
7. Native verification exposed an optimistic local issue left behind after its
   event was acknowledged. ACK now removes that exact local copy. Receiving a
   server issue also cleans older orphan copies for that door, but never a copy
   backed by any pending event. No blanket queue deletion was added.

The initial backend reproduction had 8 failures and the initial mobile
incremental reproduction had 2 failures before the fixes.

## Migration and rollout

`0062_issue_sync` adds the PostgreSQL ISSUE enum value and backfills assigned
OPEN/CLOSED issues from nondeleted projects without rewriting business rows.
The guarded disposable migration smoke passed:
empty database -> 0061 -> 0062 -> 0061 -> 0062, with both statuses retained and
zero completed-work rows. Downgrade removes only derived ISSUE log entries;
the additive PostgreSQL enum value remains, following the existing convention.
The older journal-locale smoke now resolves the actual Alembic head.

The acceptance and automated-test databases are at 0062. Production/normal local
database migration was not performed. Apply this migration before restarting
backend processes and deploy the new mobile handler together with it. An older
client that has consumed ISSUE events needs supported cold resync after its
pending work is reconciled, not application-data clearing.

## Observed native sequence

1. The first physical report produced event `1790882835215-ot57mulfxz` and issue
   `05a415d2-fcba-4627-bc25-13320d58e7e3`. It was already accepted by the first
   stopped-app SQLite export, so this sample is NOT counted as offline proof.
   That export exposed both a local copy and a server copy of the same problem.
2. Loaded the fixed mobile handler through Metro. Closing the issue via the
   office service reached the phone as CLOSED; the old orphan disappeared.
   Door became NOT_INSTALLED/version 2/unlocked with no completed work.
3. Force-stopped the app, removed only API reverse mapping 8001, retained Metro
   8081, then cold-launched the exact target composer. The user physically saved
   another access issue. USB-injected taps do not work on this phone; security
   settings were not weakened. The user left optional details empty.
4. Stopped-app SQLite proved durable ISSUE_CREATE event
   `1790883579813-pfoveknow2`, happened_at `2026-10-01T19:39:39.813Z`,
   FAILED / Network request failed / attempts 1, with its local OPEN issue.
   PostgreSQL had zero rows for this event and the previous issue was still CLOSED.
5. Restored API 8001 and cold-launched Issues. The saved event was accepted once
   at `2026-10-01T19:41:17.890531+00:00`. The existing per-door issue reopened
   under the same server ID, matching the current data model.
6. Native UI and stopped-app SQLite showed exactly one OPEN server issue for
   B-1-102. The acknowledged event and its optimistic copy were absent.
7. Closed this exact issue through the guarded office service. After another
   cold launch, native UI showed zero open issues; SQLite showed one CLOSED target
   issue and NOT_INSTALLED/version 4/unlocked door. No work or accrual was created.
8. Restored the original A-2 assignment. After sync and cold launch, A-1 SQLite
   again contained one project and five own doors; both the returned door and its
   issue were absent. The phone was finally opened on Projects with both tunnels
   restored. The closed test issue/history remains on the server for inspection.

## Financial and isolation checks

- A-1 net remains **1,250.00 ILS**; A-2 remains **250.00 ILS**.
- Target has zero completed-work rows and no installed_at timestamp.
- Each of the two physical ISSUE_CREATE events exists exactly once on the server.
- Previous reassignment target B-2-201 remains A-2 / NOT_INSTALLED / version 0.
- Previous native conflict `1790880635522-ezs7bt1akt` remains BLOCKED, attempts 1,
  without retry scheduling; all SQLite row fields match the pre-test export.
- SQLite integrity checks passed. The 13 legacy-account tables remain unchanged,
  canonical SHA256
  `bf95547abf1af9bb525949b2b5be1d73ed68c53187d15250f2cc366a16250a0c`.
- No external mail, WhatsApp, signature or customer work was triggered.

## Fresh verification

- Issue lifecycle/admin integration: **21 passed**, 102.80 s, exit 0.
- Existing installer snapshot, assignment and phase-2 API suites:
  **126 passed**, 400.07 s, exit 0.
- Backend architecture contracts: **96 passed**, 21.02 s, exit 0.
- Backend total for these completed groups: **243 passed**. An earlier combined
  run exited without a final report; it is inconclusive, not counted as passing.
  These smaller completed groups replace that attempt.
- Mobile `npm run quality-gate`: **686 tests / 47 files passed**, Vitest 34.85 s,
  plus security checks, discovery, production config, Expo config and TypeScript;
  exit 0. Existing Node 20 runtime, CI and EXPO_OFFLINE were used.
- In-memory SQLite check confirmed orphan cleanup retains pending, unrelated and
  server rows. Native exports verified the same cleanup with actual device data.
- Acceptance API restarted with final code; `/ready` returned database ready,
  container healthy. `git diff --check` passed.

Backend commands used the existing acceptance image, `run --rm --no-deps -T`,
both database URLs explicitly set to `dimax_acceptance_tests`, plugin autoload
disabled, bytecode/cache disabled, and `python -m pytest -q -p no:cacheprovider`.
No admin build or full repository-wide release gate is claimed in this block.

## Cleanup and next step

Deleted the owned disposable migration database, owned phone UI XML and all
42 files / 42,666,992 bytes of stopped-app database copies, archives, screenshot
and capture logs. Cleanup validated resolved absolute scope and reparse points.
No APK, export or duplicate dependency tree was created. Test containers used
`--rm` and are gone. Existing unrelated admin generated-file changes were left
untouched. The existing-artifact admin preview on 4173 was stopped to reduce load;
the 4188 fixture preview was not treated as live app evidence.

Commits are local only; no GitHub push/remote backup occurred. This does not close
the earlier public-remote backup restriction. Metro and the acceptance API remain
available for the next native check.

Next: add-on quantity x rate, offline delivery/replay and exact earnings. Then
native journal, test signature, PDF/local-mail delivery and current-revision full
release gates. Do not label the complete project or all Critical/High work 100%
from this checkpoint.
