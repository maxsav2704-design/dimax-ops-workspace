# Factory Mailbox Verification

## Scope And Business Boundary

Close link-only authorization of new factory price decisions. The factory still
confirms an immutable company-wide version; confirmation does not activate it,
change assignments or recalculate earnings. No mobile code or real factory
decision is included. A mailbox code proves access to the named email account,
not legal identity, factory authority or a certified signature.

## Implementation

- Public `request-code` sends only to the invitation's recorded recipient via
  the existing email outbox. It returns QUEUED and expiry/resend timestamps,
  never the code or recipient address. Opening a link does not send or approve.
- `confirm` requires a six-digit mailbox code as well as the exact version,
  snapshot, signer name and explicit consent. Missing or invalid codes return
  403. Deploy API, worker and public page together; there is no legacy bypass.
- Database counters and the existing company lock enforce a ten-minute maximum
  lifetime, sixty-second resend interval, ten requests and five wrong attempts
  per invitation. Resend invalidates the old code without resetting attempts.
  Failed attempts commit through the UOW before the router returns an error.
- Codes are keyed HMACs bound to company, invitation, recipient, snapshot and
  challenge. Outbox secrets are AES-GCM sealed with a distinct message kind.
  Workers reject stale, revoked, expired, changed, cross-tenant and locked
  challenges. Generic previews and SMTP failure logs do not expose secrets.
- Verification evidence commits with the decision; exact accepted retries stay
  repeat-safe. Old decisions remain unverified rather than gaining invented
  evidence. Admin history distinguishes verified mailbox access from old rows.
- Migration 0069 adds bounded counters/challenge fields and verification time.
  It refuses rollback once challenges have been requested. Production env
  validation requires a valid independent FACTORY_APPROVAL_EMAIL_KEY.
- Public UI and admin labels support EN/RU/HE, including RTL, pending delivery,
  retry limits, invalid codes and uncertain confirmation outcomes. Mail text is
  still English. The browser keeps the code/token only in component memory.

## Verification

- First selected backend run: 128 PASS, 2 failures in existing historical-date
  fixtures. Those tests moved confirmation into the past without moving the
  new verification evidence; the new DB constraint correctly rejected them.
  Updated only fixture timestamps, not the constraint.
- Final selected backend run: 148 PASS in 713.97 seconds. Covers mailbox,
  invitations, actual Mailpit code/invitation delivery, existing confirmation,
  timeline/application checks and production-env contract. Tests ran solely in
  dimax_acceptance_tests; Mailpit tests removed only their own messages.
- Guarded fresh migration smoke: empty database through 0068, legacy signed row,
  upgrade 0069, metadata agreement, downgrade/re-upgrade before challenges and
  refusal to discard used history. Original rows unchanged, no fabricated
  verification. Created and removed only dimax_factory_mailbox_migrations_20261010.
- Final UI regression: 47 PASS across public approval, price administration and
  helpers. Changed-file ESLint and normal Git whitespace checks passed.
- Production Next.js 16.2.11 webpack build passed, including TypeScript and 27
  routes. Build is the current working tree, including pre-existing AI files;
  this is not an AI release audit. Generated config edits were restored to the
  user's pre-existing next-env/tsconfig state.
- Playwright: 3 PASS on EN desktop 1280px, RU 360px and HE/RTL 360px. Checks code
  request, consent, exact version/code submission and absence of horizontal
  overflow. Screenshots inspected. Browser API responses were mocked, so this
  is not real external SMTP or authenticated admin activation acceptance.

## Runtime And Preservation

- Saved an acceptance database backup before upgrading at
  artifacts/factory-mailbox-20261010/before.dump (ignored, not published).
- Applied 0069 to the local acceptance database and restarted its API. Ready
  reports database ready; OpenAPI exposes request-code and verification_code.
- Earnings before and after: 11 rows, 1513.50 ILS, identical JSON aggregate
  digest d972af6ed54536ef21a9d1abc9f1ec2c (ordered by id). No repricing.
- New standalone preview: http://127.0.0.1:4189, PID 8720 when started. Kept the
  previous 4173 preview as rollback. Acceptance invitation URL now targets 4189;
  CORS allows both local previews. Verified actual preflight for the new origin.
- No runtime mailbox key or persistent outbox worker was provisioned. Tests
  injected only a test key. Live code delivery intentionally fails closed until
  API/worker share a configured key and the worker is enabled. No external mail,
  WhatsApp delivery, production price activation or credential reset occurred.
- Removed only this build's cache after path and reparse-point checks:
  274549699 bytes. Retained runtime, screenshots, rollback build and DB backup.

## Local Git Checkpoints

- Backend prerequisite f310c83 records the pre-existing 0068 AI schema migration
  unchanged, after fresh-chain validation, so 0069 has a tracked predecessor.
  It does not approve or commit the remaining AI implementation.
- Backend e4b6618: mailbox verification, migration, worker, tests and docs.
- Admin db5303b: mailbox confirmation UI/history and regression tests.
- Remaining pre-existing AI/config changes were preserved and excluded.
- No GitHub push under the existing publication restriction.

## Next Release Gates

1. Provision the shared key and supervised outbox worker in the target staging
   environment; accept real HTTPS/SMTP delivery with a verified factory contact.
2. Complete reviewed price activation API/UI and authenticated end-to-end
   acceptance, including disposition of historical decisions without mailbox
   evidence. Do not silently backfill or reprice them.
3. Complete phone offline/price-change/earnings acceptance, journal/PDF external
   delivery, final report export checks and production backup/restore/pilot gates.
