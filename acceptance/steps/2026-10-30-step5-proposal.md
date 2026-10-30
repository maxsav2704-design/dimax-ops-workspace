# Step 5 proposal: issues with a source and a closing authority, free fixes, partial acceptance (2026-10-30)

Spec: DIMAX_FACTORY_ACCOUNTING_SPEC.md 3.4, 3.5, section 8 step 5, rules R08–R11, scenarios T06, T08.
Owner (chat, 2026-10-30): move to step 5. This note records the decisions the code will follow; the
items under "Owner decisions" stay data or wait for the owner, they are never guessed by code.

## What exists today (studied by code before changes)

- One issue per door (`uq_issues_company_door`), status OPEN/CLOSED plus a workflow state
  NEW → TRIAGED → IN_PROGRESS → BLOCKED → RESOLVED → CLOSED; no source, no link to a stage, no
  notion of who may close. A door marked NOT_INSTALLED opens the door's issue; marking it INSTALLED
  (any path, including completion by stages) closes it. Devices create issues offline
  (`ISSUE_CREATE`) and receive `ISSUE` changes.
- A journal is DRAFT → ACTIVE (public link) → ARCHIVED (signed). Its rows are a copy of every
  INSTALLED door of the project (or of one installer) and every addon fact, taken at refresh time;
  one signature per journal; the snapshot carries no prices. Nothing links a row to the executed
  work (stage fact, earning), nothing marks a row as accepted or excluded, a later journal lists
  everything again, and open issues are not shown to the representative.

## Decisions for the code (strictly inside the agreed logic)

### 5a. Issues
1. **Source and closing authority.** `source = INTERNAL | SITE`. INTERNAL is closed by a DIMAX admin
   (OWNER/OPERATIONS as today). SITE is raised by the site representative (through the acceptance
   link, or recorded by the office on their behalf with the representative named) and is closed only
   through the acceptance link of that project; the office may only mark it fixed-and-checked
   (RESOLVED). Changing the source of an existing issue is refused (R09: the source cannot be
   switched to bypass the representative).
2. **Link to the work.** Optional `stage_code` (a stage of the door's plan). Several issues per
   door become possible: the legacy "one open issue per door" rule stays only for the door-level
   INTERNAL issue the status flows create (partial unique); stage and SITE issues are additional
   rows. A defect on one stage never blocks the other stages (the stage facts stay as they are).
3. **Fix workflow.** Installer reports "fixed" (API and offline event `ISSUE_FIX_REPORT`,
   payload `{issue_id, door_id}` only) → RESOLVED, awaiting check; the right party confirms → CLOSED;
   the right party may also send it back → IN_PROGRESS. A fix is recorded as an immutable
   `issue_fix_reports` row (who, when, source, idempotency key). **A fix never creates an earning**
   (R08): no stage fact, no completed_work row is written by a fix. Paid rework stays the existing
   addon flow (office plan + installer fact + factory price), never implied by an issue.
4. **Door status flows keep their behaviour for INTERNAL door-level issues** (NOT_INSTALLED opens,
   INSTALLED closes). A SITE issue is never closed by a status change: completing the door moves
   it at most to RESOLVED.
5. **After signature.** An issue raised after a journal is signed never rewrites that journal: it
   is linked to the journal (`journal_id`) and shows on the next document. Links to claims and
   payments are steps 6–8.

### 5b. Partial acceptance (flag `JOURNAL_PARTIAL_ACCEPTANCE_ENABLED`, default off)
6. **Rows reference the executed work.** A door installed as a whole: one row per door
   (`installed_at`, as today). A door installed by stages: one row per stage fact in a separate
   table `journal_stage_items` (`stage_code`, `stage_fact_id`, executed at), so the existing door
   rows, their unique rule and the commercial estimate lines stay untouched. Addon rows reference
   the addon fact (as today). Open issues of the project are stored with the snapshot at refresh
   (`journal_issue_items`), never read live at signing (existing snapshot contract).
7. **Accepted volume.** Each row has `accepted` (default true) and an `exclusion_reason`
   (check: an excluded row always has a reason). The office (or the installer preparing the
   journal) excludes rows in DRAFT; `lock_table` is now enforced on the server too. The
   representative stays read-only on rows: the public link is not a write surface for volumes.
   Their objection is a SITE issue raised through the same link (5a), which the office answers by
   excluding the row and issuing a follow-up document. The signature is bound to the SHA-256 of a
   canonical accepted snapshot (accepted rows, excluded rows with reasons, open issues, project
   block, locale) and the journal's `snapshot_version`, both stored on the signature; the public
   sign request carries the version it saw (optional at first, mismatch → 409). Signatures and the
   rows of a signed journal are guarded by database triggers like stage facts.
8. **Nothing accepted twice, nothing lost.** With the flag on, a refresh skips work already
   accepted in a signed journal of the project (door, stage fact or addon fact) and lists the rest;
   a journal created after a signed one carries `follow_up_of_journal_id`. Correcting an accepted
   volume means a new journal and a new signature; a signed PDF is never regenerated (existing rule).
9. **No commercial data to the representative** (R10): the public snapshot, the PDF and the
   signing page carry volumes, dates, stages and issues only; this is pinned by the existing
   architecture tests and extended for the new fields.
10. **Flag off = today's behaviour**: all rows accepted, no de-duplication across journals, no
    decline at signing; the issue source still works (it is a data rule, not a money rule).

## Owner decisions (not decided by code)
- Who is the site representative for a project: today the acceptance link is the only identity
  (token + signer name); a delegated/named representative registry is spec section 12.
- Whether an excluded row may be re-presented in a later journal while its SITE issue is still
  open (the code will require the issue to be closed first).
- Whether the office may close a SITE issue when the representative is unreachable (the code will
  not allow it; an OWNER override can be added later as an audited exception).

## Order of work
5a backend (migration 0091: issue source/stage/journal link, fix reports, sync event, enum values)
→ 5a admin + mobile (fix button, SITE badge, closing authority in the UI) → 5b backend (migration
0092: row references, accepted/exclusion, signature hash, follow-up link, flag) → 5b admin + public
signing page → 5c acceptance record. Each block with its own tests; commits per repository.
