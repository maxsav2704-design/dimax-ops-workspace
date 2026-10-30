# Step 7 proposal: reconciliation with the factory and retentions (2026-10-30)

Spec: DIMAX_FACTORY_ACCOUNTING_SPEC.md 3.7, 3.8, 3.10, R13–R16, section 4 (rights), step 7 of
section 8, scenarios T09, T10. Owner (chat, 2026-10-30): keep going in order, strictly inside the
agreed logic. Earlier owner decisions still in force: accounting starts 10 November 2026, periods
10th → 10th Asia/Jerusalem, VAT is not computed until the accountant answers, everything commercial
is OWNER only until the section 12 rights mapping is decided.

## What exists (studied by code)

Step 6 issues a frozen package (claim version) per contract and period with an exact amount ex-VAT
and an issue snapshot. Nothing records what the factory answered, what it acknowledged, what stays
disputed, whether anything was written off, or whether part of the obligation is held back as a
retention. The contract terms carry payment and retention terms as approved free text only; the
formulas (payment term rule, retention base and limit, release conditions) are open in section 12.

## Decisions for the code (strictly inside the agreed logic)

1. **A factory answer is bound to an exact issued claim version** (3.7, R15): claim id, number and
   version, the presented amount and the sha256 of the issue snapshot are copied into the answer.
   The answer stores the author, the channel (EMAIL or WHATSAPP), the time of the answer, the
   attachment (uploaded first, stored with its sha256, served only through the same OWNER guard),
   the acknowledged amount and its tax basis (EX_VAT, INC_VAT or UNSPECIFIED). Answers are
   immutable (trigger); the current answer of a version is the latest by answer time.
2. **Presented, acknowledged and disputed are three numbers** (3.7, T09). Disputed = presented −
   acknowledged, computed by the server, never negative: an acknowledged amount above the presented
   one is refused (a higher figure needs a new claim version, not an answer). A smaller acknowledged
   amount writes nothing off. An answer whose tax basis is not EX_VAT cannot be compared with the
   ex-VAT claim until the accountant answers: it is stored as given and marked `comparison:
   NEEDS_CLARIFICATION`, the disputed amount stays the whole presented amount.
3. **Detail or clarification, never allocation** (3.7). An answer may carry per-line decisions
   (ACKNOWLEDGED / DISPUTED with the factory's note); then the acknowledged amount is the sum of the
   acknowledged lines and a stated total that differs is refused as inconsistent. An answer without
   lines leaves the dispute at package level and is marked `detail: NONE` → clarification required;
   the server never spreads the difference over lines.
4. **A write-off is a two-step OWNER decision** (3.7, R16, section 4). An admin prepares a
   correction: kind WRITE_OFF, exact payload (amount ex-VAT, optional disputed line ids, basis =
   the answer it rests on), reason. The payload is fingerprinted (sha256). Approval is a separate
   request that carries the correction id, the payload fingerprint, the expected claim version and
   a one-time request id: a changed payload (new correction voids the old one), a corrected claim
   (version moved on) or a reused request id with a different body is refused; the same request id
   with the same body is idempotent. Approval and the financial effect are one transaction: the
   correction becomes APPROVED with `applied_amount_ex_vat`; the claim and its lines stay as issued.
   A write-off never exceeds what is still outstanding on the version; the total written off is
   shown separately from the dispute, which does not disappear by itself. Rejection is recorded
   with a reason. Until section 12 maps the financial rights, preparing and approving are both
   OWNER actions (two audit entries, two requests).
5. **A retention is part of the obligation, never a new debt or a discount** (3.8, R14, R16, T10).
   OWNER records a retention on an issued claim version: amount ex-VAT, the contract basis (clause
   text), the release condition. The amount is entered, never computed — base, limit and VAT
   treatment are section 12. Changes are new revisions (the previous one becomes SUPERSEDED, reason
   kept); a revision below the already released sum is refused. A release records the amount, the
   evidence that the condition occurred (text + optional attachment) and is immutable; the released
   sum never exceeds the retention. Registering a release is OWNER until section 12 says otherwise.
6. **The reconciliation view never double-counts** (3.8, 3.10, T11 preparation): per claim version
   `presented`, `acknowledged`, `disputed`, `written_off`, `outstanding = presented − written_off`,
   `retention_held = retention − released`, `payable_now = outstanding − retention_held`, `paid =
   null` (step 8). Superseded and cancelled versions carry no numbers. The contract summary adds
   the issued versions up with the same fields.
7. **No invented terms**: payment due dates are not computed (payment term rules are section 12);
   the applied terms text is already frozen in the issue snapshot. An answer never confirms the
   price list or a payment (3.7): it changes nothing outside the reconciliation tables.
8. Flag `FACTORY_RECONCILIATION_ENABLED` (default off) on top of `FACTORY_CLAIMS_ENABLED`.
   Downgrade refuses to discard approved corrections, answers and releases.

## Owner decisions (not decided by code)
- Section 12: payment term rule, retention base/limit/VAT treatment, partial release conditions,
  who registers a release; rights mapping OWNER / FINANCE for registering answers and preparing
  corrections.
- Accountant: VAT rate and tax moment, so that INC_VAT answers can be compared.

## Order of work
7a backend (migration 0094, models, service, API, tests) → 7b admin (reconciliation on the claims
tab: answers with attachment, write-off preparation and approval, retention and releases) → 7c record.
