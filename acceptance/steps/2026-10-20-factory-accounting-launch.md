# Factory accounting: launch and brand reference

Status: owner decisions recorded; accounting implementation not started by this step.

## Launch decision

- Start with a new accounting period; do not import detailed historical transactions.
- Work periods run from the 10th inclusive to the next month's 10th exclusive,
  using Asia/Jerusalem local dates. The exact first period is not selected yet.
- Carry opening debts, contractual retentions and advances with supporting evidence
  and OWNER approval.
- Separate retentions from ordinary opening debt to prevent double counting.
- Opening balances must not manufacture installation events, installer earnings,
  signed journals or new claims for historical work.
- Preserve existing operational history and installer earnings.
- Keep earlier unsubmitted work visible for reconciliation; do not automatically
  include it in new claims or assume that an opening debt covers it.

## Brand reference

- Owner supplied a DIMAX GROUP circular company mark for the letterhead.
- Original: acceptance/references/brand/dimax-company-mark-original.pdf
- SHA256: B64194877CD51F967FC43B1E9D92DF7E0D3580806B863EB367AE210A832000B6
- Preview: acceptance/references/brand/dimax-company-mark-preview.png
- Source filename: DIMAX_GROUP_макет_наклейка_50мм_4+0 (1).pdf
- First page visually inspected: black circular design, gold rings and monogram,
  white DIMAX GROUP lettering, Hebrew lettering and contact/registration details.
- Preserve the original proportions, artwork and lettering. Do not infer validated
  legal company particulars from artwork; structured issuer details need verification.
- Use as letterhead branding, not as a substitute for a person's signature,
  factory approval, journal acceptance or an issued accounting document.
- Primary export language: Hebrew. Russian is an additional copy of the same data.
- PDF was copied unchanged. No document templates or production configuration
  were changed in this step.

## Next design step

Define the opening balance register per factory, contract and currency:
ordinary debt, retentions and available advances; evidence, dates and allocation
restrictions; OWNER confirmation and a first-period reconciliation preview.
Choose the actual first accounting period before activation.

## Subsequent owner decisions

The first period is now selected: November 10, 2026 inclusive to December 10,
2026 exclusive, in Asia/Jerusalem. Reconcile opening debt, retentions and
advances with the factory before OWNER approval; unresolved amounts remain
separately disputed. The earlier "not selected" statement records the initial
discussion, not the current launch decision.

The consolidated rules, code mapping, open parameters and implementation gates
are in `DIMAX_FACTORY_ACCOUNTING_SPEC.md`. Invented commercial prices are
test-only and are not factory approval or opening balance evidence.
