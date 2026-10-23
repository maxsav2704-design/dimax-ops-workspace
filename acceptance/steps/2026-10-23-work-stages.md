# Step 3: work stages — plans, per-stage installers, execution facts (2026-10-23)

Spec: DIMAX_FACTORY_ACCOUNTING_SPEC.md 3.3, section 8 step 3, R05–R07. Owner (chat): keep going in
order; stage-based contracts wait for stage facts, so this step supplies the facts.

Marks: **confirmed by tests**, **studied by code**, **seen live**, **not verified**, **needs external infra**.

## 1. Before changes

Studied by code (a read-only map of the completion flow was made first): a door is installed through
three paths — `DoorUseCases.mark_installed` (API and offline sync), `InstallerDoorService.change_status`
(status PATCH and the batch queue) and `admin_override` — all three lock the company and the door,
then write `status/installed_at/is_locked/version`, create the one full-door earning
(`create_completed_work_for_door`, guarded only in application code), close the issue, recalculate
the project and record the transition. There is one `installer_id` per door; the sync protocol
accepts only `DOOR_SET_STATUS`, `ADDON_FACT_CREATE`, `ISSUE_CREATE` with closed payload allow-lists;
old devices (SQLite v11) send `{door_id, status, previous_version, price_list_id}`. No stage concept
exists outside the commercial price (`kind = STAGE`, `stage_code`).

Gaps for the spec: no catalog of stages, no versioned plan per door type, no per-stage executor, no
execution fact independent of the earning ledger, no way for two installers to finish one door.

## 2. Decisions taken in this step (strictly inside the agreed logic)

- **Additive and flagged.** Everything lives in new tables and new endpoints behind
  `WORK_STAGES_ENABLED` (default off). A door without a work plan behaves exactly as before: same
  paths, same earning, same protocol for old devices.
- **The office plans before execution.** Stage catalog per company (code `A–Z0–9_`, the same code
  space as the commercial price `stage_code`), versioned plans per door type (immutable versions,
  at least one required stage), one current plan per door (replaceable only until the first stage
  fact), one current installer per stage with full assignment history.
- **One fact per door stage, immutable** (trigger), with executor, assignment, plan version,
  execution time (`min(happened_at, received_at)`), source and the idempotency key (`request_id` or
  `client_event_id`). Facts never create an earning: stage earnings are step 4.
- **Every required stage done ⇒ door INSTALLED** through the same locks, issue closing, project
  recalculation and transition record as before, `installed_at` = the last required stage, but
  **without** the legacy full-door earning. The legacy paths refuse a door that has a work plan
  (409 "installed by stages"), so a door can never be accrued as a full installation and as stages.
- **Offline:** new sync event `DOOR_STAGE_COMPLETE` with a closed payload
  `{door_id, stage_code, base_version|previous_version}`; the assignment, not `DoorORM.installer_id`,
  proves the installer's right; `client_event_id` idempotency and conflict codes as for the other
  events. Mobile UI for stages is step 4 (the server side of the protocol is ready).
- **Roles:** planning and assignment need OWNER or OPERATIONS; FINANCE and VIEWER read only;
  the office may record a stage reported by phone on behalf of the assigned installer (source ADMIN).
- **Not decided by code:** stage composition per door type, sequence rules and the relation between
  stage rates and the full-installation price (spec section 12) stay data entered by the owner;
  no ordering is enforced between stages in this step.

## 3. Checks

| Check | Mark | Evidence |
|---|---|---|
| Catalog: uppercase codes, duplicate 409, bad code 422, priced payload 422, deactivation; plans: empty / no required / duplicate / unknown or inactive stage 422, optimistic version 409, immutable versions listed newest first | confirmed by tests | `test_work_stages.py::test_catalog_and_versioned_plans` |
| Planning needs OWNER or OPERATIONS (FINANCE 403, reads allowed); flag off → 409 | confirmed by tests | `::test_planning_needs_owner_or_operations_and_the_flag` |
| Two installers: unassigned 403, A completes FRAME (idempotent by request_id, repeat 409, B's stage 403, priced body 422), executed stage cannot be reassigned, plan cannot change; office records B's LEAF → door INSTALLED, locked, `installed_at` = last required stage, **zero** CompletedWork rows, one transition record, audit DOOR_WORK_PLAN / DOOR_STAGE_ASSIGN ×2 / DOOR_STAGE_COMPLETE ×2; optional stage after installation 409; facts immutable (update and delete refused) | confirmed by tests | `::test_two_installers_complete_a_door_by_stages_without_legacy_earning` |
| Assignment history (replaced row kept), installer sees only doors where they hold an assignment, unknown door 404 | confirmed by tests | `::test_assignment_history_and_installer_view` |
| Legacy install, status INSTALLED, admin install and admin override refuse a planned door (409, nothing accrued); a plain door installs as before with one full-door earning | confirmed by tests | `::test_legacy_installation_refuses_stage_doors_and_plain_doors_keep_working` |
| Offline `DOOR_STAGE_COMPLETE`: applied once, replay acknowledged without a second fact, other installer's stage → CONFLICT_ASSIGNMENT_CHANGED, priced payload refused, door stays NOT_INSTALLED, no earning | confirmed by tests | `::test_offline_stage_event_is_applied_once_and_checks_the_assignment` |
| Downgrade of 0088 refused with facts | confirmed by tests | `::test_downgrade_refuses_to_discard_stage_facts` |
| Regression: installer phase-2 API, sync snapshot API, sync batch API, assignment atomicity, factory earnings, e2e core flow, issue lifecycle, payload allow-list architecture test | confirmed by tests | 195 passed in 9 min 17 s |
| Admin: stage catalog and plan editor on the door types page (OWNER/OPERATIONS), "Installation stages" card on the focused door of a project: apply plan, assign per stage, record a stage reported by the installer, done/pending view, hidden when the server flag is off, no price field anywhere | confirmed by tests | `src/test/WorkStages.test.tsx` (4); existing `DoorTypesPage` and `ProjectsPage` suites still green (56) |
| Admin gates | confirmed | `tsc --noEmit` clean, eslint clean, type-scale and RTL ratchets pass |
| Live run in the browser pane | not verified in this block (flag is off on the demo stack; a live run is listed as the next action) | — |

Execution times in the tests are in the past: the server clamps `happened_at` to the receipt time, so a
future-dated stage can never be recorded as such (same rule as door installation).

## 4. Open

- Step 4: stage earnings for installers (ledger rows per stage fact with factory price evidence),
  mobile "my stages" screen and the offline queue for `DOOR_STAGE_COMPLETE`.
- Step 5: redoing a stage after a defect (today a second fact for the same stage is refused).
- The commercial estimate (`STAGES_NOT_SUPPORTED`) can value stage facts once the owner confirms
  how stage rates relate to the full-installation price (section 12).
