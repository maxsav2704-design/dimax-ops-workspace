# Installer sync to signed journal delivery

## Scope and isolation

Continue the mobile journal workflow with a reproducible server-side acceptance
scenario. Do not substitute a browser fixture preview for a connected mobile
client. No real work, customer signature, recipient or assignment is modified.

- Separate Compose project: `dimax_acceptance`.
- Both database URLs explicitly target `dimax_acceptance_tests`, not the UI
  demo database `dimax_acceptance` or the working database.
- Database revision read before execution: `0061_journal_pdf_locale`.
- Only acceptance `db`, `minio` and `mailpit` were started. Existing working
  Compose services were left running and unchanged.
- Test email uses local Mailpit on the internal network, with no external relay.
  WhatsApp is disabled. Test signers are explicitly labelled synthetic QA.
- One bounded, disposable test container at a time. No APK/build/download,
  persistent PDF export or screenshot directory is created.

## Change

Backend `tests/integration/test_journal_mailpit_acceptance.py` now includes
`test_synced_installer_work_is_signed_and_delivered_without_duplicates`.
It uses the real application, JWT login, permissions and production Unit of Work,
with no authentication/dependency overrides. Only worker database selection and
company filtering are scoped to the fixture. MinIO and SMTP are real local
services, not mocks.

The existing admin-originated invitation/signing test is retained. The two tests
share the scoped worker/storage setup and exact artifact cleanup; cleanup now
also asserts that the fixture's object prefix is empty. The whole mailbox and
bucket are never cleared.

The new scenario checks:

1. Admin sets the installer rate to 250 ILS, independently of the 400 ILS door
   price. Installer and admin authenticate through the real login endpoint.
2. A NOT_INSTALLED door progresses through IN_PROGRESS to INSTALLED using the
   mobile sync batch API. Each durable item is submitted twice to simulate a
   lost response, while preserving its event ID and completion timestamp.
3. Exactly one 250 ILS ledger entry exists. Installer summary and admin ledger
   agree on the work and amount. Pending and other-installer doors are untouched.
4. Preparing twice reuses the draft. Only the installer's completed door enters
   the installer, administrator and public-signing snapshots. Pending and other
   completed doors are excluded.
5. Anonymous access is rejected, another installer cannot read/share the act,
   and the installer cannot enter the admin API. An unsigned PDF cannot be shared.
6. Mark-ready creates the human signing URL and locks the snapshot, but does not
   create an email. The synthetic public signature creates one signature and
   one pending signed-document message; a repeat signature is rejected.
7. The signed PDF contains the correct work and synthetic signer, with no other
   door labels. The installer's temporary download and administrator PDF are
   byte-identical.
8. The scoped worker processes one message and then zero. Installer and admin
   both report ARCHIVED / DELIVERED. Mailpit contains one matching message to the
   developer with the administrator in Cc and the exact signed PDF attached.
9. Signing and delivery do not add another payroll entry or outbox message.

No production API, business rule, schema or migration was changed. No confirmed
production defect was found by the focused scenario; this step closes a test
coverage gap rather than inventing a code repair.

## Verification

- Existing Mailpit baseline before edits: **1 passed**, 11.44 seconds.
- Both real-service scenarios after edits: **2 passed**, 34.02 seconds.
- Broader journal / PDF / sync / auth / earnings regression: **140 passed**,
  183.89 seconds, exit 0. This includes the two real-service tests above; the
  counts must not be added together as distinct tests.
- Regression files: the three journal integration modules, sync batch, auth,
  earnings corrections, plus the seven journal architecture modules for
  snapshot contracts, signing links, PDF layout/integrity/freshness, filter
  contracts and email smoke guards.
- Both fixture mailbox cleanup and empty object-prefix assertions passed.
  Post-run SQL found zero `QA SYNC JOURNAL` / `QA MAILPIT` projects. Eight older
  companies remain; the newest was created on 2026-09-14. None were deleted.
- All three acceptance dependencies are stopped, with volumes preserved. No
  disposable test container remains. The four previously running working
  containers (API, PostgreSQL, MinIO, Mailpit) are still running.
- Backend local commit: `9b236ac`. Backend/root diff checks passed. Mobile has
  no working-tree changes; preexisting admin `next-env.d.ts` and `tsconfig.json`
  changes were not touched or included.

Focused reproduction from the workspace root (after starting only the three
acceptance dependencies and verifying the separate test database revision):

```powershell
docker compose -f docker-compose.acceptance.yml run --rm --no-deps -T `
  -e PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 -e PYTHONDONTWRITEBYTECODE=1 `
  -e DIMAX_JOURNAL_MAILPIT=1 `
  -e DATABASE_URL=postgresql+psycopg2://postgres:postgres@db:5432/dimax_acceptance_tests `
  -e TEST_DATABASE_URL=postgresql+psycopg2://postgres:postgres@db:5432/dimax_acceptance_tests `
  api timeout --kill-after=10s 240s python -m pytest -q -p no:cacheprovider `
  tests/integration/test_journal_mailpit_acceptance.py --tb=short
```

## Boundaries and next acceptance

- No phone UI, SQLite outbox, network interruption or native browser return was
  exercised. API retries reproduce the server side of an offline retry only.
- No admin/browser build or mobile quality gate was rerun in this backend-only
  step. Their earlier results are not counted as new evidence.
- No real provider delivery, TLS, spam/inbox placement, bounce or WhatsApp check
  is implied by local Mailpit. SMTP ambiguity does not have an exactly-once
  guarantee; this test covers normal completion and explicit request retries.
- No new visual PDF certification is claimed; PDF text and byte identity are
  checked here. Existing locale/layout evidence remains separate.
- Next: verify the actual mobile client's return from signing refreshes the
  archive and delivery state, including offline recovery without false success.
- Frozen release criteria and readiness percentages are unchanged. Full release
  remains NO GO. Local Git only; no public GitHub push or remote backup claimed.
