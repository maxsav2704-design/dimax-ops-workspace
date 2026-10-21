# Commercial contract and price confirmation

Status: implemented, acceptance incomplete. Do not deploy or describe this block
as release-accepted until the remaining checks below pass.

## Business boundary

- An OWNER reviews one exact terms version and one exact commercial price version
  for the same contract. This is the factory-to-DIMAX price, not installer pay.
- Only the current OWNER-approved factory contact receives the invitation.
  The contract's informational contact does not confer confirmation authority.
- The representative reviews the frozen pair, requests a mailbox code and gives
  explicit consent. Opening the link is not confirmation. The administrator
  cannot supply a recipient override or obtain the secret through the admin API.
- New pending versions, contact changes, revocation and expiry invalidate pending
  invitations. A confirmed historical pair is not rewritten by later proposals.
- Confirmation records evidence only: no activation, journal signature, invoice,
  payment, installer rate update or earned-amount recalculation.
- Demo contracts remain fictitious and unusable for billing. Sending their
  invitations is restricted to APP_ENV=test; pages and email carry a test notice.

## Implementation

- Backend accounting module: approval DTOs, repository, service, encrypted outbox
  delivery and separate authenticated/public routers.
- Migration 0086_commercial_approvals: tenant/contract composite foreign keys,
  unique invitation requests and confirmed pairs, immutable decision history and
  invited price snapshots. Downgrade refuses to discard confirmation evidence.
- Audit constraint includes the external commercial factory decision, preserving
  the separate import-inbox rule being developed in parallel.
- Admin: third contract tab with review, explicit send consent, delivery state,
  cancellation reason, paginated history and exact-version detail.
- Public page: fragment token removed from the address, no auth cookies/JWT,
  mailbox code, explicit consent, stale/uncertain-response protection, EN/RU/HE.
- Acceptance harness: standalone Compose overlay, synthetic real-JWT fixture,
  locally captured email rendering and a Playwright end-to-end scenario. No real
  external SMTP, customer data or work-account passwords are required.

## Checks performed

- 47 UI tests passed across CommercialApprovalPage, ContractApprovalsPanel,
  ContractTerms and FactoryAccountingPage (separate completed runs).
- 4 repository UI ratchets passed: typography, RTL utilities, locale helpers and
  programmatic names of controls.
- Initial empty-database migration reached 0086. After fixing the audit check,
  an isolated 0086 -> 0085 -> 0086 cycle ran before the repeated tests.
- The final sequential backend run passed all 16 commercial-approval tests and
  all 30 contract-terms tests (46 individually completed cases). This includes
  the exact-pair flow, mailbox verification, concurrent idempotency, live scope
  revocation, forbidden tenants, atomic audit failure and immutable evidence.
- The combined selection collected 88 tests but did not finish: it reached the
  first of the remaining 42 commercial-draft cases before the bounded run ended.
  No pass is claimed for the complete 88-test command or the uncompleted cases.
- Earlier attempts stalled, including a 15-minute run from a temporary Linux
  source copy. The final run used timeout -k 15s 600s and pytest's 60-second
  traceback diagnostic, with no concurrent Node test/compiler process.
  Diagnostics showed slow fixture cleanup and FastAPI/Pydantic route-schema
  construction. No database lock wait was observed in the activity snapshots.
  These execution delays still need investigation; they are not proof that the
  application is performant. No production migration was invoked.
- Full TypeScript checking with a 640 MB heap exhausted that heap. A retry in a
  clean source snapshot without accumulated build outputs, with a 1024 MB heap,
  completed successfully (tsc --noEmit --incremental false -p tsconfig.json).
- Targeted ESLint passed for the changed approval components, public page, API
  schemas and tests in the clean snapshot. The earlier interrupted attempt is
  not counted as a pass. The browser harness passed node --check.
- Browser screenshots, real HTTP/JWT chain, production admin build and full
  backend regression are not accepted by this report.

The machine had 4 GB RAM, with approximately 167 MB free after pausing five
approved DIMAX workers. UI tests initially hit a worker-start timeout. Disabling
test-file isolation mixed mocks, so those results were discarded and the files
were rerun with isolation. No application behavior was weakened to pass a test.

Runtime caveat: the available backend image used Python 3.12.13 / pytest 9.1.1;
the host used Node 25.5.0, whereas the admin package declares Node 20.x. Repeat
release gates with the declared runtime versions before production acceptance.

Local code checkpoints: backend `8925375`, admin `db9cf4f`. These are not release
approval or a GitHub backup. The uncommitted predecessor 0083_import_inbox from
the parallel work must be reconciled before publishing/deploying the migration
chain. Its changes and its audit-model hunk were not included in these commits.

## Remaining acceptance

1. Run all 88 selected backend tests to completion, then the existing factory
   price/contact/work-price approval regression tests.
2. Complete an isolated production admin build.
3. Start the acceptance API/gateway and built admin on 8003/4194. Run
   commercial-approval-runtime.py prepare, then commercial-approval-browser.mjs.
   Verify the actual UI at desktop, RU 390 px and HE 768 px; inspect screenshots.
4. Verify receipt persistence across isolated API restart and downgrade rejection
   with a saved receipt. Check forbidden scopes, foreign tenant and nonzero
   installer-financial baseline using the harness's real JWTs.
5. Keep parallel import-inbox changes separate, including its shared audit-model
   hunk. Public GitHub publication requires the agreed approval; nothing was
   pushed by this verification step.
6. Real domain/HTTPS and external email delivery remain a separate deployment
   gate. Local mailbox capture is not proof of internet delivery or legal identity.

## Environment restoration

Only the five explicitly approved normal DIMAX workers were paused. All five
were restarted by their original saved container IDs and verified running with
restart count zero. The normal API, PostgreSQL and MinIO were not restarted:
their start timestamps remain 17:49-17:50 UTC. API and database are healthy;
the host request to http://127.0.0.1:8000/health returned {"status":"ok"}.

Compose down removed only the disposable acceptance database/container network;
the project-label query returned zero remaining containers. A second inspection
confirmed all five workers still running with restart count zero.

After validating the exact temporary path and removing its node_modules junction
non-recursively, cleanup removed 1,028 files / 12,527,171 bytes. Original admin
node_modules remained present. No working database, volume, installer account,
assignment or earnings was changed by this acceptance.
