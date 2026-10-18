# DIMAX AI persistent conversations and tasks

Second implementation step of DIMAX_AI_PLAN.md. The existing read-only agent now
has durable server history, request replay, task cancellation and explicit recovery.
Position completion rules and server-calculated prices/earnings are unchanged.
Work photographs are not required.

## Implementation

- Alembic 0068_ai_memory: ai_conversations, ai_tasks, ai_task_attempts. Composite
  owner/company foreign keys link conversations to admin profiles and tasks to
  their conversation. Permanent request keys are unique per company/author.
- POST /admin/ai/tasks binds a UUID request key to normalized message, language,
  selected project and supplied conversation ID. Different input with the same
  key is rejected. Replays return persisted state without generation or new audit.
- GET conversations, conversation task pages and task state are author/scope
  restricted and bounded. Responses use no-store. History remains available when
  the AI provider is disabled or not configured.
- RUNNING, COMPLETED, FAILED, INTERRUPTED, CANCELLED are saved task states.
  One RUNNING task per conversation is enforced by a partial unique index.
  Per-author PostgreSQL transaction advisory locks work across API workers and
  end before any network request. Stored attempt IDs protect final publication.
- Expired leases become INTERRUPTED on read. Explicit retry uses a fresh permanent
  request token; repeated retry tokens cannot start another attempt. Only the
  latest failed/interrupted task can retry, with a limit of three total attempts.
  Cancellation and old attempt tokens cannot overwrite a current result.
- Revalidate active actor/company and unchanged scope during execution and before
  saved response delivery. Role changes hide prior conversations. Revocation during
  execution records a sanitized failure and discards the answer.
- Separate owner history stores bounded question/answer text and source links.
  General audit stores metadata only. No credentials, raw provider errors or raw
  reasoning saved. Cancellation has its own audit action without invented usage.
- Follow-ups receive the latest six completed pairs, at most 24,000 characters.
  Historical answers are explicitly untrusted context; current facts require tools.
  Prior tool payloads/reasoning are not saved or replayed. This uses manual text
  history supported by the [Responses conversation-state guide](https://developers.openai.com/api/docs/guides/conversation-state).
- Next.js /ai: conversation selector, paginated history, saved question/answer
  timestamps and sources, polling active tasks, explicit retry/cancel, stable request
  IDs for lost acknowledgements, auth-change clearing, EN/RU/HE and Hebrew RTL.
  No sensitive history is put in browser localStorage.
- Legacy /query remains a deprecated transient read endpoint for older clients.
  All new UI requests use durable /tasks.

## Verification

- Server: 46 passed in 43.72s on isolated dimax_acceptance_tests. Includes 18 core
  AI cases, 18 durable-memory cases, 8 existing issue API regressions and 2 module/
  transaction contracts. Real database sessions verify concurrent claims, duplicate
  HTTP submission, replay after disable, input fingerprint conflicts, cross-user/
  company isolation, changed/revoked scope, expired leases, explicit retries,
  three-attempt bounds, cancellation, stale attempt publication, bounded history
  and metadata-only audit. The earlier final run was interrupted by restarting
  the acceptance container; the complete series above was rerun after restart.
- Client: 44 passed in four files, covering the AI workspace, admin access,
  sidebar and existing installer pricing. Includes reload history without model
  access, lost acknowledgements, stable retry tokens, fresh tokens after an observed
  attempt fails, server cancellation, authentication clearing, localized controls,
  text-only rendering and safe source links. TypeScript and changed-file ESLint pass.
- Production Next.js build passes with 27 routes including /ai. Isolated
  .next-ai-core output; original next-env.d.ts and tsconfig.json preserved and
  restored. Verified generated client bundle includes both terminal-attempt token
  cleanup paths added during the work.
- Browser: 3 Playwright tests passed (1.3m) using mocked HTTP and the production
  build on separate port 4191. RU/HE at 390px preserve conversation/source records
  after page reload without a new generation request; Hebrew direction and no
  horizontal overflow verified. Lost network acknowledgement is recovered with
  byte-equivalent original input/request ID. Both screenshots inspected: readable
  history and controls, no clipping/overlap. This is an isolated browser contract
  check; existing next-start/standalone and terminal-color warnings remain.
- Migration 0068 was applied, rolled back on confirmed empty AI tables, and
  reapplied in the isolated tests DB. Also applied to the separate acceptance DB.
  Normal business DB was not migrated. Acceptance API alone restarted; /ready
  reports database-ready; OpenAPI exposes all eight AI routes. The owned preview
  server on port 4191 is stopped. No production launch or normal runtime restart.
- Git whitespace checks pass for workspace, backend and web repositories.

## Limits and release gates

No key was found during the earlier authorized search. No key created or copied,
and no live OpenAI request. Tests use scripted provider responses and mocked HTTP;
these prove application behavior, not real model quality.

No autonomous background restart or event worker yet; these belong to step 6.
Expired runs recover on explicit user action. Cancelling publication cannot recall
an already executing provider HTTP call. Process-local throttling remains separate
from durable request deduplication; distributed financial budgets are not implemented.

Current tasks read data only. Business-command idempotency and version-bound
approvals remain step 3. Normal database rollout, live model checks and production
deployment are not performed in this step. Do not claim a full agent release.
