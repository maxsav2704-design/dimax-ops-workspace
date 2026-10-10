# Factory Delivery Runtime, October 10, 2026

## Scope And Business Boundary

Continue reviewed price activation with protected shared mail configuration,
supervised delivery and process-level acceptance. The factory confirms a named
version using a mailbox code; the admin's later activation remains separate.
No installer price editing, automatic activation or historical earnings rewrite.
No real recipient, external SMTP/WhatsApp, production deployment or phone input.

## Implemented

- `scripts/prepare-acceptance-mail.ps1`: PowerShell 7 provisioning of one random
  key, current-user/SYSTEM access only, no secret output, reparse-path refusal,
  valid-key reuse and invalid-key refusal. Only the dedicated directory/file
  access list is updated, not parent ACLs, owners or system audit policy.
- `.gitignore` excludes `acceptance/.factory-mail/`. This is required runtime
  secret storage, not disposable cache. It must not be committed or silently
  rotated while encrypted outbox items/mailbox challenges exist.
- `docker-compose.acceptance.delivery.yml`: explicit opt-in readonly shared
  key bind, supervised worker, bounded logs and health probe. Base acceptance
  startup is still possible without provisioning delivery. Keep the overlay
  when recreating the mail-enabled local API/worker.
- Backend `outbox_health.py`: atomic timestamp/PID marker after a committed
  queue pass, CLI probe and invalid/stale/dead-process tests. Production compose
  also uses this probe. An unhealthy live container needs operator action;
  Docker restart policy alone only restarts exited processes. Healthy is not
  proof of SMTP delivery, receipt or factory confirmation.
- `scripts/factory-delivery.test.mjs` and backend driver: real HTTP login/API,
  separate API/worker processes, real SMTP to Mailpit, random mailbox code,
  worker-stop/API-restart/worker-restart with queued code, exact confirmation
  replay, no activation, no earnings and main-ledger invariance. Fresh migration
  chain and resource cleanup are part of the opt-in test.
- Backend outbox API tests now explicitly enable the two queue channels for
  their three enqueue-only cases; they no longer rely on host WhatsApp defaults.
  This does not enable external delivery or change runtime channel settings.

## Checks

- Shared-key Windows test: PASS (creation, same-key reuse, restricted file ACL,
  invalid-key refusal and rejection of a directory junction).
- Final backend regression: **89 PASS**, 279.16 seconds. Covers worker health,
  disposable-driver guards, production env validation, factory invitation/code
  delivery and outbox API/webhooks. Run against `dimax_acceptance_tests` with
  `DIMAX_FACTORY_MAILPIT=1`; no worker is launched against that test database.
- Final opt-in process-level scenario: **PASS**, 409.31 seconds, including
  invitation, code, API/worker restarts, confirmation/retry and cleanup. The
  complete migration chain succeeds on a new empty disposable database.
- The localhost stack remains at `0069_factory_mailbox`; no extra migration was
  needed for these runtime/probe/test changes.
- Production compose syntax: PASS using the example env and dummy release tag;
  no production services were started.
- Local API readiness, admin login and Mailpit info: HTTP 200. Main local API
  and outbox worker are healthy after enabling the delivery overlay.
- Existing acceptance queue was verified empty before enabling its worker.
  Main WhatsApp remains disabled; SMTP remains Mailpit-only on the internal
  Docker network. Public ports remain bound to loopback.
- Final cleanup: zero disposable factory-delivery databases, containers and
  captured factory-delivery messages. Main outbox still empty. No volume prune
  or deletion of other projects' files/containers/messages.
- Main earnings before/after: **11 rows, 1513.50 ILS**, ordered JSON digest
  `d972af6ed54536ef21a9d1abc9f1ec2c`. No factory decision/activation or business
  data was written to the main database by this test.
- API loads the shared 32-byte key; rerunning provisioning reports reused,
  rotated=false. Secret contents never appear in logs or commits.

Early test-harness failures were corrected, not hidden: Windows ACL assignment
was narrowed to access rules, APP_ENV is read from its actual environment
source, test-recipient cleanup was made independent of an API state file, and
Mailpit's successful plain-text DELETE response no longer requires JSON parsing.
The one interrupted-run invitation was removed by its exact message ID and
verified unique recipient. No mailbox-wide purge was used.

## Local Checkpoints

- Backend: `7749cf8`, worker supervision, real delivery driver, tests and runbook.
- Root commit records the opt-in compose overlay, Windows key preparation,
  disposable process test and this evidence file.
- Existing AI/admin/mobile changes were not staged into this block. Secret
  storage is excluded from Git, so a Git checkpoint does not back up that key.

## Remaining Release Gates

1. Real public HTTPS application/API, verified SMTP sender and the authorized
   factory contact. The reserved `factory.example.test` test name is not a
   deployed website; internal HTTP test calls do not prove public TLS/DNS.
2. Authenticated browser acceptance using actual staging mail, then physical
   installer-device price transition/offline restart/sync/earnings acceptance.
3. Journal/PDF external delivery and remaining report/export acceptance.
4. Exact-release backend/admin/mobile gates, backup/restore drill and a limited
   real-world pilot. Existing unrelated AI edits are outside this checkpoint.

This is a scoped local delivery block, not 100% production readiness. No frontend
or mobile source changes/build acceptance are claimed by this step. Local Git
checkpoints are not an off-machine backup; no GitHub push is performed under
the existing publication restriction.
