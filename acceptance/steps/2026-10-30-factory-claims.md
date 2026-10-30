# Step 6: claims to the factory (2026-10-30)

Spec: DIMAX_FACTORY_ACCOUNTING_SPEC.md 3.6, R12, R13, step 6 of section 8, scenarios T06, T07.
Proposal and decisions: `acceptance/steps/2026-10-30-step6-proposal.md`. Backend migration
`0093_factory_claims`; flag `FACTORY_CLAIMS_ENABLED` (default off) on top of `COMMERCIAL_ACTIVATION_ENABLED`;
OWNER only.

Marks: **confirmed by tests**, **studied by code**, **seen live**, **not verified**, **needs external infra**.

## 1. Before changes

Studied by code: the period estimate valued accepted signed lines but recorded nothing; nothing could
be presented to the factory and nothing prevented presenting the same volume twice.

## 2. Decisions taken in this step (strictly inside the agreed logic)

- **A claim is a package per contract and execution period**: number per contract, version 1; MAIN for the
  first package of a period, SUPPLEMENT for later ones (late journals keep their execution period).
- **Lines are exact references to accepted signed rows** (door, addon), rated at the agreement in effect
  on the work day, ex-VAT, rounded per line; VAT is never computed. Unrated rows (no pair in effect, no
  rate, stage rows pending section 12) are never claimed and stay a visible backlog with their reason.
- **A volume is claimed once.** A draft reserves its rows; a partial unique index per row kind refuses a
  second active reservation across packages and concurrent requests; the contract row is locked while a
  package is composed; cancelling a draft releases its rows explicitly.
- **Issue freezes the package**: snapshot of contract, factory legal data from the terms in effect, price
  versions, totals and line count; a database trigger refuses any change to an issued claim or its lines
  except the status to SUPERSEDED and the release flag; issuing again with the same request id is
  idempotent; an issued package is never cancelled.
- **A correction never doubles the debt**: a new version of the same number supersedes the issued one,
  which releases its rows; the new draft re-reserves the rows accepted now; superseded totals are excluded.
- **Delivery of the package files is step 10**: issued means composed and frozen.

## 3. Checks

| Check | Mark | Evidence |
|---|---|---|
| November package: claimable rows and amount equal the estimate (excluded row and undated row skipped), draft idempotent by request id, rows reserved (second draft → NOTHING_TO_CLAIM, lines show `claimed_in 1.1`), December untouched; issue needs the exact line count and an explicit review; issued package frozen (claim and line updates raise IntegrityError), re-issue idempotent, cancel refused; late journal → SUPPLEMENT number 2; cancelling the draft releases its row; audit CLAIM_DRAFTED ×2, CLAIM_ISSUED | confirmed by tests | `test_factory_claims.py::test_period_package_claims_each_accepted_row_once_and_keeps_the_backlog_visible` |
| Correction: version 2 of the same number supersedes version 1, collects both rows, period shows every row claimed once by 1.2, superseded excluded, correcting a draft refused, idempotent by request id | confirmed by tests | `::test_correction_supersedes_the_issued_package_without_doubling_the_debt` |
| Unrated rows stay backlog (NO_RATE), composing refused, period not on the 10th → 422, flag off → 409 | confirmed by tests | `::test_unrated_rows_and_stage_rows_stay_backlog_and_the_flag_gates_everything` |
| Two concurrent drafts for the same period: one 200, one 409; every row reserved exactly once | confirmed by tests | `::test_concurrent_drafts_reserve_each_row_once` |
| Downgrade refused with issued claims | confirmed by tests | `::test_downgrade_refuses_to_discard_issued_claims` |
| Commercial activation suite unchanged (9) | confirmed by tests | run 1: 14 passed |
| Regression: architecture, commercial approvals / terms / drafts, OpenAPI contract, RBAC matrix, partial acceptance, claims | confirmed by tests: 274 passed, 3 failed — the pre-existing `test_outbox_health.py` cases of the other agent's outbox recovery (see the step 4 record) | `scratchpad/claims-2.log` |
| Admin: "Claims" tab on the contract — period view with claimed / claimable / backlog and reasons, compose package (request id, period only), packages table, issue after an explicit review with the exact line count, cancel with a reason, correct action on issued packages, switched-off message | confirmed by tests | `src/test/ContractClaims.test.tsx` (2); eslint and ratchets | 
| Admin `tsc --noEmit`: only the five pre-existing errors in the other agent's `OutboxRecoveryPage.test.tsx` and `ContractTerms.test.tsx`; none in step-6 files | confirmed (step-6 files clean) | — |
| Live run | not verified in this block | — |

## 4. Open

- Section 12: stage rates (stage rows stay backlog), VAT rate and tax moment (amounts stay ex-VAT).
- Package files, delivery and the factory's "received" mark: step 10. Reconciliation answers, retention
  and payments: steps 7–8.
- The project-to-contract link: a period with two contracts in effect stays blocked (as in the estimate).
