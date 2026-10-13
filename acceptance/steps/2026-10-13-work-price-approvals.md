# Factory confirmation for one retained work

This block adds a separate factory invitation and mailbox-verified decision for
the immutable work-price proposals from October 12. It does not implement
earning accrual, work completion or mobile queue acknowledgement. An installer
still cannot set a price. The company-wide list and existing earnings remain
unchanged.

## Business and security boundary

- Only live OWNER or rate-authorized OPERATIONS users can issue, inspect or
  revoke these invitations. The recipient comes from the current OWNER-approved
  factory contact. A client-supplied recipient, rate or total is not accepted.
- The server rechecks the original retained command, latest proposal, assignment,
  execution context, catalog, quantity and work state under the existing company
  and work locks. The invitation includes the immutable proposal snapshot and a
  separate work reference. A changed contact, newer proposal, changed door
  identity/version or assignment blocks pending confirmation and delivery.
- Issue requests are idempotent by company/request/actor/terms. A new invitation
  replaces the previous pending link for that proposal. Invitation, sealed email
  outbox record and audit commit together; failure preserves the previous link.
- The admin receives invitation metadata and its outbox ID, never the secret
  link or verification code. The existing email configuration must be enabled,
  with a valid encryption key and public HTTPS application address. Queued mail
  is not represented as delivered mail.
- The factory opens `/work-price-approval#<secret>`. The browser removes the
  fragment from the address bar, uses POST/no-store/no-referrer and omits admin
  credentials. No secret is stored in browser storage. Opening the link neither
  sends a code nor records consent.
- The public page shows the project, installer, work/reference, execution date,
  quantity/unit, rate, total, proposal version and agreement reference. Internal
  execution evidence and raw offline payload are not exposed publicly.
- Explicit consent, signer name, exact displayed version/hash and a six-digit
  mailbox code are required. Existing ten-minute lifetime, sixty-second resend,
  ten-request/five-wrong-attempt limits are reused with a separate HMAC purpose.
  Code delivery has no invitation link. Changed/revoked/expired messages are
  checked again by the worker; SMTP failures are redacted.
- Confirmation, mailbox evidence and external-actor audit are atomic. Exact
  retries do not create another decision. Database triggers protect invitation
  terms, prevent lowering counters and prevent editing/deleting final decisions.
  Email access demonstrates mailbox control, not independently verified legal
  identity or factory authority; OWNER must establish that authority.

## Architecture and interfaces

- Migration `0073_work_price_approvals`, after `0072_work_price_proposals`, adds a
  separate table, tenant-scoped proposal/contact foreign keys, uniqueness/state
  constraints and an immutable-history trigger. Audit permits only the specific
  external factory confirmation event. Nonempty history blocks downgrade.
- Additive admin endpoints:
  `GET/POST /api/v1/admin/sync/work-price-proposals/{id}/invitations` and
  `POST /api/v1/admin/sync/work-price-proposals/{id}/invitations/{invitation}/revoke`.
- Additive public endpoints:
  `POST /api/v1/public/price-approvals/work/preview`, `/request-code`, `/confirm`.
  Existing company-price-list endpoints remain unchanged. Their token lookup
  and the new work lookup are separate.
- Reuses the existing UOW, contact authority, price proposal eligibility, mailbox
  limits, rate limiter, email transport and outbox worker. New message kinds and
  authenticated encryption context distinguish work links/codes from list links.
- EN/RU/HE admin actions display the approved recipient, lifetime, explicit send,
  revoke reason and decision status. Ambiguous send retries preserve the request
  ID. The public page reuses the tested confirmation UI with work-specific terms,
  identity and consent, including RTL. It refuses incomplete work identity.

## Verification

Frontend CI passed all 550 Vitest tests across 59 files, ESLint, production-env
and standalone checks, TypeScript and the production build (27 generated pages).
All 12 Chromium scenarios passed: existing execution-time correction, proposal
preparation plus invite/revoke, original company-price-list confirmation and the
new one-work confirmation, each in EN/RU/HE. The six new invitation/public-page
screenshots were visually inspected at 1280 px EN and 390 px RU/HE: no horizontal
overflow or overlapping fields; long review dialogs scroll; RTL is preserved.
These browser scenarios mock API responses. Real persistence/authorization and
worker behavior are covered separately by PostgreSQL backend integration tests.
The downloaded screenshot ZIP matched its GitHub SHA-256 digest. After visual
inspection, removed only this step's owned temporary extraction: 28 files,
4,804,922 bytes. The running frontend's build cache and two small runtime logs
are intentionally retained, not source artifacts or release backups.

Final backend verification completed at 22:07 UTC on October 13 (October 14 in
Asia/Jerusalem) for `e225e123f8f7915709f3ec93167ea8c1fd9556e4`. All eight jobs,
including the required quality gate, succeeded. The focused financial suite
passed 365 tests; the full integration suite passed 1,198 tests with four skips.
These suites overlap and are not additive. Upgrade/downgrade/upgrade, historical
migration guards, isolated backup/restore, API, error, architecture and repository
contracts passed as well. The four opt-in delivery/storage skips are not passes
and do not close external deployment acceptance. PyJWT still reports existing
short-key warnings for test fixtures; this is not validation of production keys.

An earlier backend run passed all 345 focused financial tests, but GitHub
cancelled the full integration step at the job's 30-minute limit after 90% of
the tests, without reported assertion failures. That interrupted run is not a
pass. Increased only the integration job budget to 45 minutes; both test suites,
isolated database, teardown and required quality gate remain unchanged.

The subsequent, initially failing complete run passed 1,190 integration tests,
with four opt-in skips, but exposed two pre-existing wall-clock-dependent
correction-summary tests after
Jerusalem midnight. They passed the UTC calendar date to an API whose day is
explicitly Asia/Jerusalem. The production period calculation was correct and is
unchanged. Replaced those two current-time scenarios with eight explicit door
and add-on cases, immediately before/at local midnight in winter and summer.
Assertions check the corrected amount, original execution timestamp, correct
business-day key and empty adjacent days. The correction suite now runs first
in the focused financial gate as well as in the complete suite. Cross-checked
the four timestamp/date pairs using Windows' Israel time zone. The standalone
local Python lacks tzdata, so that initial ZoneInfo cross-check could not run;
the canonical Python/PostgreSQL runtime validation remains the Linux CI suite.

Local scoped ESLint and Python AST checks passed. Local Vitest passed 16 tests
for the two proposal/invitation forms, but the public-page worker timed out at
startup. This local run is not counted as a full pass. The first backend CI run
passed 32 new tests but failed during cleanup of the foreign-tenant test: ORM
deletion needed an explicit user flush before deleting the company. Fixed only
the isolated fixture ordering; no authorization or foreign-key guard was relaxed.

## Source and runtime

Backup branch: `codex/work-price-approvals-20261013`.

- Backend initial implementation: `3958a35e66050679f1d3d44072b2d4c0dbf14c6a`.
- Backend fixture fix: `dd0e0ce3785571daa683e878af6eb6cd5ae9ca50`.
- Backend CI time budget: `9667f3e365ab9dc0816fea5b0b5b3888ce29c563`.
- Backend deterministic business-day tests: `e225e123f8f7915709f3ec93167ea8c1fd9556e4`.
- Frontend: `c5152b4f5e27f362bf260c2aa553809770c30d7d`.
- Backend verification:
  https://github.com/maxsav2704-design/dimax-ops-backend/actions/runs/38471479531
- Frontend verification:
  https://github.com/maxsav2704-design/dimax-ops-frontend/actions/runs/38463199059

No merges, production migration, real factory messages, phone changes, work
completion or earnings occurred. Unrelated AI/config/demo edits are preserved
and excluded from these commits. Docker's local Linux engine was unavailable;
database verification runs in disposable CI infrastructure, not the working DB.
Started a local frontend development server at http://127.0.0.1:4191 using the
existing `.next-dev` configuration. `/work-price-approval` compiled and returned
HTTP 200. Without a valid personal link it displays the unavailable-link state;
the new backend is not deployed locally. Next.js's generated next-env import was
restored to the pre-existing preview path; unrelated tsconfig edits are intact.

## Next release gates

1. Implement the separately authorized, idempotent admin accrual operation bound
   to this exact factory decision. Recheck latest proposal, work, assignment and
   execution evidence; atomically record earning/proof/audit/queue acknowledgement.
   Cover duplicate completion, reversals and financial reports.
2. Deploy API, migration, worker and frontend together in an isolated environment
   with a backup. Accept the complete retained mobile work to confirmed factory
   price to admin accrual chain; mocks are not deployment evidence.
3. Provision real HTTPS/SMTP and organizationally verify the factory contact.
   Complete actual external delivery, storage/PDF, phone and recovery acceptance.
   The isolated restore test does not close the shared-target restore safety risk.
