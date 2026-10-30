# Step 7: reconciliation with the factory and retentions (2026-10-30)

Spec: DIMAX_FACTORY_ACCOUNTING_SPEC.md 3.7, 3.8, 3.10, R13–R16, section 4, step 7 of section 8,
scenarios T09, T10. Proposal and decisions: `acceptance/steps/2026-10-30-step7-proposal.md`. Backend
migration `0094_factory_reconciliation`; flag `FACTORY_RECONCILIATION_ENABLED` (default off) on top of
`FACTORY_CLAIMS_ENABLED`; OWNER only until the section 12 rights mapping.

Marks: **confirmed by tests**, **studied by code**, **seen live**, **not verified**, **needs external infra**.

## 1. Before changes

Studied by code: an issued claim version was frozen with its amount, but nothing recorded what the
factory answered, what it acknowledged or disputed, whether anything was written off, or whether part
of the obligation was held back. Payment and retention terms exist only as approved free text.

## 2. Decisions taken in this step (strictly inside the agreed logic)

- **The answer is bound to the exact version**: claim id, number.version, presented amount and the
  sha256 of the issue snapshot are copied into it; author, channel (EMAIL / WHATSAPP), time of the
  answer, the attached message (uploaded first, stored once per claim by sha256, served through the
  same OWNER guard), acknowledged amount and its tax basis. Answers are immutable rows.
- **Three numbers, no automatic write-off** (T09): disputed = presented − acknowledged, computed by
  the server and stored; a database check keeps the three numbers adding up; acknowledging more than
  presented is refused. An answer without line detail is marked "clarification required" and the
  difference is never spread over lines; a detailed answer must decide every line and add up.
  An answer with VAT included (or no basis) is stored as given and marked NEEDS_CLARIFICATION: the
  whole claim stays disputed until the accountant answers; line detail is refused for it.
- **Write-off = prepared payload + OWNER decision** (R16, section 4): the prepared row stores the
  payload and its sha256; the decision carries the fingerprint, the expected claim version and a
  one-time request id; a changed payload is a new correction that voids the old one (PAYLOAD_CHANGED);
  a moved claim version is refused (VERSION_MISMATCH); re-sending the same decision is idempotent, a
  different decision under the same request id is refused. Approval re-checks the outstanding amount
  and applies the effect in the same transaction (`applied_amount_ex_vat`); the issued claim and its
  lines never change. Preparing and approving are separate requests and audit entries; both OWNER.
- **Retention is part of the obligation** (T10): recorded on the issued version with its contract
  basis and release condition, amount entered (never computed — section 12), never above the
  outstanding amount; a change is a new revision (old one SUPERSEDED, releases kept), never below
  the released sum; a release records the evidence (text + optional file), never exceeds what is
  held and never adds debt; releases are immutable.
- **No double counting**: `outstanding = presented − written off`; `held = retention − released`;
  `payable now = outstanding − held`; `paid` stays null until step 8; VAT never computed. A write-off
  is limited by what is outstanding beyond the retention. Superseded and cancelled versions carry no
  numbers; the contract summary adds the issued versions up with the same fields.
- **A step-6 correction of a version that carries decisions is refused** (RECONCILED): an approved
  write-off, a retention with an amount or a release would be lost silently by a new version; they
  must be re-decided explicitly first. Answers alone do not block.
- **Nothing invented**: payment due dates are not computed (section 12); the answer confirms neither
  the price list nor a payment (audit `confirms_prices: false`, `confirms_payment: false`).

## 3. Checks

| Check | Mark | Evidence |
|---|---|---|
| Flag off → 409; unanswered version: acknowledged null, disputed 0, paid null; attachment stored once (same file → same id), downloaded with `no-store`, empty file refused; unknown attachment → 404; acknowledged above presented → 422; package-level answer gives presented / acknowledged / disputed with nothing written off, clarification required; idempotent by request id, different body → 409; INC_VAT answer → NEEDS_CLARIFICATION with the whole claim disputed, line detail refused; detailed answer must cover every line and add up, then no clarification; answers immutable (trigger); claim amount unchanged; audit ×3 with `confirms_prices/payment: false`; contract summary | confirmed by tests | `test_factory_reconciliation.py::test_the_answer_gives_three_numbers_and_never_writes_off_by_itself` |
| Write-off: above outstanding → 409; named lines must add up → 422; unknown basis → 422; three decimals → 422; prepared row with payload and fingerprint, figures unchanged, idempotent; wrong fingerprint → 409; wrong expected version → 409; new payload voids the old one, old decision → PAYLOAD_CHANGED; FINANCE scope → 403; approval applies the amount (written off, outstanding, payable), dispute stays; idempotent re-decision; same request id with another decision → 409; already decided → 409; rejection with reason; approved row immutable; claim and lines untouched; step-6 correction → RECONCILED; audit prepared ×3, approved ×1, rejected ×1 | confirmed by tests | `::test_a_write_off_needs_owner_approval_of_the_exact_payload_and_version` |
| Retention: release without retention → 409; above outstanding → 409; set → held, outstanding unchanged, payable reduced, idempotent; release above held → 409; partial release with evidence file → released / held / payable, no new debt; revision below released → 409; new revision supersedes and keeps releases; write-off limited by the retention; release to zero, further release → 409; retention and release rows immutable; step-6 correction → RECONCILED; summary; audit set ×2, released ×2 | confirmed by tests | `::test_a_retention_is_part_of_the_obligation_and_a_release_never_creates_debt` |
| Downgrade refused with registered answers | confirmed by tests | `::test_downgrade_refuses_to_discard_registered_answers` |
| Regression: architecture, OpenAPI contract, RBAC matrix, commercial approvals / terms / drafts / activation, partial acceptance, claims, reconciliation | confirmed by tests: 287 passed, 3 failed — the pre-existing `test_outbox_health.py` cases of the other agent's outbox recovery (see the step 4 record) | `scratchpad/recon-2.log` |
| Admin: "Reconcile" on issued / superseded packages opens the panel — figures (presented, acknowledged, disputed, written off, outstanding, retention, released, held, payable now, paid as a later step), answer registration with required attachment (uploaded first, then the JSON body with `attachment_id`), optional per-line decisions, write-off preparation with lines and basis, decision dialog showing the full fingerprint and expected version with an explicit check, retention set / change, release with evidence, contract summary, switched-off message | confirmed by tests | `src/test/ClaimReconciliation.test.tsx` (3), `ContractClaims.test.tsx` (2); eslint; ratchets |
| Admin `tsc --noEmit`: only the five pre-existing errors in the other agent's `OutboxRecoveryPage.test.tsx` and `ContractTerms.test.tsx`; none in step-7 files | confirmed (step-7 files clean) | — |
| Live run (admin pane, real upload through the browser) | not verified in this block | — |

## 4. Open

- Section 12: payment term rule (due dates not computed), retention base / limit / VAT treatment,
  partial release conditions and who registers a release; rights mapping OWNER / FINANCE for
  registering answers and preparing corrections (today all OWNER).
- Accountant: VAT rate and tax moment, so INC_VAT answers become comparable.
- Payments and advances (recorded `paid` is null): step 8. Opening balances: step 9.
- Carrying decisions over to a corrected claim version: today refused (RECONCILED); the rule for
  re-deciding on the new version is an owner decision.
