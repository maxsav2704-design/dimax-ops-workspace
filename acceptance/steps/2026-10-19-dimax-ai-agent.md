# DIMAX AI agent: operating model, proposals, workspace (2026-10-19)

Owner's request (chat, 2026-10-19): act as lead architect / AI-agent engineer / designer. Study the
existing DIMAX AI (backend `app/modules/ai`, admin `/ai`), confirm by code and tests what works,
record what is weak or missing, then implement a strict agent operating model, a coverage matrix for
every section, one agent mechanism reused everywhere, all DIMAX business rules preserved, a strong
visual language for the `/ai` workspace with compact variants in the sections, the installer side with
offline, verification and documentation. Real model key: none on this machine; continue with a mocked
provider and say so.

Marks: **confirmed by tests**, **studied by code**, **seen live** (browser pane), **not verified**,
**needs external infra**.

Base: the other agent's steps 1–2 (`DIMAX_AI_PLAN.md`, `acceptance/steps/2026-10-09-dimax-ai-core.md`,
`-memory.md`) were uncommitted in both repos. They are built on, not reverted; this record and the
commits below include those files as the base of the agent.

## 1. Fact state of the existing DIMAX AI (research)

| Area | Status | Evidence |
|---|---|---|
| Read-only runtime: caller-owned Responses function loop, five bounded read tools, strict schemas, pagination, no money/contacts in tool output | Implemented well | `domain/tools.py`, `infrastructure/read_tools.py`; `tests/integration/test_dimax_ai.py` (18 cases) — confirmed by tests |
| Authorization: admin profile required, tools follow the scope's read prefixes, FINANCE gets installer search only, actor re-read before every tool and before the final answer, revocation discards the answer | Implemented well | `load_actor`, `ReadTools.check_access`; tests `test_access_revoked_during_provider_request_discards_answer`, `test_ai_does_not_bypass_role_or_profile` — confirmed by tests |
| Durable conversations and tasks (`0068_ai_memory`): request-id replay with input fingerprint, one RUNNING task per conversation, advisory locks across workers, lease → INTERRUPTED, explicit retry (3 attempts), cancel wins over a late result, owner/scope-private history, metadata-only audit | Implemented well | `infrastructure/task_store.py`; `test_dimax_ai_memory.py` (18 cases) — confirmed by tests |
| Provider: `store=false`, reasoning items preserved, sanitized error codes, no body/secret leaks | Implemented well | `infrastructure/provider.py`; `test_provider_does_not_expose_error_body_or_key` — confirmed by tests |
| Admin `/ai`: form, conversation select, history, polling, retry/cancel, recover lost acknowledgement, RU/EN/HE, RTL, auth-change clearing | Implemented but weak (plain form, no plan/sources structure, no selected-object context from the UI, no visual language) | `src/views/DimaxAiPage.tsx`, 13 Vitest cases, 3 Playwright cases — confirmed by tests |
| Execution model | Implemented but weak: the provider loop runs inside the HTTP request; RUNNING only matters for a lost response; no background worker or events (plan step 6) | studied by code |
| Business actions / approvals | Missing (plan step 3) | — |
| Selected object context | Partially: `project_id` accepted by the API, never sent by the UI | studied by code |
| Prompt-injection posture | Partially: instructions say record text is data; tool outputs did not mark text fields; comments were not readable at all | studied by code |
| Provider outage / no key | Explicit `missing_api_key` state; nothing runnable without a key | studied by code |
| Installer cabinet / mobile AI | Missing (plan step 4); AI history tables are bound to `admin_profiles` by a composite FK | studied by code |
| Highest value for the owner | A verified, auditable loop from a question to a saved office record with confirmation, and the same mechanism reachable from every section | — |

## 2. Agent operating model (implemented)

Order enforced by the server, not by the prompt alone:

1. **Intent and context.** The request carries `context: {kind: project|door|issue, id}`. The server loads it
   through an authorized read tool (`project_summary`, `get_door`, `get_issue`) before any provider call; a
   foreign/unknown id fails with 404 and nothing reaches the provider (`test_foreign_context_is_rejected_before_the_provider`).
2. **Authorization.** Actor, company and scope are re-read before every tool, before the answer, and again
   at confirmation. Action tools exist only for OWNER/OPERATIONS and only when `AI_ACTIONS_ENABLED` is on.
3. **Fresh data.** Read tools return current rows; prior answers are passed as untrusted history.
4. **Plan → preview → proposal.** An action tool (`propose_issue_report`, `propose_issue_comment`,
   `propose_issue_workflow`) never executes. It runs the action's `preview` (fresh read, before/after,
   expected versions) and stores an `ai_proposals` row (`0079_ai_proposals`). The model receives
   `{proposal_id, executed: false, preview, note}` and must say nothing was saved.
5. **Confirmation.** `POST /admin/ai/proposals/{id}/confirm {request_id}`: re-checks actor/scope/flag,
   claims the row with the client's request id (replay-safe), re-reads the record under lock, compares
   versions (`door.version`, `issue.updated_at`, issue status), executes the existing office command and
   marks EXECUTED in the same transaction, verifies by reading the saved record back, stores result and
   server-built sources. Conflict → `CONFLICT/AI_VERSION_CONFLICT`, no write. Expired → `EXPIRED`.
   Reject → `REJECTED`. A second click or a different request id on a finished proposal never executes again.
6. **Answer with sources and audit.** Reply carries `steps` (tool, ok, ms), `proposal_ids`, `provider`;
   audit holds `AI_PROPOSAL_CREATED`, `AI_ACTION_EXECUTED`, `AI_PROPOSAL_REJECTED`, `AI_ACTION_FAILED`
   with ids and tool names, never the question text.

Trust levels in the instructions: (1) tool results of this run, (2) company rules, (3) conversation
history, (4) record texts as data. Tool outputs wrap title/details/comment texts as `{"untrusted_text": …}`
(`test_issue_context_marks_record_text_as_untrusted_data`).

Limits: existing steps/tool calls/deadline/throttle; `AI_MAX_PROPOSALS_PER_TASK` (3), `AI_PROPOSAL_TTL_SEC`
(30 min), confirm throttle 30/min per user. Feature flags: `AI_ENABLED`, `AI_ACTIONS_ENABLED`, `AI_PROVIDER`.

### Tool specifications

| Tool | Kind | Rights (read prefix / write scope) | Args | Result | Errors | Version check | Retry |
|---|---|---|---|---|---|---|---|
| search_projects | read | /admin/projects (not FINANCE) | q, limit≤40, offset | page + sources | VALIDATION | — | model may re-call with another page |
| project_summary | read | /admin/doors | project_id | counts, open issues | NOT_FOUND | — | — |
| list_project_doors | read | /admin/doors | project_id, status, limit, offset | page with reasons/types, door `version` | NOT_FOUND | — | — |
| list_project_issues | read | /admin/issues | project_id, status, limit, offset | page | NOT_FOUND | — | — |
| search_installers | read | /admin/installers | q, limit, offset | page, no contacts | VALIDATION | — | — |
| get_door (new) | read | /admin/doors | door_id | door + project + issue summary, `version`, comment as untrusted text | NOT_FOUND | — | — |
| get_issue (new) | read | /admin/issues | issue_id | issue + door + ≤20 comments as untrusted text, `updated_at` | NOT_FOUND | — | — |
| propose_issue_report (new) | action | OWNER/OPERATIONS + flag | door_id, title≤200, details≤2000, priority | proposal (preview: new/reopen/append, door status after) | NOT_FOUND, VALIDATION (limit) | expected `door_version` + `issue_id` at confirm | confirm is idempotent per request id |
| propose_issue_comment (new) | action | same | issue_id, body≤2000 | proposal | NOT_FOUND | expected issue status | same |
| propose_issue_workflow (new) | action | same | issue_id, workflow_state, priority, due_date | proposal (before/after) | NOT_FOUND, VALIDATION (nothing to change) | expected `issue_updated_at` | same |

Office command reused by the report action: `IssuesAdminApiService.report_issue` (new, same semantics as the
installer report: one issue per door, append when open, reopen when closed; installation facts, prices,
assignment untouched) exposed as `POST /admin/issues` for the office too.

## 3. Coverage matrix (what the agent can do per section)

| Section | Read now | Act now (proposal + confirmation) | Context from the section | Not for the agent (by rule) |
|---|---|---|---|---|
| Dashboard | projects, open issues via tools | — | company-wide launcher | money tiles (no financial tools) |
| Projects / doors | project summary, door pages, one door | issue report on a door | launcher: selected door, else project | install/not-installed facts, assignment, prices |
| Calendar | events in a date range, per project (admin); my schedule (installer) | — | — | planning dates |
| Issues | project issues, one issue with comments | comment, workflow (state/priority/deadline) | launcher: selected issue | owner change, closing by installing |
| Installers | search by name, workload (positions by status, projects, open issues) | — | — | contacts, identity, rates, earnings |
| Journal / documents | journals of a project: status, signed or not, delivery, snapshot version | — | — | signatures, factory confirmation, signer identity |
| Price / earnings / held work | — | — | — | any price or amount |
| Reports | — | — | — | — |
| Catalogs | reasons/types appear as names in door reads | — | — | catalog edits |
| Operations / sync | — | — | — | sync and outbox decisions |
| Settings | DIMAX AI card: connection, budget, company rules (owner), connection check | — | — | secrets, integrations |
| Installer cabinet / mobile | my projects / my positions / my issues (assignments only) | my issue report, my comment (the app's own commands) | cabinet: project page, focused issue; mobile: project screen | installation facts, prices, rates, earnings; offline flows unchanged |

Rows with "—" are documented gaps, not hidden behaviour: the tool registry is the single place where a new
read or action is added, and the proposal/confirmation mechanism is reused unchanged.

## 4. Implementation record

Backend (`backend`):
- `0079_ai_proposals`: `ai_proposals` table (composite FK to the owner's task, status check), `ai_tasks.context`.
- `domain/tools.py`: `ToolSpec` registry (kind read/action, permission path, version), `actions_available`.
- `application/actions.py`: three actions with `preview` / `execute` (verify by re-read).
- `infrastructure/proposal_store.py`: propose / confirm (two phases: claim with request id, then command +
  EXECUTED atomically) / reject / expire / list, advisory lock per user, metadata audit.
- `infrastructure/read_tools.py`: action dispatch to the store, `get_door`, `get_issue`, untrusted text wrapping.
- `application/runner.py`: operating model + trust ladder instructions, context loading through tools,
  `steps`, `proposal_ids`, provider label.
- `infrastructure/mock_provider.py`: deterministic demo provider (keyword intents: unfinished doors on a
  project, obstacle → issue report on the mentioned door, comment on a selected issue), every answer labelled.
- `api/admin.py`: status with `provider`, `actions_enabled`, `real_model_verified=false`; proposals
  get/confirm/reject; provider selection; legacy `/query` stays read-only.
- Issues: `IssuesAdminApiService.report_issue`, `POST /admin/issues`, `AdminIssueReportBody`.
- Config: `AI_ACTIONS_ENABLED`, `AI_PROVIDER`, `AI_PROPOSAL_TTL_SEC`, `AI_MAX_PROPOSALS_PER_TASK`; `.env.example`.
- Tests: `tests/integration/test_dimax_ai_actions.py` (14 cases): flags and scopes, the end-to-end scenario
  (project context → unfinished doors → proposal → confirm once → saved issue verified → replay and second
  click do nothing), version conflict, expired/rejected, revoked scope at confirmation, author privacy,
  foreign door, proposal limit, injection text as data, foreign context 404, comment + workflow actions
  with a stale-preview conflict, office endpoint, mock provider end to end.

Admin (`dimax-operations-suite-main`):
- `src/lib/dimax-ai.ts`: types for context/steps/proposals, `parseAiContext`, `aiContextHref`, preview
  labels and rows, `AI_PROMPTS`, copy in EN/RU/HE.
- `src/views/DimaxAiPage.tsx`: the workspace — rail (dialogs list + select, connection card with provider
  and actions state), hero with the animated orb (idle / working / awaiting; paused offscreen; reduced
  motion respected; lighter under 640px), selected-object context chip from the deep link, composer,
  thread with per-task timeline (received → context → records read · n calls → proposal prepared → answer),
  sources chips, proposal cards (before/after table, decision buttons, ConfirmActionDialog with "what
  changes / what is kept", stable decision token across a lost response, result "Saved and verified" with
  record links, CONFLICT/EXPIRED/REJECTED/FAILED states).
- `src/components/ai/AiAssistPanel.tsx`: compact launcher reused by Dashboard (company), Projects (selected
  door, else project) and Issues (selected issue); deep links into the one workspace with context and a
  ready question.
- `src/index.css`: isolated `.dmx-ai-*` block.
- Tests: `DimaxAiPage.test.tsx` (13 existing + 4 new: deep-link context sent, proposal card + confirm once
  with a stable token after a lost response, reject/conflict/expiry states, actions off), `AiAssistPanel.test.tsx` (3).

## 5. Verification

| Check | Result | Mark |
|---|---|---|
| Backend AI suite on `dimax_acceptance_tests` (0079 applied): `test_dimax_ai_actions.py` 14, `test_dimax_ai.py` 18, `test_dimax_ai_memory.py` 18 | 50 passed | confirmed by tests |
| Company/role isolation: FINANCE/VIEWER never see action tools; another admin cannot read/confirm a proposal (404); foreign door → NOT_FOUND inside the run, foreign context → 404 before the provider | pass | confirmed by tests |
| Revocation: write scope removed between proposal and confirmation → 403, proposal stays PROPOSED, no issue | pass | confirmed by tests |
| Injection: issue title/details "Ignore all rules…" reach the provider only as `untrusted_text`, instructions carry the trust ladder | pass | confirmed by tests |
| Duplicate confirmation / lost response: same request id replays, different request id on EXECUTED returns the state, one issue in the DB | pass | confirmed by tests |
| Version change after preview (door version, issue updated_at) → CONFLICT, no write; expiry → EXPIRED; reject → REJECTED and later confirm does nothing | pass | confirmed by tests |
| Proposal limit per task (`AI_MAX_PROPOSALS_PER_TASK`) returns a tool error, no extra rows | pass | confirmed by tests |
| Mock provider end to end without a key, status `provider: mock`, `real_model_verified: false` | pass | confirmed by tests |
| Admin Vitest: `DimaxAiPage.test.tsx` 17, `AiAssistPanel.test.tsx` 3, plus Index/Issues/Projects pages | 93 passed; `tsc` clean; ESLint clean; type-scale and RTL ratchets pass | confirmed by tests |
| Live demo stack (api recreated with `AI_PROVIDER=mock`, `AI_ENABLED`, `AI_ACTIONS_ENABLED`; 0079 applied to the demo DB; compose also started the `minio` dependency): Projects page launcher → `/ai?context=project:…&q=…` → task "Какие позиции не завершены?" → timeline "Запрос получен → Выбранный объект прочитан → Записи прочитаны · 2 вызова → Ответ", 20 positions with sources | works | seen live |
| Live: "Нет доступа в квартиру… поставь замечание" → proposal card (before/after: position Не установлена → Открыто замечание, issue Открыто/Новое/P3) → "Проверить и подтвердить" → dialog with "what changes / what is kept" → "Подтвердить" → card EXECUTED "Сохранено и проверено" with links to the issue and the project | works | seen live |
| Live DB after confirmation: issue `02a16eea…` OPEN/NEW/P3 with author; door `621315ba…` ISSUE_OPEN, version 1, no installed_at/lock/rate snapshot; `ai_proposals` EXECUTED with the request id; audit `AI_READ_QUERY` ×2 (metadata), `AI_PROPOSAL_CREATED`, `ISSUE_REPORTED`, `AI_ACTION_EXECUTED`; project health BLOCKED (open issue rule) | matches the card | seen live |
| Live: Issues page opened on the new issue shows the issue-context launcher (summary / comment / priority+deadline prompts) | works | seen live |
| Live: mobile 375px, Hebrew, RTL: `dir=rtl`, no horizontal overflow on the page and the admin scroller, the executed card readable; orb lighter (second ring hidden) | works | seen live |
| Reduced motion: all AI animations sit under `prefers-reduced-motion: no-preference`; offscreen orb paused through IntersectionObserver | studied by code; Playwright HE run uses `reducedMotion: reduce` | studied by code |
| Playwright `e2e/dimax-ai.spec.ts` on the production build (`.next-ai-core`, port 4191, mocked HTTP): 3 existing + 2 new (proposal card confirmed once, RU 1280px and HE 390px with `reducedMotion: reduce`, screenshots inspected: card, dialog result, RTL, no overflow) | 5 passed | confirmed by tests |
| Real model run | not possible: no key on this machine; the live provider path is exercised only by mocked HTTP | needs external infra |
| Installer cabinet / mobile AI, offline | implemented in block 6 below | see block 6 |

Backend regression after the issues changes (`test_issues_admin_api`, `test_issue_lifecycle_sync`, `test_factory_issue_financials`, `test_admin_list_contracts`, `test_openapi_contract`): 45 passed — confirmed by tests.

Demo side effects of the live check: one real issue on the demo project "צרפתי שמעון — בניין 1"
(door `1--1-כ.מחסנים…`), one AI conversation with two tasks and one executed proposal for admin@dimax.dev.

## 6. Installer cabinet and mobile (owner's request of 2026-10-19, "берись за кабинет монтажника и мобильный аи")

Decision taken: the AI history no longer belongs to admin profiles. `0080_ai_installers` drops the
composite FK, adds `owner_role` and makes `admin_scope` nullable; the live actor is re-read with its
role before every tool, answer and confirmation, and a role change hides the old history.

Backend (`53a40ce`): installer tool set and two proposal actions (registry `role="INSTALLER"`),
`require_installer_id` (active, non-deleted installer linked to the user; unlinked → 403),
shared route registration (`api/routes.py`) for `/admin/ai` and `/installer/ai`, mock provider
resolves either tool set. Tests `test_dimax_ai_installer.py` (9): tool set without installation/money
tools and without admin tools; unlinked installer refused; reads limited to assigned positions
(colleague's door → NOT_FOUND, admin tools → forbidden, `mark_installed` → forbidden, no price
fields, comment as untrusted text); the scenario (project context → my doors → proposal → confirm
once → issue by the installer, door ISSUE_OPEN, replay and second click do nothing, installer paths in
sources); colleague's door never becomes a proposal; own comment with injection text as data; the
admin router cannot read or confirm the installer's conversation/proposal; role change hides history
and closes the installer router; mock provider without a key. All 59 AI cases green.

Admin cabinet (`0c5ab91`): `DimaxAiPage` and `AiAssistPanel` take `surface` (admin | installer):
installer API, `/installer/ai` routes, installer-only access, installer prompts and subtitle;
`safeAiSourcePath` accepts cabinet paths; nav entry "DIMAX AI" in `InstallerShell` (EN/RU/HE);
launchers on the installer project page (project context) and on the focused issue. Vitest 59 across
the touched files, `tsc`, ESLint clean. Playwright: installer cabinet HE at 390px (installer API only,
context chip, source link to the cabinet project, RTL, no overflow): 6 passed on the production build (`.next-ai-core`, port 4191, mocked HTTP), screenshot inspected — confirmed by tests. Two e2e lessons recorded for the next session: type only after a client-fetched text is visible (the pre-rendered HTML drops typed text on hydration), and mock the conversation's task page because the workspace reloads the conversation after a send.

Mobile (`e46c197`): `src/modules/ai/{navigation,client}.ts` (routes without the API import for light
screens; API calls, failure classification without provider bodies, preview rows, source → app route
mapping that never trusts server paths), `app/ai.tsx` (status pills with provider/actions, context from
the project screen, question with prompts, thread with answers, source rows, proposal cards with
before/after, ConfirmDialog, stable decision token across a lost response, reject, recent
conversations; explicit offline state with the sync queue shortcut), entry button on the project
screen, Stack route. Tests: helpers (4) and the screen (4: installer API only + context, confirm once
after a lost response, offline state + queue shortcut, access failure without provider details + Hebrew
right alignment); the whole mobile suite 852 green, discovery contract 69 files, `tsc` clean.

Not done / limits: no live installer login exists in the demo stack that could be used without
creating or changing an account, so the installer surfaces are verified by tests and by the Playwright
run with mocked HTTP, not by a live installer session; voice input (plan step 9) not started; the
mobile screen was not run on a phone (owner: "в телефоне продолжим позже").

## 7. Background execution (owner's choice of 2026-10-19: "делай 3 пункт")

Backend (`AI_EXECUTION_MODE`, `0081_ai_worker_claims`, `app/workers/ai_worker.py`, compose `ai-worker`):
the API queues in background mode and the worker claims once (`claimed_at`, SKIP LOCKED, fresh lease
for the run) and executes `execute_task`, now the single pipeline for inline and worker runs. Status
reports `execution`. Tests `test_dimax_ai_worker.py` (7): queue → claim once → COMPLETED → replay
without a second run; four parallel workers claim once; inline tasks never picked by the worker;
access revoked before the worker runs → FAILED `AI_ACCESS_CHANGED`, no answer; cancelled task
skipped; expired lease not claimed, INTERRUPTED on read, explicit retry re-queues and the worker runs
attempt 2; proposals prepared by a worker run are confirmable by the owner; mock provider through the
worker. All 66 AI cases green on `dimax_acceptance_tests` (0081 applied).

Live (demo stack recreated with the override: api in background mode + `ai-worker` container, 0081 applied
to the demo DB): the admin workspace sent "Что не завершено на объекте?" with the project context; the API answered
at once, the page polled, the worker claimed the task (`claimed_at` set after creation) and completed it in
4 s with the mock provider; timeline and sources rendered as in inline mode — seen live.

Limits: the worker is a polling loop (2 s idle), not an event consumer; one task per claim; no
distributed budget; business events (plan step 6) and a real model (step 8) remain open. The web and
mobile UIs needed no change: they already poll RUNNING tasks and offer cancel/retry.

## 8. Company rules, budget, connection check, coverage reads (owner: "продолжай до 100%")

Backend (`c0189f4`): `0082_ai_company_rules` + `AiRulesService` (versioned, metadata audit `AI_RULES_UPDATED`),
`GET/PUT /admin/ai/rules` (owner writes, every admin reads), rules injected into the runner as trust level 2 with
the explicit limit that they cannot add tools or override business rules, `reply.rules_version`; durable daily
company budget (`AI_DAILY_TASK_LIMIT_PER_COMPANY`, 429 `TOO_MANY_REQUESTS` with a clear message, `daily_used/limit`
in status); `POST /admin/ai/check` (owner, 3/min, tool-less round trip, codes only, audited `AI_CONNECTION_CHECK`);
reads `list_calendar_events`, `project_journals`, `installer_workload`, `my_schedule`. Tests `test_dimax_ai_rules.py`
(9): versions and audit without text, OPERATIONS cannot change rules or run the check, budget durable and replay-safe,
check reports codes never bodies (200/401/500 mocked HTTP), mock provider check and 503 when not configured,
calendar/journal/workload scoped and bounded (62 days, bad dates, no signer name, no rates), my_schedule shows only
own events. All 75 AI cases green on `dimax_acceptance_tests` (0082 applied).

Admin (`AiSettingsCard`): Settings → DIMAX AI card with connection facts, execution mode, budget, the rules editor
(owner only; version, author, time), save and connection check with readable results; the workspace connection
card shows execution mode, rules version and budget. Tests `AiSettingsCard.test.tsx` (3), Settings and workspace
suites green, `tsc`, ESLint, ratchets clean.

Live (demo api + worker recreated, 0082 applied): Settings → DIMAX AI shows provider, readiness, actions, execution mode
and the budget; the owner saved rules (version 1, author and time shown), the connection check answered "works · mock · 13 ms";
the workspace connection card shows "Правила компании: версия 1" and the next task completed with `rules_version` 1 stored in
its reply — seen live.

## 9. Document content, voice, live installer run (closing the pass)

- `journal_document` (backend `edff196`): one journal at its snapshot version — positions and add-on works
  listed in it (quantities, no prices), signed or not, notes as untrusted text, a quotable source label
  "journal <title>, snapshot version N"; the `extra` JSON of items (which may hold prices) and the signer name are
  never returned — confirmed by tests (`test_journal_document_is_quoted_with_its_snapshot_version_and_without_money`).
- Voice (admin `c7f5dd3`): the workspace composer shows "Dictate" only when the browser offers speech recognition;
  dictation runs in the current language (ru-RU / he-IL / en-US) and only fills the question; rights and the
  proposal flow are unchanged — confirmed by tests (fake recognition, hidden without support). Mobile voice is not
  started (needs a native module and a device run).
- Installer proposal titles fixed (`e430476`): the installer actions now have readable names in EN/RU/HE.
- Live installer run (seeded login `installer1@dimax.dev` from `app/scripts/seed_dev.py`, one unfinished door of the
  demo project assigned to that installer directly in the demo DB for the check): the cabinet shows the "DIMAX AI" nav
  entry; `/installer/ai` with the project context lists provider, actions, background execution, rules version 1 and
  the budget; "Какие мои позиции не установлены? Нет доступа, запиши замечание" → the worker completed the task,
  the card proposed the installer's own report on the assigned door → "Проверить и подтвердить" → "Подтвердить" →
  "Сохранено и проверено" with links to the cabinet issue and project. DB: issue OPEN/NEW created by the installer
  user, door ISSUE_OPEN with its version bumped, audit `AI_PROPOSAL_CREATED` and `AI_ACTION_EXECUTED` by the installer,
  conversation owned as INSTALLER without a scope; the installer issues page opens the issue with its own launcher — seen live.

## 10. Status against the original prompt

| Requirement | Status |
|---|---|
| Study, fact state, weak/missing, highest value | done (block 1) |
| Agent operating model, tool specs with rights/limits/version check/retry, server-side authority | implemented and tested (blocks 2, 4) |
| Coverage matrix for every section | done; reads for dashboard/projects/doors/issues/installers/calendar/journal/documents; actions in issues; price/earnings/reports/operations/settings intentionally without agent writes (block 3) |
| One agent mechanism everywhere | one registry, one pipeline (`execute_task`), one workspace with `surface`, launchers on sections, installer cabinet and mobile on the same API |
| Business rules preserved | confirmed by tests: no installation facts, prices, rates, earnings, assignments, signatures; installers see only their positions |
| Unified system: context, allowed tools, persisted tasks/decisions, continuation after confirmation, retries, version conflicts, audit, limits, feature flags, provider outage, trust levels, injection protection, revocation, secrets server-side | implemented and tested; continuation after confirmation is deterministic verification (no second model call) |
| Visual language for /ai and compact variants, RU/HE/EN, RTL, keyboard, reduced motion, mobile | implemented; Playwright 6 (RU/HE, 390/1280, reduced motion), screenshots inspected |
| Installer cabinet and mobile with offline | implemented and tested; cabinet seen live; mobile screen tested, not run on a phone |
| Background execution | implemented and tested, seen live |
| Company rules, budget, connection check | implemented and tested, seen live |
| Real model | not possible here: no key on the machine; the owner's check button verifies a key once it is set on the server |
| Business events resuming tasks | decided out for now: in the proposal model a task completes in one run and humans confirm; nothing waits for events |
