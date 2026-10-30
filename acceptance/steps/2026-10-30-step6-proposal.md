# Step 6 proposal: claims to the factory (2026-10-30)

Spec: DIMAX_FACTORY_ACCOUNTING_SPEC.md 3.6, R12, R13, step 6 of section 8, scenarios T06, T07.
Owner (chat, 2026-10-30): keep going in order. Earlier owner decisions still in force: accounting starts
10 November 2026, periods 10th → 10th Asia/Jerusalem, VAT is not computed until the accountant answers,
stage-billed contracts wait for the section 12 decision on stage rates.

## What exists (studied by code)

The read-only period estimate (step 2): every accepted line of every signed journal is valued at the
agreement in effect on its work day; unrated lines are named (NO_AGREEMENT, NO_RATE,
STAGES_NOT_SUPPORTED); two contracts in effect block the estimate. Nothing records what was presented
to the factory, nothing prevents the same volume from being presented twice.

## Decisions for the code (strictly inside the agreed logic)

1. **A claim is a package for one contract and one execution period** (R12, R13): sequential number
   per contract, version 1; the first package of a period is MAIN, later ones are SUPPLEMENTS (late
   journals keep their execution period and go into a supplement of that period, never into the
   current one). Flag `FACTORY_CLAIMS_ENABLED` (default off) on top of the commercial activation
   flag; OWNER only, like the estimate.
2. **Lines are exact references to accepted signed rows** (door row, addon row) rated at the
   agreement in effect on the work day, rounded per line half-up to cents, ex-VAT, VAT never computed.
   A line that cannot be rated is never claimed: it stays a visible backlog with its reason. Stage rows
   stay backlog (`STAGES_NOT_SUPPORTED`) until section 12 is decided.
3. **A volume is claimed once.** A draft reserves its rows; the database refuses a second active
   reservation of the same row (partial unique index per row kind) — across journals, packages and
   concurrent requests; the contract row is locked while a draft is composed. Cancelling a draft
   releases its rows explicitly.
4. **Issue freezes the package.** ISSUED stores a snapshot (contract reference, factory legal data of
   the terms in effect, price versions, totals, line count) and is immutable (trigger); issuing again
   with the same request id is idempotent and never creates a second claim. Delivery of the package
   (files, email, WhatsApp, "read" marks) is step 10: issued means composed and frozen.
5. **A correction never doubles the debt.** An issued claim is corrected by a new version of the same
   number (`supersedes_claim_id`): the old one becomes SUPERSEDED and releases its rows, the new draft
   re-reserves the current accepted rows; totals of superseded claims are excluded everywhere.
6. **Reconciliation from the UI**: each line shows the journal, the row and the signed fact behind it;
   the period view shows claimed, claimable and backlog rows side by side.

## Owner decisions (not decided by code)
- Stage rates versus full-installation price (section 12): until then stage rows are backlog.
- VAT rate and tax moment (accountant): amounts stay ex-VAT.
- Package delivery addresses and the factory's "received" rule: step 10.

## Order of work
6a backend (migration 0093, models, service, API, tests) → 6b admin (claims tab on the contract:
period rows with claimed/claimable/backlog, create draft, issue, cancel, correct, line reconciliation)
→ 6c record.
