# Step 8 proposal: payments, advances and refunds (2026-10-30)

Spec: DIMAX_FACTORY_ACCOUNTING_SPEC.md 3.9, 3.10, R17, R18, section 4 (rights), step 8 of section 8,
scenarios T11, T12. Owner (chat, 2026-10-30): keep going in order, strictly inside the agreed logic.
Earlier decisions in force: VAT is not computed until the accountant answers; everything commercial is
OWNER only until the section 12 rights mapping; a retention is part of the obligation (step 7).

## What exists (studied by code)

Step 7 gives every issued claim version its figures (presented, written off, outstanding, retention,
held, payable now) with `paid` empty. Nothing records money received from the factory, what it
settled, what stays unallocated, or a refund of an overpayment.

## Decisions for the code (strictly inside the agreed logic)

1. **A payment is money received, separate from what it settles** (3.9): contract (the contractual
   purpose and the currency), amount as received, date, counterparty as on the bank statement, bank
   reference, stated purpose, purpose kind (SETTLEMENT / ADVANCE / UNKNOWN) and the tax basis of the
   amount (EX_VAT / INC_VAT / UNSPECIFIED). Registered as DRAFT; POSTED only with a bank proof
   attached (R17); DRAFT can be cancelled, POSTED can only be reversed. Rows are immutable except
   those status moves (triggers).
2. **Duplicates are checked, not guessed**: the same bank reference on the same contract is refused;
   the same amount and date, or the same proof file, only warn — posting then requires an explicit
   acknowledgement of the possible duplicate, recorded in the audit.
3. **Allocations are many-to-many and bounded** (3.9): an allocation settles one claim version from
   one payment, PRINCIPAL or RETENTION part; never more than the payment's available amount
   (amount − active allocations − active refund reserves − executed refunds) and never more than the
   part still due (principal due = outstanding − retention − principal paid; retention payable =
   released − retention paid); same contract and currency; the contract row is locked, so concurrent
   allocations of the last available amount let one through. Releasing an allocation keeps the row
   with its reason; re-allocation is a new row (history).
4. **Money and ex-VAT obligations compare only on the same basis**: until the accountant answers,
   only payments whose amount is stated ex-VAT can be allocated; INC_VAT / UNSPECIFIED payments stay
   visible as "needs the VAT rule" and are never allocated by guessing.
5. **Advance, unallocated and overpayment are visible apart from the work** (3.9, R18): the
   unallocated remainder of every posted payment is shown per purpose kind; a later allocation of an
   advance references the same payment (the source is kept, no second receipt); an overpayment is an
   unallocated remainder when nothing is payable on the contract.
6. **Refund of an overpayment = proposal → OWNER decision → reserve → bank execution** (3.9, R18):
   the proposal names the source payment and the amount (≤ its available amount) with a fingerprinted
   payload; OWNER approves against the fingerprint; approval reserves the amount on the payment (a
   reserve can no longer be allocated) and is not a transfer; execution records the bank reference,
   the date and the proof; OWNER may cancel an approved reserve before execution. Statuses PROPOSED /
   APPROVED / EXECUTED / REJECTED / CANCELLED, immutable payloads.
7. **Reversal of a posted payment is OWNER's** (R17): the payment becomes REVERSED with the reason;
   its active allocations are released with reason REVERSAL and the parts due are restored; nothing
   is deleted; a payment with an approved or executed refund cannot be reversed.
8. **Settlement state per claim version** (3.9): OPEN; PRINCIPAL_PAID_RETENTION_PENDING when the
   principal is paid and retention is still held or unpaid ("Principal paid, retention payout
   pending"); SETTLED when principal and retention are fully paid. Figures add principal due,
   principal paid, retention paid, paid (sum), balance due; never double-counted (T11: 15 000 on
   19 000 + 1 000 → 4 000 and 1 000).
9. Flag `FACTORY_PAYMENTS_ENABLED` (default off) on top of the reconciliation flag; OWNER only
   until section 12; downgrade refuses to discard posted payments.

## Owner decisions (not decided by code)
- Accountant: VAT rule, so that INC_VAT payments can be allocated against ex-VAT claims.
- Section 12: rights mapping (who posts, who allocates, who changes allocations of posted money).
- Bank file formats and the accountant's export: steps 10–11.

## Order of work
8a backend (migration 0095, models, service, API, tests) → 8b admin (payments tab: register, proof,
post, allocate, release, reverse, refunds; settlement in the reconciliation figures) → 8c record.
