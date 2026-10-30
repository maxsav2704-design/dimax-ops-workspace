# Step 8: payments, advances and refunds (2026-10-30)

Spec: DIMAX_FACTORY_ACCOUNTING_SPEC.md 3.9, 3.10, R17, R18, section 4, step 8 of section 8, scenarios
T11, T12. Proposal and decisions: `acceptance/steps/2026-10-30-step8-proposal.md`. Backend migration
`0095_factory_payments`; flag `FACTORY_PAYMENTS_ENABLED` (default off) on top of
`FACTORY_RECONCILIATION_ENABLED`; OWNER only until the section 12 rights mapping.

Marks: **confirmed by tests**, **studied by code**, **seen live**, **not verified**, **needs external infra**.

## 1. Before changes

Studied by code: step 7 gave each issued claim version its figures with `paid` empty. Nothing recorded
money received from the factory, what it settled, what stayed unallocated, or a refund.

## 2. Decisions taken in this step (strictly inside the agreed logic)

- **A payment is money received, apart from what it settles**: amount as received, date, counterparty
  as on the statement, bank reference, stated purpose, purpose kind (SETTLEMENT / ADVANCE / UNKNOWN),
  tax basis of the amount. DRAFT → POSTED only with a bank proof attached (R17); DRAFT → CANCELLED
  with a reason; POSTED → REVERSED only by OWNER; every other change is refused by a trigger.
- **Duplicates are checked, not guessed**: the same bank reference on the contract is refused while a
  draft or posted payment carries it; the same amount and date, or the same proof file, only warn and
  posting needs an explicit acknowledgement, which is stored on the payment and in the audit.
- **Allocations are many-to-many and bounded**: PRINCIPAL or RETENTION part of one issued claim
  version; never above the payment's available amount (amount − active allocations − approved or
  executed refunds) nor above the part still due (principal remaining; released retention unpaid);
  same contract and currency; the contract row is locked, so two concurrent allocations of the same
  money let exactly one through. A released allocation stays with its reason; a change is a new row.
- **Same basis only**: until the accountant answers, only payments stated ex-VAT are allocated;
  INC_VAT / UNSPECIFIED money stays visible as "needs the VAT rule".
- **Advance, unallocated, overpayment apart from the work**: the money summary shows received,
  allocated, unallocated by purpose, reserved, refunded, needs-VAT-rule, payable now and the
  overpayment (allocatable unallocated money beyond everything payable). A later allocation of an
  advance references the same payment: no second receipt.
- **Refund = proposal → OWNER decision (reserve) → bank execution**: fingerprinted payload; approval
  checks the available amount again and reserves it (a reserve is neither allocated nor reversed
  away); execution records date, bank reference and proof; OWNER may cancel before execution.
- **Reversal is OWNER's**: active allocations are released with "REVERSAL: reason", the parts due are
  restored, nothing is deleted; refused while a refund is approved or executed.
- **Settlement per claim version** (T11): principal due = outstanding − retention; paid = principal
  paid + retention paid; balance due = outstanding − paid; payable now = principal remaining +
  released retention unpaid; OPEN / PRINCIPAL_PAID_RETENTION_PENDING / SETTLED. Nothing is doubled:
  d on (2d − d/2) payable with d/2 retention leaves d/2 principal and d/2 retention.

## 3. Checks

| Check | Mark | Evidence |
|---|---|---|
| Flag off → 409; draft without proof cannot be posted (PROOF_REQUIRED); same bank reference refused (DUPLICATE_BANK_REFERENCE); three decimals → 422; proof uploaded and downloadable with `no-store`; posting idempotent by request id; posted draft cannot be cancelled; same amount and date → POSSIBLE_DUPLICATE with the warning list, posted only with the acknowledgement (stored); allocation above available → EXCEEDS_AVAILABLE, foreign claim → 422, idempotent; T11 figures (principal paid, remaining, held, payable now, paid, balance due, OPEN); above due → EXCEEDS_DUE; retention before release → EXCEEDS_RELEASED; principal settled → PRINCIPAL_PAID_RETENTION_PENDING; released retention paid → SETTLED with balance 0; release keeps history and a new allocation settles again; claim reconciliation lists allocations with bank references; money summary; posted payments and allocations immutable; audit posted ×2, allocated ×4, released ×1 | confirmed by tests | `test_factory_payments.py::test_a_payment_settles_principal_and_released_retention_without_double_counting` |
| Advance 3d and INC_VAT payment: unallocated by purpose, needs-VAT-rule, overpayment d; INC_VAT allocation → NEEDS_VAT_RULE; two concurrent allocations → one 200, one 409; advance settles the claim from the same source (two allocations, one receipt); refund above available → 409; proposal with fingerprint; wrong fingerprint → PAYLOAD_MISMATCH; FINANCE → 403; approval reserves (available 0), idempotent, re-decision → 409; reserved money cannot be allocated or reversed away (REFUND_PENDING); second refund → EXCEEDS_AVAILABLE; execution with uploaded proof, idempotent; executed refund cannot be cancelled; summary refunded / open refunds; OWNER reversal of a late payment releases its allocation with the reason and restores the due amount, idempotent, OPERATIONS → 403, reversed row immutable; draft cancelled with reason; audit reversed / proposed / approved / executed / cancelled ×1 | confirmed by tests | `::test_advance_overpayment_refund_concurrency_and_owner_reversal` |
| Downgrade refused with posted payments | confirmed by tests | `::test_downgrade_refuses_to_discard_posted_payments` |
| Step 7 suite still green with `paid` and `settlement` in the figures | confirmed by tests | run 1: 7 passed (payments + reconciliation) |
| Regression: architecture, OpenAPI contract, RBAC matrix, commercial approvals / terms / drafts / activation, partial acceptance, claims, reconciliation, payments | confirmed by tests: 290 passed, 3 failed — the pre-existing `test_outbox_health.py` cases of the other agent's outbox recovery (see the step 4 record) | `scratchpad/pay-2.log` |
| Admin: "Payments" tab — money summary, register dialog, proof upload per draft (post disabled until a proof exists), posting shows the duplicate warning and posts only with the explicit acknowledgement, allocate dialog (issued package, part, amount), allocations under the payment with release, refund proposal, decision against the full fingerprint, execute with proof, reverse with reason and one-time request id, switched-off message; reconciliation figures show paid, retention paid, balance due and the settlement state, allocations listed on the claim | confirmed by tests: 28 passed across the four files (incl. `FactoryAccountingPage.test.tsx`); eslint and ratchets clean | `src/test/ContractPayments.test.tsx` (2), `ClaimReconciliation.test.tsx` (3), `ContractClaims.test.tsx` (2); eslint; ratchets |
| Admin `tsc --noEmit`: only the five pre-existing errors in the other agent's `OutboxRecoveryPage.test.tsx` and `ContractTerms.test.tsx`; none in step-8 files | confirmed (step-8 files clean) | — |
| Live run (admin pane, real upload through the browser) | not verified in this block | — |

## 4. Open

- Accountant: VAT rule, so INC_VAT money can be allocated against ex-VAT claims.
- Section 12: rights mapping (who posts, allocates, changes allocations of posted money); today all
  OWNER. Bank file formats and the accountant's export: steps 10–11.
- Payment due dates are still not computed (section 12 payment term rule); late journals are
  tracked by their execution period, not by a due date.
- Opening balances and the cutover backlog: step 9.
