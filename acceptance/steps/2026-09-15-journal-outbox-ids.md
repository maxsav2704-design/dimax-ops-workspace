# Journal manual-send outbox IDs

## Scope and implementation

Follow-up to `2026-09-15-journal-links.md`. The manual send service read ORM
message IDs before insert-time UUID defaults had run. Persisted queue rows had
valid IDs, but the response and `JOURNAL_SEND_REQUESTED` audit contained the
string `None`, preventing reliable correlation.

Backend commit `ff723dd` allocates a UUID when constructing each email/WhatsApp
message. This is a two-line runtime change in
`app/modules/journal/application/send_service.py`. It adds no flush or commit,
changes no repository behavior, and retains the router/UoW transaction boundary.
The response remains string-or-null, as expected by the existing admin client.
Unselected channels return JSON null; intentional resends get distinct IDs.
No migration or frontend/mobile source change is required. Existing queue rows
and historical audit records are not rewritten or guessed from timestamps.

## Verification

- New integration coverage checks email-only, WhatsApp-only and both channels,
  with two sends per case: response UUIDs resolve to the exact tenant/journal/
  channel rows, match send audit data and delivery statuses, and do not collide
  with each other or previous sends. No unexplained extra queue row is allowed.
- Three rollback cases cover a missing WhatsApp recipient, failure after a
  file token is created/flushed, and failure after the send audit is flushed.
  Queue entries, token/file records, delivery statuses and send audits roll
  back together. Tests use the existing API fixtures and real PostgreSQL UoW.
- The opt-in Mailpit test now resolves the returned ID to the SENT email row,
  then verifies the actual invitation/PDF and subsequent signed-PDF delivery.
  SMTP and MinIO are real local services; WhatsApp provider calls remain mocked.
- Initial pre-fix one-case run reached the 300-second process timeout without a
  pytest report: Docker exit 124, OOM false. This is NOT a reproduced failing
  assertion and is not counted as a completed test. Code inspection and the
  prior checkpoint established the original defect.
- Final selected regression: **49 PASS**, pytest 159.50 seconds, exit 0. Container
  state confirms `exited / exit=0 / oom=false`. Container wall time was about
  413 seconds including slow pre-session startup. No performance certification.
- Coverage: 1 transaction-boundary guard, 13 signing-link cases, 11 snapshot
  cases, 16 delivery cases, 7 journal API cases and 1 live Mailpit case. This is
  a focused regression, not the complete backend/admin/mobile release suite.
- Both database URLs explicitly target `db/dimax_acceptance_tests`; the Mailpit
  guard verifies isolated services before writes. Fixture cleanup reports zero
  remaining test projects/companies in the run window. Mailpit total is zero.
- The two owned one-off containers were removed by exact name. No dependency
  installation, host PDF/image export or build artifact was created. The tests
  remove only their own MinIO objects and mailbox messages; no global cleanup.
- `git diff --check` passes. The existing admin client accepts `string | null`
  IDs; its preexisting `next-env.d.ts` and `tsconfig.json` changes are untouched.

## Reproduction

From the workspace root, with the migrated isolated test DB and acceptance
services running (remove only this owned container after inspecting its result):

```powershell
docker compose -f docker-compose.acceptance.yml run --no-deps -T --name dimax-journal-ids-check -e PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 -e PYTHONDONTWRITEBYTECODE=1 -e PYTHONUNBUFFERED=1 -e DIMAX_JOURNAL_MAILPIT=1 -e DATABASE_URL=postgresql+psycopg2://postgres:postgres@db:5432/dimax_acceptance_tests -e TEST_DATABASE_URL=postgresql+psycopg2://postgres:postgres@db:5432/dimax_acceptance_tests api timeout --kill-after=10s 900s python -m pytest -vv -p no:cacheprovider -o faulthandler_timeout=120 tests/architecture/test_transaction_boundary.py tests/architecture/test_journal_signing_links.py tests/architecture/test_journal_snapshot_contract.py tests/integration/test_journal_delivery_api.py tests/integration/test_journal_api.py tests/integration/test_journal_mailpit_acceptance.py --tb=short
```

## Runtime and boundaries

Only the acceptance API was restarted. The bounded readiness wait reached HTTP
200 on attempt 13. A fresh request returns `status=ok / database=ready`; Docker
reports `running / healthy / oom=false`. The existing admin journal URL answers
HTTP 200 with HTML. This is route availability, not a new visual/button test.
Backend working tree is clean after the local commit.

Acceptance business data, phone queues, assignments, payroll and live signatures
were not modified. The supplied personal email/WhatsApp contacts were not put in
source, fixtures or logs and received no messages. Local Mailpit is not proof of
external inbox/WhatsApp delivery. Database rollback does not roll back object-store
writes; this step does not introduce distributed transactions or unsigned-file
versioning. Existing signed archive protection and signing-link rules are intact.

Local Git only; no public GitHub push or remote backup is claimed. Frozen release
criteria and readiness percentages are unchanged. Full release remains NO GO.
Next bounded work: RU/EN/HE PDF localization and long-document pagination, then
the outstanding real-browser/native and external delivery acceptance gates.
