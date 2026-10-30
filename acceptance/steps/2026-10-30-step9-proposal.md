# Step 9 proposal: opening balances (2026-10-30)

Spec: DIMAX_FACTORY_ACCOUNTING_SPEC.md 3.12, 3.10, R23, R24, section 4 ("approve opening balances: OWNER
only after reconciliation"), step 9 of section 8, scenario T13. Owner (chat, 2026-10-30): keep going in
order, strictly inside the agreed logic. Decisions in force: accounting starts 10 November 2026 (periods
10th → 10th Asia/Jerusalem); VAT is never computed until the accountant answers; everything commercial is
OWNER only until section 12; the real opening amounts and documents are an owner input (section 12).

## What exists (studied by code)

Claims, reconciliation and payments (steps 6–8) know only obligations that arise from signed journals
dated inside an accounting period. Nothing records what the factory already owed, retained or had paid
in advance before the cutover; signed rows dated before 10 November are refused by the period rule and
are invisible; money received before the cutover cannot be allocated.

## Decisions for the code (strictly inside the agreed logic)

1. **Three kinds of opening balance, entered apart** (3.12, R24): DEBT (what the factory owed DIMAX),
   RETENTION (the part of that debt the factory holds back) and ADVANCE (money of the factory not yet
   applied). Each row carries contract, currency ILS, amount, basis text, tax basis (EX_VAT / INC_VAT /
   UNSPECIFIED), a due date or release condition or an explicit "unknown", an evidence file, and the
   state date = the day before the cutover (Asia/Jerusalem). No detailed history is migrated.
2. **A retention is extracted from the debt, never added** (3.12): approved RETENTION rows of a
   contract never exceed its approved DEBT; the opening principal = debt − retention.
3. **Reconciled with the factory, then approved by OWNER** (R24, section 4): a draft is reconciled by
   recording the factory's acknowledgement (author, channel, time, attachment, acknowledged amount);
   the difference is the disputed amount, kept as its own attribute; acknowledging more than entered is
   refused. Changing a reconciled draft clears the reconciliation (the factory acknowledged other
   figures). OWNER approves against a fingerprint of the exact payload and a one-time request id; an
   approved row is immutable (trigger); a mistake is a new row after a REJECT with a reason. Approval
   does not replace the factory's acknowledgement: a disputed row is approved as disputed.
4. **Opening balances join the figures without doubling** (3.10): an approved DEBT is an obligation
   that payments settle like a claim (allocation target: principal only; opening retention is shown
   held and its release is an owner decision, not built here); an approved ADVANCE becomes a posted
   payment of purpose ADVANCE with the evidence as proof, so it is allocated through step 8 and shown
   as unallocated money until it is; the contract summary shows opening debt, retention, advance,
   disputed and paid apart from the claims, and the money summary's payable amount includes the
   opening principal still unpaid.
5. **No second debt from early work** (3.12, T13): accepted signed rows dated before the cutover are
   listed as "early work" and are never claimable (the period rule stays); each approved DEBT states
   explicitly whether it covers the early unpresented work, and the early-work list shows the
   coverage so nothing is presented twice.
6. **VAT is not re-applied** to an opening debt: the tax basis is stored as entered and shown.
7. Flag `OPENING_BALANCES_ENABLED` (default off) on top of the payments flag; downgrade refuses to
   discard approved balances. Preparing the rows before the cutover activates nothing by itself.

## Owner decisions (not decided by code)
- The real opening amounts, documents and the factory's acknowledgements (section 12).
- Release of an opening retention and allocation of payments to it; VAT rule for INC_VAT balances.

## Order of work
9a backend (migration 0096, models, service, API, tests) → 9b admin (tab "Opening balances": rows,
reconcile, approve, early work) → 9c review pass with the owner's skills, record.
