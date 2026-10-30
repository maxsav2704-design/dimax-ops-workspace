# Step 4: stage earnings, stage installers and the phone (2026-10-29 … 2026-10-30)

Spec: DIMAX_FACTORY_ACCOUNTING_SPEC.md 3.3 and section 8 step 4. Owner (chat, 2026-10-29): drop the stash
copies and move to step 4. Backend migration `0090_stage_earnings`, admin and mobile changes in one step.

Marks: **confirmed by tests**, **studied by code**, **seen live**, **not verified**, **needs external infra**.

## 1. Before changes

Studied by code (two read-only maps were made first): the installer price list held only DOOR and ADDON
lines (`ck_factory_price_items_target`, unique per door type); the earnings ledger allowed only DOOR and
ADDON rows, one active DOOR row per door enforced in application code; the factory confirmation hashed
each line as `{kind, target_id, name, unit, installer_price}`; stage facts (0088) created no earning; a
stage-only installer never saw the door (every visibility query was keyed on `doors.installer_id`), no
stage data reached a device and the phone's price cache rejected any kind other than DOOR / ADDON.

## 2. Decisions taken in this step (strictly inside the agreed logic)

- **Stage rates are factory-confirmed lines of the same single price list.** Kind `STAGE`, keyed by
  door type and stage code (the company stage catalog, 0088). Only when work stages are switched on, only
  known active stages; DOOR and ADDON lines keep the exact fingerprint, snapshot shape and constraints they
  had, so every earlier factory confirmation still verifies. A stage rate is never derived from the
  full-installation price: the relation stays an owner decision (spec section 12).
- **A stage fact is valued at the rate confirmed for its execution time**, like a door: same activation
  timeline, same evidence row (`factory_earning_prices` points at the STAGE line), quantity one, no client
  price snapshot (the client price belongs to the whole door). Ledger kind `STAGE` with `door_id` and
  `stage_fact_id` (one ORIGINAL per fact, database constraint), covered by the immutability trigger.
- **No price is ever invented.** Without an effective factory price at execution time the fact is kept
  (it is proof of work and still installs the door) and the money gap is named: `PRICING_INACTIVE`
  (legacy mode: stages have no legacy rate) or `NO_RATE` (the effective version has no line for this door
  type and stage). The status is in the stage view, the completion response and the audit row; the price
  application check lists planned stages without a rate as a review note (`MISSING_STAGE_PRICES`, not a
  blocker). There is no retry endpoint: a later version cannot price past work, and a manual rate for a
  factory-priced stage is refused like for doors.
- **A staged door cannot be flipped back by override** (NOT_INSTALLED refused, 409): its facts and stage
  earnings are immutable; redoing a stage after a defect is step 5.
- **Visibility follows the current stage assignment.** A door is in an installer's view when they hold
  it or hold one of its current stages (door lists, project list, sync change scope, cold snapshot).
  New change type `DOOR_STAGES` (one row per installer of the door: assigned to me / done / done by me,
  never a price); the stage installers also receive the DOOR change when the door becomes INSTALLED.
- **The phone caches no stage price.** The installer price snapshot still carries DOOR and ADDON lines
  only (the old device parser stays valid); the stage protocol carries `{door_id, stage_code,
  previous_version}` and nothing else. On a staged door the app hides whole-door actions and the
  whole-door price, and offers one button per stage assigned to this installer. SQLite schema 12 adds
  `door_stages`; an upgraded device drops its change cursor so the next sync brings a snapshot with the
  stages, queued work untouched.

## 3. Checks

| Check | Mark | Evidence |
|---|---|---|
| Price list: STAGE needs its stage, DOOR refuses a stage, duplicates (case-insensitive) refused, unknown stage 422, flag off 422; detail shows `Staged entrance: Frame · pcs`; confirmation snapshot keeps the five DOOR keys and adds `stage_code` only to STAGE lines; quote by door type and stage, missing stage line → MISSING_FACTORY_PRICE, wrong kind/stage pairs refused; device snapshot and admin state show DOOR only; application check notes `MISSING_STAGE_PRICES` 1 for the planned optional stage | confirmed by tests | `test_stage_earnings.py::test_stage_lines_need_a_known_stage_and_keep_door_lines_byte_identical` |
| Two installers, FRAME 100 / LEAF 150: one STAGE row per fact with evidence pointing at the STAGE line (AT_EXECUTION), replay creates nothing, door INSTALLED after LEAF with zero DOOR rows, stage view RECORDED with earning ids, installer summary row `Staged entrance: Frame` 100.00, admin ledger filter STAGE with stage code and factory price, CSV columns `stage_fact_id, stage_code`, manual correction 409, override NOT_INSTALLED 409, downgrade of 0090 refused | confirmed by tests | `::test_stage_facts_are_valued_at_the_confirmed_stage_rate` |
| Missing stage rate: FRAME RECORDED, LEAF fact kept with NO_RATE, door installed, one earning, audit rows name the status | confirmed by tests | `::test_missing_stage_rate_keeps_the_fact_and_shows_the_gap` |
| Legacy mode: fact kept, PRICING_INACTIVE, no earning | confirmed by tests | `::test_without_factory_pricing_stage_facts_stay_unpriced` |
| Stage-only installer: cold snapshot brings the door, its project and `door_stages` (assigned_to_me per stage), later pulls bring `DOOR_STAGES` (done, not by me) and after the offline LEAF event both installers get DOOR INSTALLED + DOOR_STAGES; no payload carries a price word | confirmed by tests | `::test_stage_installer_sees_the_door_and_receives_stage_changes` |
| Step 3 suite unchanged (7 cases, zero earnings without factory pricing) | confirmed by tests | `test_work_stages.py` |
| Backend regression: architecture suite, price list / timeline / approvals / activation / application check / reconciliation / review / write boundary, factory earnings, corrections, installer rates, price conflict resolution, work price accruals / approvals / proposals, sync snapshot / batch / cursor ordering, issue lifecycle, door assignment atomicity, commercial activation and approvals | confirmed by tests (2026-10-30, after an owner-approved Docker restart and with the demo API and workers stopped for the run): 36 + 338 + 254 + 144 passed in four chunks, then 46 passed on the re-run of the approval suites. One step-4 failure found and fixed: the public approval preview had started to show `stage_code: null` on DOOR lines (`test_public_confirmation_is_explicit_private_and_repeat_safe`); the public line now serialises `stage_code` only for STAGE lines. The other three failures are pre-existing and outside this step: `tests/architecture/test_outbox_health.py` (3 cases) expects single-item worker passes while the outbox worker from the recovery branch (0089, other agent, 2026-10-24) processes 20-item batches. Two earlier attempts on the loaded host had hung (15 min faulthandler timeout, test database "canceling authentication due to timeout") and then the Docker engine stopped answering. | logs `scratchpad/regr-b1..b5.log` |
| Admin: price editor offers `door type: stage` lines only when the stage catalog answers (409 → none), key `STAGE:<door type>:<stage>`; ledger kind STAGE with stage code; stage card shows the earning status per done stage without an amount; catalog test and page tests green | confirmed by tests | `src/lib/factory-prices.test.ts`, `src/test/WorkStages.test.tsx`, `src/test/EarningsLedgerPage.test.tsx`, `src/lib/api-schemas.test.ts` (36) |
| Admin gates: eslint on changed files clean, type-scale and RTL ratchets pass | confirmed | — |
| Admin `tsc --noEmit`: one step-4 error (device price item kind) fixed in `api-schemas.ts`; re-run leaves only the five pre-existing errors in the other agent's `OutboxRecoveryPage.test.tsx` (4) and `ContractTerms.test.tsx` (1) (`exact` in ByRoleOptions, committed in `cf8f450`), none in step-4 files | confirmed (step-4 files clean) | — |
| Mobile: schema 12 with `door_stages`, snapshot and `DOOR_STAGES` ingest keep a queued completion visible as mine, stage event payload is `{door_id, stage_code, previous_version}` only, stages that are not mine or already done are refused, whole-door actions hidden on a staged door, queue summary for the stage event, workspace loads stages | confirmed by tests | `db.test.ts`, `service.test.ts`, `presentation.test.ts`, `door-action-state.test.ts`, `local-workspace.test.ts`, `actions.test.ts`; full suite 69 files / 858 tests, `tsc --noEmit` clean, discovery contract 69 files |
| Live run (admin pane, phone) | not verified in this block | — |

## 4. Open

- Owner decisions (spec section 12): the stage rates themselves and their relation to the full
  installation price; until a confirmed version carries STAGE lines, stage facts stay `NO_RATE`.
- Issues of a staged door are still visible only to the door holder; a stage-only installer can report
  an issue but will not see the office's answer on the phone.
- The commercial estimate (`STAGES_NOT_SUPPORTED`) and the factory side of stage billing stay for the
  commercial steps; this step pays the installer, not the factory.
- Step 5: redoing a stage after a defect (second fact for the same stage, reversal of its earning).
