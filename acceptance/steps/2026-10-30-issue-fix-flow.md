# Step 5a: issues with a source and a closing authority, fixes without earnings (2026-10-30)

Spec: DIMAX_FACTORY_ACCOUNTING_SPEC.md 3.4, R08, R09, step 5 of section 8, scenario T08. Proposal and
decisions: `acceptance/steps/2026-10-30-step5-proposal.md`. Backend migration `0091_issue_source_fix_flow`.

Marks: **confirmed by tests**, **studied by code**, **seen live**, **not verified**, **needs external infra**.

## 1. Before changes

Studied by code (two read-only maps first): one issue per door with status OPEN / CLOSED and a workflow
state; any admin could close any issue; the installation (any path) closed the door's issue; devices could
only create issues; no source, no stage link, no record of who reported a fix or who confirmed it; the
site representative existed only as the signer of a journal link.

## 2. Decisions taken in this step (strictly inside the agreed logic)

- **No new statuses.** "Fixed, awaiting check" is the existing workflow state RESOLVED with status OPEN
  (the door stays blocked until confirmation); "confirmed" is CLOSED. Doors, project health, reports,
  sync and the phone keep their OPEN / CLOSED contract.
- **Source decides who closes (R09).** `issues.source` INTERNAL (default) or SITE. A SITE issue is
  closed only through the acceptance link of the project; the office gets 403 on every closing path
  (status, workflow, bulk) and may only mark it fixed and checked. The source of an open issue is never
  downgraded: a later office report on a SITE issue keeps SITE; a SITE report on an INTERNAL issue
  escalates it. A closed issue reopened by a new report starts a fresh trail.
- **The installation closes INTERNAL issues only** (confirmed by SYSTEM); a SITE issue is at most
  marked RESOLVED by the installation and waits for the representative.
- **A fix is an immutable report, never an earning (R08).** `issue_fix_reports` (trigger-protected,
  idempotent by request id or client event id) records who reported the fix and when; the issue goes
  to RESOLVED with `fix_reported_at` / `fix_reported_by_installer_id`. No stage fact and no ledger row
  is ever written by a fix; the stage fact uniqueness and ledger constraints from 0088/0090 make a
  "redo" earning impossible by construction. Paid rework stays the existing addon flow.
- **Stage-linked defects.** `stage_code` names a stage of the door's current plan (validated); the
  stage assignees of a door are installers of the door for issues: they receive the ISSUE changes,
  may report, and may report a fix (online `POST /installer/issues/{id}/fixed` or offline
  `ISSUE_FIX_REPORT` with the closed payload `{issue_id, door_id}`).
- **The site representative acts through the acceptance link** (today's only identity of the
  representative, the same that signs volumes): `GET/POST /public/journals/{token}/issues` raises a
  SITE issue on a listed door in the representative's name, `POST …/issues/{id}/confirm` closes a
  RESOLVED SITE issue. Rate-limited like the signing endpoints; audited with `actor_kind
  SITE_REPRESENTATIVE` and the representative's name (audit actor constraint extended in 0091). A
  stronger identity (registered representative, mailbox code) is spec section 12.
- **One issue per door stays** for this step (every door flow, the sync scope and the phone assume
  it); a defect on one stage does not touch the other stages' facts but still blocks the door.

## 3. Checks

| Check | Mark | Evidence |
|---|---|---|
| Installer creates an issue (INTERNAL, NEW), reports the fix with a request id (RESOLVED, OPEN, `fix_reported_at` from `happened_at`), replay idempotent, second report 409, priced body 422; one immutable fix report; zero earnings; door stays ISSUE_OPEN until the office closes it; office close records ADMIN confirmation and restores the door; ISSUE changes carry workflow_state/source/stage_code and no price word; reopening by a new report resets the trail | confirmed by tests | `test_issue_fix_flow.py::test_installer_fix_report_awaits_the_office_and_never_earns` |
| SITE issue through the acceptance link on an installed door: raised in the representative's name (journal linked, no user), door stays INSTALLED; office close/status/bulk → 403, office may set IN_PROGRESS, office report keeps SITE; confirm before fix → 409; installer reports fix; link lists `can_confirm`; office still 403; representative confirms → CLOSED by SITE_REPRESENTATIVE with name, audit rows ISSUE_REPORTED / ISSUE_FIX_REPORTED / ISSUE_CONFIRMED_BY_SITE; repeat confirm idempotent; unknown token / unlisted door 404; zero earnings | confirmed by tests | `::test_site_issue_is_closed_only_by_the_representative_through_the_acceptance_link` |
| Stage-linked SITE issue recorded by the office (unknown stage 422, stage on a plain door 422, SITE without a name 422); both installers of the door receive it; the stage installer (not the door holder) reports the fix offline (applied once, replay acknowledged, priced payload refused); completing all stages installs the door but leaves the SITE issue OPEN/RESOLVED; a plain door's INTERNAL issue is closed by its installation with SYSTEM | confirmed by tests | `::test_stage_defect_installation_keeps_site_issue_open_and_internal_closes_itself` |
| Downgrade of 0091 refused with fix reports | confirmed by tests | `::test_downgrade_refuses_to_discard_fix_reports` |
| Existing issue suites unchanged: lifecycle sync (7) and admin issues API (10) | confirmed by tests | run 2: 28 passed |
| Regression: architecture suite, sync snapshot, installer phase 2, AI actions / installer, installer projects, journal API, OpenAPI contract, RBAC matrix, work stages, stage earnings | confirmed by tests: 344 passed, 5 failed — 3 pre-existing in `tests/architecture/test_outbox_health.py` (other agent's outbox recovery, see the step 4 record) and 2 exact-shape contract tests extended deliberately for the new issue fields (`test_installer_sync_reset_snapshot_includes_projects`, `test_installer_project_details_returns_scoped_data`), re-run 72 passed | `scratchpad/fix-flow-regr.log`, `fix-flow-4.log` |
| Admin: issue trail (raised by the site with name, stage, fix reported, confirmed by whom), CLOSED options disabled for SITE issues with the explanation, RESOLVED labelled "Fixed, awaiting check" | confirmed by tests | `src/test/IssuesPage.test.tsx` (9), eslint clean, ratchets pass |
| Mobile: SQLite 13 (`workflow_state`, `source`, `stage_code` on issues; cursor reset for upgraded devices), issues ingested with the new fields, a queued fix stays visible as awaiting check, `ISSUE_FIX_REPORT` queued with `{issue_id, door_id}` only (undo data stripped before sending), refusals for local / done / already reported issues, revert on rejection, issue dialog shows the source, stage, awaiting-check pill and the "Fixed, please check" button with who confirms | confirmed by tests | `db.test.ts`, `service.test.ts`, `presentation.test.ts`, `issues/*.test.ts`; full suite 69 files / 860 tests, `tsc --noEmit` clean, discovery contract 69 files |
| Admin `tsc --noEmit`: only the five pre-existing errors in the other agent's `OutboxRecoveryPage.test.tsx` and `ContractTerms.test.tsx`; none in step-5 files | confirmed (step-5 files clean) | — |
| Live run (admin pane, acceptance page, phone) | not verified in this block | — |

## 4. Open

- The acceptance page in the admin app does not yet show or raise site issues (the public endpoints
  exist); it comes with partial acceptance (5b) where excluded rows and open issues are shown together.
- Issues of a staged door are still one per door; per-stage issues need the one-issue-per-door rule
  relaxed across doors, sync and the phone (later step).
- A registered site representative with a mailbox code (spec section 12) would replace the link-based
  identity without changing the rules above.
