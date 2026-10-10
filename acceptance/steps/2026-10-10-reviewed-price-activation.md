# Reviewed Company Price Activation

## Completed Scope

Connect the existing price-timeline service to an authenticated admin action.
Factory confirmation remains separate from activation; no real company was
activated as part of this checkpoint.

- Added POST /api/v1/admin/price-lists/{id}/activate. It delegates through the UOW
  to existing company locking, database permissions, idempotency, predecessor,
  version, price coverage, exact factory receipt and atomic audit checks.
- New transitions require mailbox verification. An old unverified decision
  needs a new version and genuine factory confirmation; it cannot gain invented
  evidence. Already effective historical decisions and quotes remain readable.
- Added EN/RU/HE activation dialog: current version, issues, explicit review,
  reason, server-recorded effective time and response-loss handling. Installer
  and FINANCE users do not get activation controls. No backdate or price input.
- Preserved execution-time prices, the first-confirmed-list legacy queue rule,
  immutable earned amounts, existing individual-rate write boundaries and sync.
- Corrected reconciliation text that incorrectly called every inspected version
  inactive. Updated old browser invitation scenarios for the mailbox-code flow.
- Added backend operator/API/recovery documentation. No new schema is required;
  current migration head remains 0069_factory_mailbox.

## Evidence

- New backend activation suite: 17 PASS in 43.59s.
- Extended backend regression: 147 PASS in 1121.99s. Files: activation API,
  timeline, application checks, earnings and price sync. Runs used only
  dimax_acceptance_tests, not the main acceptance database.
- Real JWT integration: admin login, factory decision with test mailbox code,
  initial activation, amendment, stale predecessor rejection, installer login,
  late offline door/add-on upload and repeat upload. Earned 250.00 and 13.50 ILS
  under the old confirmed execution-time rates, not the new 300/12 rates;
  duplicate submissions produced only two ledger entries.
- UI regression: 71 PASS across five files (activation dialog, price list,
  reconciliation, public confirmation and price helpers).
- Production Next.js webpack build: PASS, including TypeScript and 27 routes.
  Existing uncommitted AI work was part of the build but not audited or committed
  as part of this step. Build-generated config changes were restored to the
  pre-existing next-env/tsconfig state, not reverted to Git HEAD.
- Final Playwright: 9 PASS in 1.4m, on production preview. Includes activation
  EN 1280px, RU/HE 390px, consent and readback, approval EN/RU/HE and invitation
  administration/read-only finance. RU/HE activation screenshots were inspected.
  Browser APIs are mocked; this is not external delivery or physical-phone proof.
- Initial browser run: six passed, three failed because an exact text locator
  expected a fragment to be a separate element. Fixed the test locator; product
  controls and business assertions were not relaxed. Full nine-test rerun passed.
- Changed-file ESLint and Git whitespace checks passed.
- Alembic check: no new upgrade operations. No migration/data rewrite applied.

## Runtime And Preservation

- New preview: http://127.0.0.1:4190/price-lists, standalone PID 7276 at launch,
  build .next-acceptance/activation-20261010. Previous 4189 preview is retained.
- Acceptance API/public app URL/CORS now includes the new preview. Confirmed
  actual OpenAPI activation route, successful CORS preflight, /ready and login
  HTTP 200. The first OpenAPI request timed out while cold generation/tests were
  running; the later check passed. This is not a production load-test result.
- API recreation initially failed with Docker zombie-process error. The old
  container subsequently exited, and scoped Compose recreation succeeded.
  Added init:true for acceptance API/worker child-process reaping. API and DB
  are healthy. Other projects' containers, database volumes and files untouched.
- Main acceptance earnings unchanged before/after: 11 rows, 1513.50 ILS,
  JSON aggregate digest d972af6ed54536ef21a9d1abc9f1ec2c (ordered by id).
- Removed only this build's cache after absolute-path, ancestor and descendant
  reparse-point checks. Runtime, screenshots, rollback build and prior DB backup
  retained. No mobile source changes. Test container used --rm.
- No external email/WhatsApp, production price decision, user credential change
  or live earnings write. The runtime mailbox key and persistent delivery worker
  still require provisioning; they were not silently enabled here.

## Local Git Checkpoints

- Backend: 9c274c3, reviewed activation route, verification boundary, tests/docs.
- Admin: e0c7bbe, activation dialog/localization and regression/browser tests.
- Root checkpoint includes this record and acceptance runtime configuration.
- Unrelated existing AI/config changes were preserved outside these commits.
- No GitHub push under the existing publication restriction. Local Git commits
  are checkpoints, not an off-machine backup or a database backup.

## Remaining Release Gates

1. Provision the shared mailbox key and supervised outbox delivery in staging;
   verify HTTPS/SMTP delivery with the actual authorized factory contact.
2. Run authenticated browser acceptance with real staging email and a physical
   installer device through price change/offline restart/sync and earnings.
3. Complete journal/PDF external delivery and remaining report-export acceptance.
4. Finish exact-release backend/admin/mobile gates, production infrastructure,
   backup/restore drill and a controlled pilot before broader real-world use.

This completes this scoped activation implementation, not 100% product readiness.
