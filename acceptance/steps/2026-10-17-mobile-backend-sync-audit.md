# Mobile ↔ backend sync audit, 2026-10-17

Read-only pass over the installer app (`mobile/`, Expo 52 / React Native 0.76 /
TypeScript, branch `codex/release-hardening-20260908`, HEAD `d0aed71`) and the API
(`backend/`, FastAPI / SQLAlchemy 2 / PostgreSQL 16, same branch, HEAD `159564c`).
Nothing was changed. The other agent's uncommitted backend work (`app/modules/ai/`,
`routers.py`, `config.py`, `model_registry.py`, `.env.example`, two AI tests) is not
touched and excluded from the findings; the mobile tree is clean. Method: two read-only
sweeps (mobile, backend) whose high-severity claims were re-verified by hand in the
code; no servers, installs, migrations or real `.env` files. Same format and rules as
`2026-10-15-admin-audit.md`.

## Scale

- Mobile: 63 vitest files (SQLite mocked everywhere; no test runs real SQL), largest
  files `sync/service.ts` 1 515 lines (+ its test 1 730), `app/project/[id].tsx` 1 270,
  `components/mobile-ui.tsx` 1 120. Gate: `npm run quality-gate` (security patch checks,
  test discovery contract, android build contract, vitest, production config contract,
  `expo config`, `tsc`). No ESLint at all. CI runs the gate on PRs and the branch.
- Backend: 417 modules / 47.9 k lines, 801 tests (715 integration, 78 architecture),
  73 Alembic revisions (head `0074_work_price_accruals`). Gate: `workspace.cmd
  test-backend-gate` (Postgres needed). No ruff / mypy anywhere.
- Sync surface actually used by the app: `POST /api/v1/installer/sync` (v2 events +
  cursors, prices pushed as `factory_prices`), project detail, earnings summary,
  calendar, journal endpoints, auth. The queue-batch protocol
  (`/installer/sync-queue/batch`) and the online door endpoints are not called by the app.

## What is solid (keep)

- Mobile outbox: one SQLite DB per `company:user` with an owner key; events, optimistic
  rows and undo fields written in one transaction; door events deduped per door; sync
  serialized and coalesced; cold resync refuses to run with unsynced work; strict
  validation of `factory_prices` before anything is written; the installer never sends
  an amount (`capturePriceVersion` returns only `price_list_id`); earnings are
  server-authoritative. 49 + 16 + 9 sync tests cover replay, lost acks, assignment
  removal, reset, session isolation.
- Backend sync: `client_event_id` unique per company (`uq_sync_events_client_event`),
  savepoint per event, concurrent insert turned into a replay ack, payload whitelist,
  company row lock around financial writes, execution-time authority
  (`ExecutionAuthority.inspect`: timezone, received ≥ performed ≥ assignment start),
  price quoted from the activation effective at execution time, first-confirmed-list
  only for an explicit legacy queue, `factory_earning_prices` evidence row, reversals
  that must offset the original, DB triggers on proposals / approvals / accruals and on
  accrued `completed_work` rows. 25 + 26 + 12 + 7 + 7 sync tests, 7 + 9 + 10 + 10 on
  execution authority, corrections and price review; the factory link flow has
  `test_link_alone_never_confirms` and 60+ tests around it.
- Phase 1–3 audit (`backend/AUDIT_INSTALLER_APP_PHASE*.md`) blockers are closed: access
  token 15 min (`core/config.py:14`), `FORBIDDEN_SCOPE` exists
  (`shared/domain/errors.py:42`), login/refresh/public-file rate limits
  (`api/v1/rate_limit.py`), refresh hashes are sha256-prefixed by decision
  (`core/security/refresh_token_hash.py`).

## Findings by area (evidence)

### A. Mobile sync client

- **A1. One 4xx blocks the whole batch.** `executeSync` sends up to 500 events; a
  non-401, non-5xx HTTP error marks every sent event BLOCKED
  (`sync/service.ts:1283-1289`, `policy.ts:17-19` treats only 401 and ≥ 500 as
  retryable). The server validates each event with pydantic
  (`backend/.../sync/api/installer_schemas.py:14-26`), so one malformed event (or any
  422/409/429) blocks all queued work, and each item then needs a manual retry.
- **A2. Failure after a successful POST leaves work stuck.** `markEventsAttempted`
  increments `attempts` before the call (`:1245`); if `parseFactoryPrices`
  (`:1295`) or the change application throws afterwards, events stay PENDING without
  `next_retry_at`; after 8 attempts `getPendingEvents` (`:140`, `attempts < 8`) stops
  selecting them, so they neither send nor become BLOCKED. (The reset-without-snapshot
  path does schedule a retry, `:1297-1300`.)
- **A3. Queue items that can never be cleared.** Any BLOCKED event whose error text
  contains `auth` gets neither Retry nor Drop (`sync/presentation.ts:240-257`), also
  after the user signs in again; a 401 that exhausted 8 retries ends there with
  "(auto retry limit reached)". A BLOCKED door event also blocks any new status for
  that door (`service.ts:1380-1390`).
- **A4. Issue creation bypasses the workspace guard.** `app/issues.tsx:205` calls
  `queueIssueCreateEvent` directly; door and add-on actions go through
  `withWorkspaceDatabase` (`doors/actions.ts`). Screen reads in `app/projects.tsx:127,
  176, 188, 206` and `app/issues.tsx:123` also bypass it; they can interleave with a
  sync DB phase or an account switch.
- **A5. A corrupt price cache blocks saving work.** `readFactoryPrices` throws on bad
  JSON or shape (`prices/repository.ts:9`) and is called inside `queueDoorStatusEvent`
  (`:1369`) and `queueAddonFactEvent` (`:1437`), so the install cannot be queued at all
  instead of being queued without a `price_list_id` claim (which the server handles).
- **A6. Non-crypto event IDs.** `createClientEventId` is `Date.now()` + `Math.random`
  (`service.ts:57-59`); the device id has the same fallback (`device-id.ts:4-6`).
  Collisions across devices of one company would be treated as replays.
- **A7. E2E password can land in a bundle.** `E2E_LOGIN.password` is read from
  `EXPO_PUBLIC_E2E_PASSWORD` regardless of dev mode (`config.ts:24-28`); auto-login is
  dev-gated, the value is not. `scripts/validate-production-config.mjs` has no E2E check.
- **A8. Small ones.** `projectId` interpolated without `encodeURIComponent`
  (`projects/service.ts:26`, unlike the journal endpoints); raw server bodies stored
  and shown as the queue error (`api.ts:213`, `policy.ts:23`); several English-only
  thrown messages reach the UI (`service.ts:1194, 1361, 1364, 1389, 1425, 1432`);
  cold snapshot drops `whatsapp_url` / `call_url` until details are refreshed
  (`service.ts:900-924, 1143-1167`); README lists an unused bootstrap endpoint and
  omits `ISSUE_CREATE`; no ESLint.

### B. Backend sync service

- **B1. Unknown server errors become sticky conflicts.** `_sync_event_error_code`
  returns `str(exc)` for non-domain exceptions (`sync/application/service.py:105`),
  the catch-all at `:686` stores it as `apply_error`, and a replay of the same
  `client_event_id` returns the stored error without re-applying (`:152-158`). A
  transient failure (DB timeout, bug) therefore permanently blocks that offline
  completion and leaks the internal message to the device, where it may match the
  `auth` rule of A3. `mark_failed` failures are swallowed (`:701-705`).
- **B2. Legacy queue-batch protocol fails whole batches with 500.** `sync_batch`
  catches only domain errors (`:358-397`); `uuid.UUID(str(reason_id))` (`:1045`) or a
  bad `door_id` (`:970`) raises `ValueError`; `create_or_update_pending` keys by
  (company, id, user) while `id` is the global primary key, so an id reused by another
  user is an IntegrityError (`infrastructure/repositories.py:491-535`). The app does
  not use this protocol.
- **B3. Cursor visibility gap (risk, no test).** `cursor_id` comes from a global
  sequence (`0015`), changes are read with `cursor_id > since` and no horizon
  (`repositories.py:271-280`), and admin change-log writers do not take the company
  lock; a change committed after a higher cursor was served can be skipped.
  `since_cursor` above the server max is not detected (only `ack_cursor` is,
  `service.py:454`).
- **B4. Hot-path reads.** `_ensure_project_access` loads the full door list of the
  project for every event (`service.py:786-799`, up to 500 per request);
  `installer_add_fact` does the same (`addons/application/use_cases.py:407-413`); the
  cold snapshot runs one query per project for plans and issues (`:1151-1164,
  1188-1207`); `GET /installer/sync-queue` paginates in memory
  (`installer_sync.py:34-55`); `sync_events` and `sync_queue_items` are never pruned
  (GC only touches the change log).
- **B5. Two rule sets for door status.** v2 `DOOR_SET_STATUS` → `mark_installed`
  checks only the lock invariant (`doors/application/use_cases.py:69-76`), while the
  batch path and the online `PATCH /status` enforce `ALLOWED_TRANSITIONS_INSTALLER`
  (`installer_service.py:19-22, 67`); `POST /{id}/install` also bypasses it. For the
  offline app the direct NOT_INSTALLED → INSTALLED is the intended flow; the
  inconsistency is documented here, not proposed as a change.
- **B6. Left from Phase 3.** `doors/application/use_cases.py:210` still raises
  `Forbidden("Admin only")` instead of `FORBIDDEN_SCOPE`.

### C. Data layer

- **C1. No index on `completed_work.door_id`** (`earnings/infrastructure/models.py:71-75`,
  migration `0037`), queried on every completion and reversal
  (`completion.py:95-104, 171-182`).
- **C2. No partial unique index for one active DOOR ORIGINAL per door** — the add-on
  side has `uq_completed_work_addon_fact_original` (`models.py:48-55`); doors rely on
  the door row lock, the company lock and `is_locked`. Covered by two concurrency tests,
  but not by the schema.
- **C3. `outbox_messages.provider_message_id` has no index** and is used for webhook
  lookups (`outbox/infrastructure/repositories.py:81-90`).
- **C4. Immutability of ordinary earnings is application-only.** Triggers protect
  proposals/approvals/accruals and accrued `completed_work` rows (`0074:41-55`); plain
  `completed_work` and `factory_earning_prices` rows have none.

### D. Outbox, auth, integrations

- **D1. Outbox retries without backoff.** `mark_failed` only increments `attempts`
  (`outbox/infrastructure/repositories.py:58-63`); `scheduled_at` never moves, so all
  5 attempts happen about 3 s apart (`workers/outbox_worker.py:244-248`), and a
  WhatsApp fallback email is enqueued on **every** failed attempt when
  `WHATSAPP_FALLBACK_TO_EMAIL` is on (`:179-185`, `_enqueue_whatsapp_fallback_email`
  has no dedupe, `:33-47`). Messages are sent before the batch commit (`:226`), so a
  crash resends them; `main()` has no try/except (restart policy covers it).
- **D2. Refresh reuse revokes every session without grace.** A lost refresh response
  (the app does one refresh and retries once, `api.ts:366-386`) means the next refresh
  reuses the old token and revokes all sessions
  (`identity/application/auth_api_service.py:312-344`). Correct against replay, hard on
  a flaky network; the app then needs a fresh login and A3 can leave queue items stuck.
- **D3. Webhooks are `async def` with a synchronous unit of work**
  (`webhooks/twilio.py:46-85`, `webhooks/outbox.py:63-108`), blocking the event loop
  for the DB time. Twilio signature validation defaults off (`config.py:51`), enforced
  for production by `validate_production_env.py:309`.
- **D4. Rate-limit buckets are in-process and unbounded** (`rate_limit.py:12-30`): no
  effect behind a single worker, incorrect behind several.

### E. Tests and quality

- No mobile test runs real SQLite (`json_extract` / `json_valid` at `service.ts:1036,
  1385` never execute in tests); no lint. Backend has no lint or type check; the test
  `TestUnitOfWork` is a hand copy missing three repositories (`tests/conftest.py:82-116`);
  `sync_gc_worker` has no test; `GET /issues/{id}/media` is a stub returning `[]`
  (`issues/api/installer.py:100`); there is no photo/signature upload anywhere in the
  installer app or API (journal signatures are drawn on the public web page).

## Proposed blocks (each: minimal additive change, regression test, gate, own commit)

1. **Mobile queue resilience (A1, A2, A3).** `policy.ts`: 429 retryable; on a
   non-retryable error with more than one event, re-send events one at a time once so
   only the offending one is BLOCKED; post-response failures call `scheduleRetry` like
   the reset path; BLOCKED-with-auth items get Retry after a successful login (and Drop
   stays off). Tests in `sync/service.test.ts` + `presentation.test.ts`. Gate:
   `npm run quality-gate`.
2. **Backend v2 error semantics (B1, B6).** Unknown exceptions map to a stable
   `SERVER_ERROR` code that is **not** persisted as `apply_error` (so a replay re-runs
   the work), internal text stays in the log; `Forbidden("Admin only")` →
   `FORBIDDEN_SCOPE`. Tests in `test_sync_installer_snapshot_api.py`. Gate: backend
   integration suite (Postgres in Docker).
3. **Schema safety (C1–C3).** Migration `0075`: index on `completed_work.door_id`,
   partial unique index for one active DOOR ORIGINAL per door (preceded by a read-only
   duplicate check on the demo DB), index on `provider_message_id`; migration smoke
   head → base → head.
4. **Outbox retry policy (D1).** Exponential `scheduled_at` in `mark_failed`, fallback
   email only on the final failure (or deduped by correlation), send-then-commit order
   reviewed; worker tests.
5. **Mobile hygiene (A4, A5, A7, A8).** Guarded issue enqueue, price cache read that
   degrades to "no claim" with a log, E2E vars dev-only + production config check,
   `encodeURIComponent`, localized thrown messages, cold snapshot keeps contact links,
   README. Small commits.
6. **Backend hot paths (B4, D3).** `exists()` instead of full door lists, batched
   snapshot queries, DB-side pagination for the queue list, `def` webhooks. Tests on
   query counts where cheap.
7. **Cursor gap (B3).** Write the reproducing test first (two writers, out-of-order
   commit); fix only if it fails (e.g. horizon = min in-flight cursor, or company lock
   on admin writers), then detect `since_cursor` beyond max.
8. **Legacy batch protocol (B2).** Either harden input parsing + per-user scope, or
   mark it deprecated behind a flag since the app does not use it — the owner's call.

Not proposed: changing door transition rules (B5), the refresh reuse policy (D2), the
DB-trigger scope (C4) — each is a product decision; listed for the owner.

Device checks: the acceptance stack recipe (phone + stack on 8001) is available for
blocks 1 and 5; they need the owner's phone connected and will be recorded as
"needs external infra" until then.

## Not verified

Real-device behaviour of any block; backend tests were not run in this pass (the
suite needs the Docker Postgres); the cursor gap (B3) is a code-level risk, not a
reproduced defect; the AI router in the other agent's tree may change the OpenAPI
contract test while uncommitted.
