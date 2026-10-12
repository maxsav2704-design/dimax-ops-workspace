# DIMAX retained work execution time correction

This checkpoint adds an evidence-backed administrator decision for retained
offline work with missing or invalid execution time. It never edits the original
device command, assigns a caller-supplied price or recalculates an existing earning.
It is a source checkpoint, not deployment or production approval.

## Operator procedure

1. An OWNER or rate-authorized OPERATIONS administrator opens the price conflict
   from Operations. FINANCE can inspect ordinary price evidence but cannot
   preview a correction or accrue the work; installers have neither authority.
2. For missing, naive, future, pre-creation or historically unknown timezone
   evidence, enter the verified execution date/time, explicit UTC offset at that
   date and an independent evidence reference. Do not copy server receipt time
   or invent an execution time. The form starts empty.
3. Check the corrected date. The server returns a read-only calculation using
   the factory-confirmed timeline. This does not write a decision or earning.
4. Review installer, work, quantity, original device record, corrected date,
   factory version, rate and amount. Explain the decision and explicitly attest
   independent execution and assignment evidence before recording it.
5. A successful result records work, earning, immutable factory price evidence,
   decision, audit and mobile acknowledgement in one transaction. The updated
   mobile app receives the existing resolution acknowledgement on its next sync.

## Boundaries

- Correction is available only for an originally missing or invalid execution
  time. An already valid historical date cannot be edited to select another price.
- The corrected timestamp must have a timezone, cannot follow the original server
  receipt and cannot precede project/door creation. Current assignment remains
  mandatory; absent historical assignment evidence requires explicit attestation.
- The company-wide confirmed price is selected by the corrected execution time,
  not by upload time or a supplied amount. For eligible old versionless work,
  use the first factory-confirmed list, never a later substitute.
- Missing factory prices, invalid/unavailable cached versions, changed units,
  missing original door versions and other unresolved work conditions stay held.
- Correction metadata participates in the review token and retry fingerprint.
  Final resolution rechecks live authority, work/assignment/version/status,
  quantity, price evidence and the reviewed correction under existing locks.
- The immutable decision retains both the complete original command and the
  corrected time/reference. An audit failure rolls back the work and decision.
  A retry cannot create a second earning. Existing decisions and ordinary retry
  fingerprints remain compatible.
- The UI shows EN/RU/HE labels, separates preview from accrual, and clears the
  calculation/consent when correction inputs change. Narrow dialogs scroll;
  browser screenshots and interaction checks run in isolated CI.

An administrator's reference is an attestation, not cryptographic proof of
offline execution or factory authority. They must actually check the referenced
record. No required photo, signature or document-upload dependency is added.

## Implementation

- Backend `price_review_dto.py`: explicit timezone-aware correction DTO with a
  bounded evidence reference; arbitrary price fields are forbidden.
- Backend `price_review_service.py`: candidate analysis and a token including
  the correction without modifying queue data.
- Backend `price_resolution_service.py`: live authority, idempotency, locked
  revalidation, existing work handlers and immutable correction/audit snapshots.
- Backend `admin_sync.py`: additive read-only POST `execution-review` endpoint;
  existing `resolve` accepts optional correction metadata. No installer API changes.
- Backend `test_execution_time_correction.py`: 50 parameterized integration
  cases added to the focused financial gate and full integration discovery.
- Admin `PriceConflictReviewDialog.tsx`: explicit date/offset/reference preview
  followed by the existing authorized decision. No editable price or amount.
- Admin dialog tests and `e2e/execution-time-correction.spec.ts`: input/reset,
  permissions, failure states and multilingual browser acceptance.

No new migration is needed. Existing migration 0067 provides immutable JSONB
decision snapshots and tenant/command/work uniqueness; migration 0071 provides
original timezone and assignment evidence. Both remain required before rollout.

## Verification

- Local Python AST: five changed/new files passed; this is not a runtime test.
- Local dialog Vitest: **30 passed**. An initial sandbox worker startup timed
  out without executing tests; the subsequent single-worker run passed.
- Targeted ESLint and whitespace checks passed.
- Backend CI: **176 architecture/security tests**, **202 focused financial
  regressions**, **1103 integration tests passed, 4 skipped**, final quality gate
  successful on `c72bcb9`. The 202 are included in the 1103, not additional cases.
  Full integration took 19 minutes and reported 312 warnings; the four existing
  opt-in real mail/storage cases were not executed. CI runtime was Python 3.12.
- API/error contracts, fresh and populated migration checks and isolated restore
  smoke passed. This does not validate restoring a real/shared business database.
- Initial admin CI passed lint, **510 Vitest tests**, TypeScript and production
  build. All three browser cases exposed ambiguous label text around the UTC
  selector: Playwright's exact label lookup included its nested option text.
  The label is now a separate element linked with `htmlFor`, with an accessible
  name assertion added. The 30 local dialog tests and targeted lint passed again.
- Final admin rerun on `9652eb0`: **success**. Full lint, **510 Vitest tests**
  across 56 files, six production-env tests, one standalone-runtime test,
  test-discovery validation, TypeScript and Next.js production build passed
  (26 pages). The 30 dialog cases are included in the 510.
- Chromium browser acceptance: **3 passed** in EN/RU/HE at 1280/390 CSS pixels.
  Preview, explicit consent, single decision, success and dialog closure passed;
  no page errors or horizontal dialog overflow. All six resulting screenshots
  were inspected: fields, calculation, confirmation and action fit their layouts.
  These use synthetic API responses, not a live integrated deployment or phone.

Backend CI: https://github.com/maxsav2704-design/dimax-ops-backend/actions/runs/38273202785
Initial admin CI: https://github.com/maxsav2704-design/dimax-ops-frontend/actions/runs/38274803521
Admin rerun: https://github.com/maxsav2704-design/dimax-ops-frontend/actions/runs/38277107692

## Release and storage

No working database migrations, factory confirmations, real accruals, mail,
WhatsApp or phone installation were performed. Existing foreign AI/demo/mobile
changes were preserved and excluded from these commits. Tests use disposable CI
databases and synthetic browser API responses. No local image build, dependency
download, temporary database or dump was created. CI screenshot retention is
three days. Both owned local screenshot/context directories were removed after
inspection with absolute-path and reparse-point guards. No screenshot bundle,
database, dump or local build from this step remains.

Remaining separate steps: missing-price resolution with factory authority;
database financial immutability and legacy transition enforcement; safe business
backup/restore; coordinated deployment and real device/API/admin acceptance;
real mail/storage delivery and production HTTPS/SMTP. This does not close them.

## GitHub checkpoints

Backend `c72bcb9` and admin `e3da48d` / `9652eb0` were pushed to their existing origins on
`codex/execution-time-correction-20261012`, without merge, force push, PR or deploy.
The workspace report is backed up separately after final verification.
Backend remote readback matched `c72bcb986fc0c0576bf236ad40a76215ff274afe`.
Admin final source checkpoint is `9652eb0431e96877919a8a8b2b2d9ea655615f34`.
