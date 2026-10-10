# Factory Invitation Email

## Scope

Optional email delivery of a factory price-confirmation link through the existing
outbox, with explicit admin choice. The manual-copy workflow remains available.
No real recipient mail, factory-price activation, earning change, mobile change
or schema migration is included. Unrelated AI work is preserved and excluded
from this block's commits.

## Implementation

- Add `send_email` (strict boolean, default false) and optional `email_outbox_id`
  to the existing invitation request/response. Creation, rotation and enqueue
  share the existing unit-of-work transaction; queue failure rolls them back.
- Require email enabled, a public HTTPS app base and an independent configured
  32-byte key. Validate before rotating an existing invitation.
- Store only an AES-GCM sealed link in outbox, bound to company/invitation
  identity. Pin the already-installed PyCryptodome dependency directly. Keep
  bearer links out of generic previews and provider-error logs.
- Reuse invitation validity/snapshot checks at send time, including actual
  tenant/recipient identity and pending decision. Keep stale or tampered emails
  as terminal failures; use existing bounded retries for SMTP failures.
- Keep journal correlation empty for price invitations. The existing journal
  email/WhatsApp branches are unchanged. SMTP supports optional multipart HTML
  plus plain text without changing existing attachment calls.
- The letter has a review button, version, factory/contact, agreement and expiry.
  It is currently English; the public review page remains EN/RU/HE. Opening mail
  or its link does not confirm a version. Confirmation does not activate it.
- Admin opt-in and queue/error messages support EN/RU/HE. A queued response is
  not labelled delivered. The existing Operations queue provides delivery/retry
  visibility. Lost-response handling does not silently reissue invitations.

Operational prerequisites, key rotation and recovery are documented in
`backend/FACTORY_APPROVAL_EMAIL.md`. SMTP is at-least-once: a crash after provider
acceptance but before database commit can duplicate mail, not price decisions.

## Verification

- Initial backend run: 39 PASS, 1 fixture failure. EmailStr correctly rejected
  the test recipient's reserved `.test` domain before SMTP. Changed only that
  fixture to `example.com`; SMTP remained confined to Mailpit.
- Expanded regression: 66 PASS, 3 existing outbox tests failed because acceptance
  disables WhatsApp. Factory invitation, real Mailpit multipart and journal
  delivery cases passed. No production guard was weakened.
- Final backend run: 27 PASS in 63.89 seconds. Includes three additional malformed
  or local URL cases and the existing outbox suite with its required WhatsApp
  flag enabled only in the one-shot test process. No real WhatsApp sender ran.
- In total the selected suites cover 72 distinct backend cases, including price
  confirmation, queue rollback, invalid/stale links, SMTP retries/redaction,
  journal delivery and outbox access. Financial fixtures use only
  `dimax_acceptance_tests`. Mailpit checks remove only their own test messages.
- UI: 42 PASS in 105 seconds across price administration, public approval and
  price helpers. Changed-file ESLint and whitespace checks passed.
- Next.js 16.2.11 webpack production build passed: compilation 100 seconds,
  TypeScript 114 seconds, all 27 pages generated. The build reflects the current
  working tree, including pre-existing AI work; this is not an AI release audit.
  Build: `.next-acceptance/factory-email-20261010`.
- Restored acceptance API and verified `/ready` (database ready) and live OpenAPI:
  email remains opt-in and the response has its queue reference. No persistent
  outbox worker, production key or external SMTP configuration was enabled.
- Replaced only the verified prior preview PID 3164. New preview is at
  `http://127.0.0.1:4173`, PID 8352 when checked. Login, price lists, public
  approval and all four root-main JS assets returned nonempty HTTP 200 responses;
  runtime stderr was empty.
- Browser navigation correctly reached login with `next=/price-lists` and
  `auth_required`. No authentication bypass/reset was performed. The new admin
  dialog still needs authenticated browser acceptance; component tests are not
  a substitute for that gate.
- Removed only the new build's cache after exact-path/reparse-point checks:
  274207275 bytes. Runtime and previous rollback builds remain. Restored only
  auto-generated include changes; original user configurations remain untouched.
- Main acceptance earnings still match the prior checkpoint: 11 rows, 1513.50
  ILS, digest `873b5115c8e2e320f325b1b8ff7ad96e`. The existing database reports
  `0068_ai_memory`; this block did not apply that unrelated migration.

Local implementation checkpoints: backend `0273355`, admin `1389a4b`.

## Remaining Release Gates

1. Public HTTPS deployment and real SMTP/sender-domain acceptance.
2. Mailbox OTP or equivalent representative identity verification: possession
   of the bearer link still permits confirmation; sending mail does not prove
   who opened it. Do not describe this as verified identity or a legal signature.
3. Authenticated browser acceptance and the separate price activation E2E gate.
4. Localized invitation letters if needed by the actual factory contacts.

Keep local Git checkpoints only under the existing publication restriction.
