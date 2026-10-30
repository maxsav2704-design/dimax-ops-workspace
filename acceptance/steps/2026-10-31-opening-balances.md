# Step 9: opening balances (2026-10-30 / 2026-10-31)

Spec: DIMAX_FACTORY_ACCOUNTING_SPEC.md 3.12, R23, R24, section 4, step 9 of section 8, scenario T13.
Proposal and decisions: `acceptance/steps/2026-10-30-step9-proposal.md`. Backend migration
`0096_opening_balances`; flag `OPENING_BALANCES_ENABLED` (default off) on top of `FACTORY_PAYMENTS_ENABLED`;
OWNER only until the section 12 rights mapping.

Marks: **confirmed by tests**, **studied by code**, **seen live**, **not verified**, **needs external infra**.

## 1. Before changes

Studied by code: steps 6-8 settle the work presented from the cutover (10 Nov 2026) on. Nothing recorded what
the factory owed, held back or had paid in advance on the day before, and nothing showed the accepted signed
work dated before the cutover, which the period rule never presents.

## 2. Decisions taken in this step (strictly inside the agreed logic)

- **Three kinds, entered apart** (3.12, R24): DEBT, RETENTION, ADVANCE rows with amount, basis text, tax basis
  (EX_VAT / INC_VAT / UNSPECIFIED, stored as entered, VAT never re-applied), terms (a due date for a debt or
  advance, a release condition for a retention, or an explicit "unknown"), an evidence file and the state date
  = the day before the cutover (2026-11-09). No detailed history is migrated.
- **A retention is extracted from the debt, never added**: approved RETENTION rows never exceed the approved
  DEBT (RETENTION_EXCEEDS_DEBT); opening principal = debt − retention.
- **Reconciled, then approved by OWNER**: the factory's acknowledgement (author, channel, time, attached
  message, acknowledged amount) is recorded on the draft; the difference is the disputed amount, its own
  attribute; acknowledging more than entered is refused. Changing a reconciled draft clears the
  acknowledgement and bumps the revision. The payload fingerprint is stored on every revision (draft, change,
  reconciliation); OWNER decides against that fingerprint with a one-time request id; approval needs the
  reconciliation (NOT_RECONCILED) and fixes the row as it stands, disputed amount included; approved and
  rejected rows are immutable (trigger); a mistake is a new row.
- **Joins the figures without doubling**: an approved DEBT row is an allocation target for its principal
  (bounded by the row's own amount and by the contract's opening principal remaining; the opening retention is
  not paid through allocations: OPENING_RETENTION_NOT_SUPPORTED); an approved ADVANCE becomes a posted payment
  of purpose ADVANCE through the step-8 posting path (proof = the evidence, the duplicate gate applies with no
  acknowledgement path, the payment has its own audit) and is allocated like any money; OWNER's reversal of
  that payment is refused (OPENING_ADVANCE): it is part of the approved row. The contract summary shows the
  opening figures apart from the claims; the money summary's payable amount includes the opening principal
  still unpaid (only while the flag is on).
- **No second debt from early work** (T13): accepted signed rows dated before the cutover are listed as early
  work (filtered in SQL by the local work day), never claimable; each approved DEBT states whether it covers
  that work and the list shows the coverage.
- Evidence and the factory's answers are contract-level files of the payments attachment table (never a
  payment's proof); downgrade refuses to discard approved rows.

## 3. Checks

| Check | Mark | Evidence |
|---|---|---|
| Flag off → 409; empty view as of 2026-11-09; evidence upload (payment_id null); terms validation (unknown carries none, retention needs a release condition, debt needs a due date; only a debt covers early work); unknown file → 404, a payment's proof → 422; drafts do not count; create idempotent; NOT_RECONCILED and PAYLOAD_MISMATCH before reconciliation; acknowledgement 4 800 of 5 000 → disputed 200 in the row and the payload; change clears the acknowledgement, revision 2, new fingerprint, old one mismatches; FINANCE → 403; approval fixes the row and its disputed amount, figures debt 5 000 / disputed 200 / covers early work; re-decision → 409; PATCH of an approved row → 409; a rejection needs no reconciliation; retention 6 000 → RETENTION_EXCEEDS_DEBT, 500 approved → retention 500, principal due 4 500 (extracted, not added); advance 1 000 acknowledged 900 → disputed 300 across kinds; a registered twin payment (same amount and date) blocks the approval with POSSIBLE_DUPLICATE and the row stays DRAFT, approved after the twin is cancelled; the advance is a POSTED payment of purpose ADVANCE with the evidence as proof, available 1 000, unallocated-by-purpose ADVANCE 1 000, payable now = claim principal + 4 500; its reversal → OPENING_ADVANCE; allocation without a target → 422, to a retention row → 409, RETENTION part → OPENING_RETENTION_NOT_SUPPORTED, 4 501 → EXCEEDS_AVAILABLE, 1 000 → label "opening", principal paid 1 000 / remaining 3 500, contract summary opening 3 500, payable now = claim principal + 3 500; release keeps the history and the audit names the opening balance (claim_id null); audit approved ×3, reconciled ×5, changed ×1 | confirmed by tests | `tests/integration/test_opening_balances.py::test_opening_balances_are_reconciled_then_approved_and_join_the_figures_without_a_second_debt` |
| Early signed work (door of 5 Nov) listed and not covered; the November package holds the 15 Nov door only; no period before the cutover (422); approved covering debt → covered, figures covers_early_work; the early row still cannot be presented | confirmed by tests | `::test_early_signed_work_is_listed_covered_and_never_claimable` |
| Downgrade refused with approved opening balances | confirmed by tests | `::test_downgrade_refuses_to_discard_approved_opening_balances` |
| Steps 6-8 suites with the opening additions (nullable claim target, `target_kind`, opening in the summaries, `_post_now`, SQL bound on early work) | confirmed by tests | run after the simplify pass: 15 passed (opening + payments + reconciliation + claims) |
| Regression: architecture, OpenAPI contract, RBAC matrix, commercial approvals / terms / drafts / activation, partial acceptance, claims, reconciliation, payments, opening balances | confirmed by tests: 293 passed, 3 failed — the pre-existing `test_outbox_health.py` cases of the other agent (see the step 4 record) | `scratchpad/open-reg2.log` (fresh database; the final run after the simplify pass is in `open-reg3.log`) |
| Admin: "Opening balances" tab — figures grid (as of, debt, retention, advance, disputed, principal due / paid / remaining, early work covered), add row (kind, amount, tax basis, terms known with due date or release condition, basis, covers early work, evidence upload required), edit a draft through PATCH keeping the old evidence (an untouched edit closes without the discard question; a changed draft shows "not reconciled yet"), reconcile (channel, author, time, acknowledged amount, attached answer, note), decide against the full fingerprint with the explicit check, evidence and answer files open from the row, early work table with coverage, switched-off message; payments tab: allocation target "Package / Opening debt" (opening takes the principal only), allocation rows labelled by target kind in RU/EN/HE | confirmed by tests: 30 passed across the five settlement test files; eslint and ratchets clean | `src/test/ContractOpening.test.tsx` (2), `ContractPayments.test.tsx` (2), `ClaimReconciliation.test.tsx` (3), `ContractClaims.test.tsx` (2), `FactoryAccountingPage.test.tsx` |
| Admin `tsc --noEmit`: only the five pre-existing errors in the other agent's `OutboxRecoveryPage.test.tsx` and `ContractTerms.test.tsx`; none in step-9 files | confirmed (step-9 files clean) | — |
| Live run on the disposable stack | not verified | the steps 6-8 recipe (`commercial-settlement.compose.yml`) applies with `OPENING_BALANCES_ENABLED=true`; not run in this pass (host memory) |

## 3a. Review pass (owner's skills: code-review, security-review, simplify; 2026-10-31)

- **code-review (high)**: 10 findings, all fixed with regression tests — reversal of the advance payment refused;
  release / reversal audit names the opening balance instead of `claim_id: "None"`; the advance approval goes
  through the step-8 duplicate gate; `disputed` sums every kind; evidence and answer files open from the tab;
  the money summary adds the opening principal only with the flag on; one row scan and one attachment query
  per view; the forwarding wrapper removed; the edit dialog's "dirty" means changed; the suite covers the
  duplicate gate, the refused reversal and the release audit.
- **security-review**: no findings. Every new route depends on `require_draft_owner`; rows, attachments and
  allocation targets are scoped by company and contract; the fingerprint is recomputed server-side and
  compared with `compare_digest`; the posted advance is built from server values only; the admin adds no
  unsafe DOM sinks and downloads through the authenticated client.
- **simplify (reuse / simplification / efficiency / altitude)**: applied — read side moved to the leaf
  `opening_figures.py` (no function-local imports; `ContractReconciliationSummary.opening` typed as
  `OpeningFigures`); the payload fingerprint stored on every revision and compared as stored (step 7/8
  pattern); `_contract_attachment` and `add_evidence` reuse the payment service's `_attachment` / `_store`;
  the approved advance posted through one shared `_post_now`; figures computed only for a retention approval;
  the early-work bound pushed into SQL; the allocation target bounded by the named row as well as the contract
  principal; `AllocationDTO.target_kind` labels the target (no English sentinel in RU/HE); the write's response
  replaces the view instead of a refetch; `part` is the single truth in the allocate dialog; shared
  `FiguresGrid` / `AttachmentLink` / `setter` for the settlement panels (the opening panel uses them; the
  claims and payments panels keep their copies for now).
  Skipped on purpose: dropping `payload` from the DTO and the per-row `covered` flag (both are in the step-9
  proposal and asserted by the tests); extracting a shared factory-answer form from the step-7 dialog;
  carrying the opening debts on the money summary (the allocate dialog keeps its on-demand query, hidden on
  409 and shown as an error otherwise); a contract-level aggregate target instead of a row (kept the row, now
  bounded by its own amount, so the audit names the row that received the money).

## 4. Owner decisions still open (section 12)

- The real opening amounts, documents and the factory's acknowledgements.
- Release of an opening retention and allocation of payments to it; the VAT rule for INC_VAT balances.
- Rights beyond OWNER for entering and reconciling opening balances.

## 5. Not done / next

- Live run of the opening tab on the disposable stack (recipe in the step-8 record).
- Step 10 and later per the section 8 order; nothing pushed (steps 5-9 wait for explicit approval).
