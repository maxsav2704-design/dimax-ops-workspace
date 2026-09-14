# Journal invitations: human signing links

## Scope and implementation

Follow-up to `2026-09-15-journal-integrity.md`. The manual send service and
communication-template variables both pointed recipients at the JSON journal
API. They now use `PUBLIC_APP_BASE_URL/acceptance/{token}` through one helper.
Admin snapshots and installer journal details use the same eligibility rule.

A human signing link is emitted only for ACTIVE, unsigned journals with a token
whose expiry is strictly later than now. Legacy null expiry remains supported.
Draft, signed and expired documents remain sendable as PDF attachments without
an unusable signing link. Both ordinary email/WhatsApp bodies and fallback email
use this rule; template substitution and preview use it as well.

PDF/media download URLs still use the API origin. Existing API endpoints and
response fields are unchanged; manual-send `public_url` now intentionally means
the recipient-facing page. Mark-ready's legacy API `public_url` and its separate
`signing_url` are preserved. No migration, token renewal, new signature requirement
for door completion or change to work/payroll/access rules is introduced.

## Evidence

- First focused link/snapshot unit run: 24 PASS, 48.18 seconds, exit 0.
- Initial combined run: 45 PASS, 4 FAIL, 392.06 seconds, exit 1. Three new tests
  incorrectly accessed an email `subject` in a WhatsApp payload; they now check
  that channel's `fallback_subject`. An old settings test assumed enabled
  WhatsApp; its mocked test-only channel flags are now explicit. No runtime
  channel was enabled to make a test pass.
- The opt-in Mailpit flow in that run passed: manual invitation contains the
  same human signing URL as mark-ready and the correct unsigned PDF. After the
  test signature, the separate automatic email contains the unchanged signed
  archive and expected To/Cc recipients. This is real local SMTP/MinIO with an
  ephemeral company in `dimax_acceptance_tests`, not external email delivery.
- Frontend route probe `/acceptance/qa-route-check`: HTTP 200, content type
  `text/html; charset=utf-8`. The token is deliberately nonexistent; this only
  confirms routing, not a real customer signing session.
- Final complete repeat: 49 PASS, 265.65 seconds, process exit 0. Container
  inspection confirms `exited / exit=0 / oom=false`. This repeats all selected
  link/snapshot, journal API, delivery, settings and real Mailpit tests after the
  test corrections. The initial 24 tests are a subset, not additional coverage.
- Backend locally committed as `2ddb375`. The inspected one-off test container
  was removed by exact name; Mailpit reports zero messages after scoped cleanup.
  No PDFs/screenshots, dependency downloads or build caches were produced on
  disk in this step. The opt-in test cleaned only its company/journal objects.
- Only the acceptance API was restarted. Initial readiness requests timed out
  during slow startup; the bounded wait reached HTTP 200 on attempt 24. A fresh
  check returns `status=ok / database=ready`, and Docker reports
  `running / healthy / oom=false`. This is not a latency/performance certification.
- The existing admin journal was reloaded only after checking that Save was
  disabled (no unsaved edits). It retains the original DRAFT title, version 2,
  five installed rows, zero addons and unchanged QA notes. No live signing,
  submission, refresh-snapshot or send action was performed in Acceptance A.
- `git diff --check` passes. Backend source is clean after the local commit.
  Preexisting admin `next-env.d.ts` and `tsconfig.json` changes are untouched.

## Boundaries

No phone interaction or acceptance business-data mutation is performed. Existing
queued/sent messages are not rewritten, and old links cannot be recalled.
Links may still expire while queued or after delivery; no automatic extension
of signing authority is added. Production needs a publicly reachable HTTPS
`PUBLIC_APP_BASE_URL`; localhost/Mailpit are only an isolated test environment.

No PDF generator, frontend source or mobile source changes are required here.
Full backend/admin/mobile release gates, external inbox delivery, long multilingual
PDFs and physical-device acceptance remain separate work. No product-readiness
percentage or release GO is inferred from this fix. Local Git only under the
existing public-repository publication restriction; no GitHub backup is claimed.

The run also exposed a separate existing manual-send response defect:
`outbox_ids` contains the string `None` before ORM-generated IDs are flushed.
The queue rows do receive actual UUIDs and the tested deliveries work. Correct
response IDs/audit correlation in a separate focused step rather than coupling
that change to recipient URL behavior.
