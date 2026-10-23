# Commercial activation stage: pair in effect, rate resolver, periods, read-only estimate (2026-10-23)

Owner's decisions (chat, 2026-10-23): first effective date 10 November 2026; build the period estimate;
estimate for OWNER only; stage-based contracts wait for stage facts; VAT is not computed until the
accountant answers. Proposal: `2026-10-23-activation-proposal.md`. Spec: DIMAX_FACTORY_ACCOUNTING_SPEC.md
3.2, 3.10, 8, 9 (T01), 12.

Marks: **confirmed by tests**, **studied by code**, **seen live** (browser pane, disposable stack),
**not verified**, **needs external infra**.

## 1. What was built

Backend (migration `0087_commercial_agreements`, feature flag `COMMERCIAL_ACTIVATION_ENABLED`, default off):

- `commercial_agreements`: one row per factory decision put into effect by an OWNER: contract, exact
  terms and price versions, the approval, `effective_from`, `effective_until`, who, when, why, request
  id and fingerprint, snapshot hash. Database guards: composite tenant foreign keys to the terms, price
  and approval; one activation per decision; `effective_from >= 2026-11-10`; at most one open agreement
  per contract (partial unique index); a trigger that refuses overlaps, refuses deletes and allows one
  change only: closing an open agreement. Downgrade refuses while any agreement or its audit exists.
- `POST /admin/accounting/contracts/{id}/agreements` (OWNER, explicit `accepted`, reason, idempotent by
  request id): only a CONFIRMED, non-revoked decision; demo contracts only under `APP_ENV=test`; the
  date not before the accounting start and not before the proposed dates of the confirmed versions; the
  previous open agreement is closed the day before; audit `COMMERCIAL_AGREEMENT ACTIVATE` with
  `creates_claim=false`, `affects_earnings=false`. `GET …/agreements` lists history, the pair in effect
  today and whether the flag is on. Approval rows now carry `agreement_id`.
- `CommercialRateResolver.rate_for(company, contract, kind, target, on_date)`: the rate of the pair in
  effect on that date with version and decision reference; no agreement or no position → `None`, never
  a default price; demo contracts → `None` outside tests.
- Periods (`app/modules/accounting/domain/periods.py`): 10th inclusive to the next 10th exclusive in
  Asia/Jerusalem, computed from the local calendar day; naive datetimes refused.
- `GET …/periods` and `GET …/periods/{start}` (OWNER, flag on): signed journal lines (door items by
  `installed_at`, addon facts by `done_at`) valued at the rate in effect on the work day; reasons
  `RATED`, `NO_AGREEMENT`, `STAGES_NOT_SUPPORTED`, `NO_RATE`; lines without a work date counted
  separately; amounts Decimal, two places, half-up; `vat: null`, `estimate_only: true`. When two
  contracts of the company are in effect at once the estimate is blocked (`MULTIPLE_CONTRACTS`): the
  project-to-contract link is a later step. Before 10 November the first period is listed empty.

Admin (production build, EN/RU/HE):

- "Согласование заводом": block "Действует" with the pair in effect and history; button "Ввести в
  действие" on confirmed rows (only when the server flag is on); dialog with date (default
  10.11.2026, not earlier), reason and explicit consent; send disabled until consent.
- New tab "Периоды": period table (signed journals, rated lines, lines without rate, amount excl. VAT)
  with the VAT note, drill-down to lines with the reason per unrated line; "stage switched off" message
  when the server answers 409.

Not changed: installer rates and earnings, journals and signatures, mobile, claims, invoices, payments.

## 2. Checks

| Check | Mark | Evidence |
|---|---|---|
| T01: 9 Nov 23:59:59 and 10 Nov 00:00 Israel time are different periods; summer/winter offsets; naive datetime refused | confirmed by tests | `test_commercial_activation.py::test_t01_period_boundary_in_jerusalem_across_dst` |
| OWNER activates a confirmed pair; 422 for missing consent, a date before the start or before the proposed dates; idempotent replay; 409 for a changed payload, a second activation of the same decision; resolver rates inside the range only, `None` for unknown positions and stage codes; installer rate and earning counts unchanged; one audit row | confirmed by tests | `::test_owner_puts_confirmed_pair_into_effect_without_financial_effect` |
| Pending or revoked decision cannot be activated; unknown decision 404 | confirmed by tests | `::test_unconfirmed_pending_or_revoked_decision_cannot_be_activated` |
| Second confirmed pair from 10 Dec closes the first on 9 Dec; a date not later than the current start is refused; resolver returns v1 in November and v2 in December; updating or deleting a closed agreement is refused by the trigger | confirmed by tests | `::test_next_pair_closes_the_previous_agreement_gap_free_and_history_is_immutable` |
| OPERATIONS 403, foreign contract 404, flag off → page says disabled and commands answer 409, demo contract outside tests 409 | confirmed by tests | `::test_only_owner_in_the_same_company_and_only_with_the_flag` |
| Estimate: door at 15 Nov and 2.5 h addon rated, door at 9 Nov 23:30 local falls in October, undated door counted separately, unsigned journal ignored, December door in the next period, detail lines, 404 for periods before the start or after today; before 10 Nov only the first period, empty | confirmed by tests | `::test_period_estimate_values_signed_lines_at_the_rate_in_effect` |
| `NO_AGREEMENT` before activation, `NO_RATE` for an unpriced door type, `STAGES_NOT_SUPPORTED` once a stage-based pair is in effect | confirmed by tests | `::test_estimate_marks_lines_without_agreement_or_rate_and_stage_contracts` |
| Two contracts in effect → estimate blocked | confirmed by tests | `::test_estimate_is_blocked_while_two_contracts_are_in_effect` |
| Downgrade of 0087 refused with history | confirmed by tests | `::test_downgrade_refuses_to_discard_agreements` |
| Backend regression after the DTO change | confirmed by tests | approvals 16 + contract terms 30 = 46 passed |
| Admin: activate button only with the flag; dialog default date, refusal of an earlier date, body `{request_id, approval_id, effective_from, reason, accepted: true}`; hidden when the flag is off; periods table, VAT note, undated note, drill-down reasons; 409 message | confirmed by tests | `src/test/ContractAgreements.test.tsx` (4) + `ContractApprovalsPanel` (3) + `FactoryAccountingPage` (21) |
| Admin gates | confirmed | `tsc --noEmit` clean, eslint clean, type-scale and RTL ratchets pass, production build (`next build --webpack`, 41 s compile, 69 s TypeScript) |
| Live on the disposable stack (`dimax-activation-20261023`, db migrated 0086 → 0087, built admin on 4194): factory decision recorded through the gateway; one signed synthetic journal inserted (priced door 15 Nov, priced door 9 Nov 23:30 local, unpriced door 18 Nov, 2.5 h addon 20 Nov); OWNER opened "Согласование заводом", pressed "Ввести в действие": date prefilled 10.11.2026, send disabled until consent (checked by script), activation 200; block "Действует" shows "Условия v1 / Коммерческий прайс v1 · Запланировано · с 2026-11-10 без даты окончания"; the button disappeared and the decision row shows it is in effect | seen live | browser pane |
| Live "Периоды": 1 signed journal, 2 rated lines, 1 without rate, 550,50 ILS excl. VAT (400,50 + 2,5 × 60,00); lines show "SYN-201 Полный монтаж 400,50", "SYN-203 … нет ставки на эту работу", "Acceptance adjustment 2.50 hour 150,00"; the 9 Nov door is outside the period | seen live | browser pane |
| Live through the gateway: OPERATIONS and INSTALLER 403, foreign tenant 404, anonymous 401 on agreements and periods; estimate detail reasons `NO_RATE, RATED, RATED`, amount 550.50; second activation of the same decision 409 | seen live | `scratchpad/activation-live.py verify` PASS |
| RU at 390 px: no horizontal scroll; HE at 768 px: `dir=rtl`, Periods tab present, no horizontal scroll | seen live | browser pane |

A copy nit found live ("Ни одна пара пока не введена" shown next to a scheduled pair; "Действует"
label on a scheduled decision) was fixed after the run; the fix is covered by the admin unit tests and
lint, the production build was not repeated for it.

## 3. Logic preserved

Factory supplies prices; installers never see or set commercial rates; the server computes sums;
factory confirmation ≠ activation ≠ claim ≠ payment; recorded earnings untouched; demo contracts never
enter real accounting; no default price; history immutable, changes only as new versions and new
agreements; VAT not computed without the accountant's parameters.

## 4. Open before the next steps

- Enable `COMMERCIAL_ACTIVATION_ENABLED` on a real server only after the real contract, terms and
  price exist and the factory has confirmed them.
- Project-to-contract link (needed before two factories can be in effect at once).
- Stage facts (spec step 3) before stage-based contracts get an estimate.
- Claims (step 6) turn the estimate into a claim with reservation and double-claim protection.
- Declared runtimes (Node 20, Python 3.11) gate, as before.
