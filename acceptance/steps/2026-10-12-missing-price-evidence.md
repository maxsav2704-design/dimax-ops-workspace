# DIMAX missing factory price diagnosis

Retained offline work now identifies the verified factory list in which its rate
is missing. This is read-only preparation for separate factory approval, not that
approval workflow and not permission to accrue the work.

## Business decision

On October 12 the user explicitly authorized a separate factory confirmation for
a specific retained work with no applicable rate: administrator proposal,
OWNER-approved factory representative confirmation by personal link showing the
work and execution date, then authorized administrator accrual. The company-wide
price list and previously recorded earnings must remain unchanged. An installer
cannot propose or confirm the price.

## Implemented boundary

- The existing timeline remains the only source for choosing the applicable
  confirmed list. Receipt integrity is verified before reporting a missing rate.
- The review response gains nullable `missing_price`: confirmed list/version,
  approval, activation, target work type, execution date, selection basis and
  snapshot hash. It contains no invented rate, amount or price-list item.
- Ordinary execution-time and first-confirmed legacy selection remain distinct.
  For legacy work the first confirmation can differ from the first activation;
  the context preserves that distinction.
- Missing rate still means no quote, amount, review token or resolution authority.
  Later full lists and repeated queue uploads do not settle the original work.
- Invalid factory evidence remains a separate failure without missing-rate
  metadata. The public error envelope remains unchanged; a typed internal
  exception carries the context only into the authorized admin review response.
  The additive field is excluded from existing resolution token hashes
  to preserve the meaning of previously issued ordinary review tokens.
- The admin dialog in EN/RU/HE shows the applicable version and selection basis,
  including after execution-time correction. It keeps original identifiers and
  original device time separate. It explicitly says no invitation was sent and
  the separate approval workflow is not yet available here.
- No new migration, stored data, installer endpoint or mobile payload is needed
  for this read-only change. Existing earnings and queues are not rewritten.

## Verification

Local six-file Python AST validation and targeted frontend ESLint passed.
Local Vitest worker startup timed out before executing tests; this is not a test
pass. Admin CI succeeded on both source checkpoints: full lint, 517 Vitest tests
across 56 files, six production environment checks, one standalone-runtime check,
test-discovery validation, TypeScript and Next.js production build (26 pages).
All six Chromium cases passed: three missing-rate reviews and three existing
execution-time corrections, in EN/RU/HE at desktop/narrow widths. Screenshots were
inspected for readable fields, scrolling, lower actions and RTL; the new review
makes no write requests. This is synthetic browser acceptance, not a physical
phone or live integrated deployment.

The first backend run exposed a cyclic import in the new test module; the helper
import now occurs inside the relevant tests. The second passed the focused
financial suite and 1112 full integration cases (four skipped), but an existing
timeline test correctly rejected the extra error metadata. The public error
contract was restored instead of weakening that assertion. Timeline cases are
now included in the focused financial gate.

Final backend CI on `7d9aaa5`: success. Architecture/security: 176 passed;
focused financial/timeline regressions: 266 passed; complete integration:
1113 passed, four skipped, 312 warnings, 15 minutes 9 seconds. The 266 are part
of the 1113, not additional unique tests. API/error contracts, repository
boundary, fresh/populated migration checks and isolated restore smoke passed.
These ran on CI Python 3.12 with disposable PostgreSQL. The four skips and
synthetic browser tests do not prove real mail/storage or device readiness;
the isolated restore smoke does not close the unsafe shared-target restore risk.

Backend adds ten PostgreSQL integration cases across both queues and work kinds:
first-confirmed and execution-time missing rates, later-list/retry resistance,
resolve bypass rejection, original-command retention and corrupt factory
evidence. The existing corrected-time missing-price test now checks list identity.
Admin adds seven unit tests and three synthetic browser cases at 1280/390 CSS
pixels in EN/RU/HE. Existing correction browser cases also run in the same gate.

## Source checkpoints

Branch in backend and admin: `codex/missing-factory-price-evidence-20261012`.
Backend: `7d9aaa5e26650ac45d2124e04aecbf72ca9e1f32` (after `bacb1f9` and `085bbbf`).
Admin: `34002b84e564ccc200ccf9c22711577a69cdd1f4` (after `2d32269`).
Final backend CI: https://github.com/maxsav2704-design/dimax-ops-backend/actions/runs/38289547983
Final admin CI: https://github.com/maxsav2704-design/dimax-ops-frontend/actions/runs/38286680424

These are source backups, not merges or deployment. Foreign AI/demo/mobile work
is excluded. No factory invitation, email, WhatsApp message, real earning,
working database migration or phone installation was performed.
Remote readback matched the final backend/admin SHAs. The workspace protocol and
this report are backed up on the same branch in `dimax-ops-workspace`.
Both owned local screenshot bundles (827014 and 1127548 bytes) were removed after
visual inspection using resolved-path and reparse-point guards. No temporary
database, dump, image build or dependency download was created locally by this
step. CI screenshots expire after three days.

## Next complete workflow

1. Store an immutable, tenant-scoped proposal for the original retained command,
   verified execution date, installer, project, work/unit/quantity, applicable
   missing-rate context, proposed rate, reason and agreement reference. Recheck
   live administrator permissions and work eligibility; reject duplicates.
2. Issue a scoped, expiring personal link only to the current OWNER-approved
   factory contact. Show this specific work and total, not a general price list.
   Reuse existing mailbox verification, delivery outbox and token handling where
   they fit, without treating an ordinary list approval as this work's approval.
3. Record the exact factory-confirmed proposal snapshot. Changed contact, expired
   or replaced invitation, stale work and changed terms must not be silently
   accepted. Merely opening a link never confirms terms.
4. Revalidate factory authority, original command, execution evidence, assignment,
   door version and quantity under locks. Record work, immutable price evidence,
   decision, audit and mobile acknowledgement atomically and idempotently.
   Demonstrate denial cases and retries through API/admin/mobile acceptance.

Database immutability, safe business restore, coordinated rollout and real
device/mail/storage/HTTPS acceptance remain separate open release gates.
