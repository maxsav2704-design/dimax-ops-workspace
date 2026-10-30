# Step 5b: partial acceptance of journals (2026-10-30)

Spec: DIMAX_FACTORY_ACCOUNTING_SPEC.md 3.5, R10, R11, step 5 of section 8, scenarios T06, T07 (partly).
Proposal and decisions: `acceptance/steps/2026-10-30-step5-proposal.md`. Backend migration
`0092_journal_partial_acceptance`; flag `JOURNAL_PARTIAL_ACCEPTANCE_ENABLED` (default off).

Marks: **confirmed by tests**, **studied by code**, **seen live**, **not verified**, **needs external infra**.

## 1. Before changes

Studied by code (read-only map first): a journal copied every INSTALLED door and every addon fact at
refresh, rows had no link to the executed work and no accepted flag, a later journal listed everything
again, the signature was bound to nothing but the journal id, open issues were never shown, rows of a
signed journal were protected by application checks only. Prices, earnings and bank data were already
absent from the public snapshot and the PDF.

## 2. Decisions taken in this step (strictly inside the agreed logic)

- **Rows reference the executed work.** Whole doors stay one row per door; a door installed by stages
  gets one row per stage fact in `journal_stage_items` (also for doors not yet fully installed, so a
  stage can be accepted on its own); addon rows reference the addon fact. Open issues of the listed doors
  are stored with the snapshot (`journal_issue_items`) at refresh and never read live at signing.
- **The office decides the accepted volume in DRAFT.** Every row carries `accepted` and an
  `exclusion_reason` (database check: an excluded row has a reason); `lock_table` is now enforced on the
  server; decisions survive a refresh of the work table; a journal with nothing accepted cannot be sent.
  The representative is read-only on rows: the acceptance link is not a write surface for volumes;
  their objection is a SITE issue (5a).
- **The signature is bound to what was shown.** The sign request carries the `snapshot_version` the
  representative saw (409 when the document changed); the signature stores the canonical accepted
  snapshot (accepted rows, excluded rows with reasons, open issues, project block, locale) and its
  SHA-256; the signed PDF shows the accepted volume, then separately the stages, the rows not accepted
  with their reasons, the open issues (who raised them, fixed-awaiting-check) and the snapshot hash.
- **Nothing accepted twice, nothing lost.** A refresh skips doors, stage facts and addon facts already
  accepted in a signed journal of the project (unless a later journal supersedes it); a new draft after a
  signed journal carries `follows_journal_id`. A correction is a new journal with `supersedes_journal_id`
  (never both links); signed PDFs are never regenerated (existing rule).
- **Database guards.** A signature is immutable; rows of a signed journal cannot be inserted, changed or
  deleted (triggers). Downgrade refuses while signatures bound to accepted snapshots exist.
- **Flag off = yesterday's behaviour**: all rows accepted, no de-duplication, no version check, no new
  keys in the snapshot (the strict snapshot contract and the public/admin identity stay as they were).
- **No commercial data to the representative** (R10): the new rows, the issue rows and the PDF carry
  volumes, stages, dates, reasons and issue titles only; the commercial estimate now counts accepted
  rows only.

## 3. Checks

| Check | Mark | Evidence |
|---|---|---|
| Office excludes a row (reason required 422, locked table 409), the decision survives a refresh, version bumps; public view equals the admin view and carries no price word; stale version → 409; signature stores version, snapshot and SHA-256 with accepted doors/stages and the excluded door with its reason and the open issue; signed row and signature immutable (IntegrityError); signed PDF contains "Not accepted in this document", the reason, "Completed installation stages", "Open issues", "SHA-256" and no money word; the follow-up journal lists only the excluded door and the stage finished later and follows the signed one; zero earnings touched | confirmed by tests | `test_journal_partial_acceptance.py::test_office_excludes_rows_representative_signs_the_accepted_snapshot_and_a_follow_up_lists_the_rest` |
| Nothing accepted → mark-ready 422; unknown row 404; rows frozen once the link is issued (409); sign without a version still works | confirmed by tests | `::test_nothing_accepted_cannot_be_sent_or_signed` |
| Flag off: legacy shape (no item ids, all accepted), acceptance endpoint 409, signature without snapshot binding | confirmed by tests | `::test_flag_off_keeps_the_legacy_journal_shape` |
| Downgrade refused with bound signatures | confirmed by tests | `::test_downgrade_refuses_to_discard_bound_signatures` |
| Journal API (18), snapshot contract, PDF layout / integrity, signing links, filter contract, public capability locking | confirmed by tests | run 2: 76 passed |
| Journal delivery / Mailpit acceptance, financial integrity, commercial activation (estimate on accepted rows), AI journal document, reports, issue fix flow | confirmed by tests: run 3 48 passed + 3 fixtures that inserted rows into an already-signed journal (`signed_journal` helper in `test_commercial_activation.py`, the AI rules journal fixture) now write rows before the signature; run 4 66 passed | `scratchpad/partial-3.log`, `partial-4.log` |
| Admin: journal form shows acceptance checkboxes per door and stage row, excludes with a reason through `PATCH …/acceptance`, shows stage rows and the open issues the representative will see; the acceptance page shows the accepted volume, the completed stages, the rows not accepted with reasons, the open issues, and signs with the version it saw | confirmed by tests | `src/test/JournalFormPage.test.tsx` (10), `src/test/AcceptancePage.test.tsx` (4); eslint clean, ratchets pass |
| Admin `tsc --noEmit`: only the five pre-existing errors in the other agent's `OutboxRecoveryPage.test.tsx` and `ContractTerms.test.tsx`; none in step-5 files | confirmed (step-5 files clean) | — |
| Mobile | no change needed: the journal contract tolerates the new fields; the installer prepares and submits as before | studied by code | `mobile/src/modules/journal/contract.ts` |
| Live run (admin pane, acceptance page) | not verified in this block | — |

## 4. Open

- Later-accepted rows of a stage door and the `supersedes` correction flow have no UI yet (the office
  creates a new journal; `supersedes_journal_id` is set by data only until a "correct this journal"
  action is added).
- The installer web/mobile journal view does not show acceptance flags; the office decides.
- Spec section 12: a registered site representative (mailbox code) would strengthen the link identity.
