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
| Live run on the disposable stack (`acceptance/commercial-settlement.compose.yml`: flags on + disposable MinIO; admin dev server 4194 → gateway 8003; synthetic OWNER through the real login): November package 1.1 composed and issued (3 lines, 951.00); factory answer registered with the uploaded message (801.00 acknowledged → disputed 150.00, clarification required); write-off 150.00 prepared with the disputed line and approved against the full fingerprint and version 1.1 (outstanding 801.00); retention 100.00 recorded (payable now 701.00); payment 500.00 registered, proof uploaded, posted, allocated to 1.1 (payable now 201.00); advance 300.00 posted and allocated 201.00 (overpayment 99.00 shown apart); refund 99.00 proposed, approved by OWNER, executed with the transfer proof (refunded 99.00, payable now 0); claim figures end at paid 701.00, balance due 100.00, state "Principal paid, retention payout pending" | seen live | browser pane 2026-10-30; network log: every write 200/201 |

## 3a. Review pass (owner's skills: code-review, security-review, simplify; 2026-10-30)

- **code-review (high)**: 11 findings, all fixed with regression tests — money allocated to a version now
  blocks the step-6 correction (RECONCILED); a write-off is capped at the unpaid principal, a retention at
  the unpaid part (paid money is never written off or re-labelled); the proof of a received payment
  cannot prove an outgoing refund; FK from a proof to its payment; the duplicate bank-reference check is
  the unique index alone; `AttachmentDTO` carries `claim_id` / `payment_id` honestly; batch loading of
  allocations/refunds; shared helpers for uploads and request-id replay; tests for SAME_PROOF and for
  cancelling an approved refund.
- **security-review**: no finding with confidence ≥ 7 (tenant and ownership checks on every child row,
  bound SQL only, sanitised object keys, attachments served as downloads). Hardening applied anyway:
  `X-Content-Type-Options: nosniff` on attachment downloads.
- **simplify** (three angles; the fourth agent hit the usage limit): applied — `common.py` (money,
  fingerprint, request-id replay, decision replay, attachment store) shared by the settlement services;
  `claim_effects.py` as a leaf module so step 6 needs no late import; one `Rows` bundle per claim loaded
  once per write and in bulk for the summaries; targeted duplicate queries; sync upload handlers (no
  blocking work on the event loop); shared route helpers `write` / `attachment_response`; admin:
  `contractPath` as the single base, `form.ts` / `use-upload.ts` / `PayloadDecisionDialog` shared by both
  panels, the post dialog on the common write hook (409 meta exposed), dialog-only queries fetched on
  demand. Skipped on purpose: storing the issue-snapshot hash on the claim (needs a column; the hash is
  cheap), a `kind` column on attachments (schema change, noted for step 10 when delivery files arrive),
  request ids on cancel/release (idempotent by state), carrying decisions over to a corrected version
  (owner decision).
- Gates after the pass: settlement modules 13 passed (slow run, 14 min, host under memory pressure after
  a Docker Desktop restart); admin 28 passed, eslint, ratchets, tsc (same five pre-existing errors).

## 3b. Found live and fixed

- Attachment links were plain `<a href>` to the API path: on a split origin they hit the admin host and carry no
  token. Downloads now go through the authenticated `apiDownload` client (`downloadAttachment`).
- Issuing a package did not refresh the reconciliation summary on the Claims tab (stale "issued: 0"); the
  tab now invalidates the summary too.
- The disposable stack had no object store: uploads failed with 500 until a disposable MinIO was added to the
  overlay (documented there). The 2026-10-23 journal seeding script wrote rows into an already signed
  journal and is refused by the 0092 trigger; `settle-journal.py` (scratchpad) writes rows first.

## 4. Open

- Accountant: VAT rule, so INC_VAT money can be allocated against ex-VAT claims.
- Section 12: rights mapping (who posts, allocates, changes allocations of posted money); today all
  OWNER. Bank file formats and the accountant's export: steps 10–11.
- Payment due dates are still not computed (section 12 payment term rule); late journals are
  tracked by their execution period, not by a due date.
- Opening balances and the cutover backlog: step 9.
