# DIMAX AI implementation plan

Started: 2026-10-09. Delivery is incremental; each step requires its own evidence.

## Agreed business rules

- Installers confirm a specific position as installed, or record non-completion
  with a reason. Work photographs are never required for completion or earnings.
- The server calculates earnings using the established factory-price timeline.
  AI cannot invent prices, rewrite earning snapshots or sign for another person.
- Reuse existing business services, authorization, audit, journal and sync flows.
- Company boundaries and current user permissions apply to every agent tool.
- Keep offline installer actions independent of online AI availability.
- Warehouse, purchasing, logistics and routing remain outside project scope.

## Existing architecture and gap

FastAPI provides company-scoped domain modules and PostgreSQL repositories.
Next.js provides a role-aware RU/EN/HE admin workspace. Expo preserves offline
installer actions. Confirmed price activation and financial snapshots now exist;
the older October 2 pricing dependency is no longer the implementation baseline.
Step 1 provides the AI runtime and admin UI. Step 2 adds server-owned conversation
history and task recovery without replacing the existing business application.

## Ordered implementation

| Step | Deliverable | Acceptance condition | Status |
| --- | --- | --- | --- |
| 1 | AI runtime, operational read tools and admin workspace | Model can call authorized functions, return an answer and show server-derived source links; provider failures are explicit | Implemented and tested; live key/model activation pending |
| 2 | Persistent tasks, conversations and replay protection | A task survives restart; repeated requests return saved state without starting a second run | Implemented and tested; normal DB rollout/live activation pending |
| 3 | Authorized mutations and approvals | Office issue report / comment / workflow reuse current commands; approvals bind to a specific version/payload | Implemented and tested (proposals + confirmation, 2026-10-19); position completion and reasons intentionally not given to the agent |
| 4 | Installer web/mobile AI | Context-aware commands, RU/HE input and queued requests; offline completion stays usable | Implemented and tested (0080, installer tool set, cabinet /installer/ai, mobile /ai screen run on the phone against the demo api, 2026-10-19); voice input not included; live run only with the mock provider |
| 5 | Prepare day / resolve obstacle / finish day workflows | Each workflow reaches a verified saved outcome or an explicit waiting state | Planned |
| 6 | Business events and background worker | Committed events resume tasks without duplicate processing or notification loops | Partially: background worker implemented and tested (2026-10-19, `AI_EXECUTION_MODE=background`, `app.workers.ai_worker`); business events not started |
| 7 | Approved company rules and document knowledge | Persistent rules are reviewable; document answers identify authoritative source/version | Partially: versioned owner rules implemented and tested (2026-10-19); journal/document status reads exist, journal content read at its snapshot version (`journal_document`); PDF/free-text knowledge not started |
| 8 | Live pilot and operational release | Real model/tool checks, company isolation, regression gates, cost/latency monitoring and disable switch | Prepared: owner connection check, durable daily company budget, audit of latency/requests, disable switches (2026-10-19); the real-model run itself needs a key on the server |
| 9 | Voice and optional marking recognition | Voice follows the same permissions; marking photos only help locate positions | Partially: web dictation through the browser's speech recognition fills the question (2026-10-19); mobile voice and marking recognition not started |

## Step 1 scope

Use the agreed Responses API function-calling integration through the existing
HTTP client dependency. Keep the loop on DIMAX servers to enforce domain access
and avoid opening business infrastructure to a hosted sandbox. No new agent
framework, cloud sandbox, dependency or database migration is needed for this
bounded first step. This is not persistent conversation memory yet.

Expose search_projects, project_summary, list_project_doors,
list_project_issues and search_installers. Return operational fields only;
financial fields, contact details and identity documents are not tool output.
Revalidate the actor before tool reads and before delivering a final answer.
Sources are built by backend code from actual returned records, not model URLs.
Short DB transactions never span provider requests.

Configure OPENAI_API_KEY on the server, AI_MODEL and AI_ENABLED. User chose
reuse of an existing key. A local credential has not been located; do not create
a new key or claim a live model connection. Mocked provider tests are explicitly
distinguished from real API evaluation. No plaintext secrets in source, logs or UI.

Pilot bounds: input length, tool argument validation, pagination, maximum model
requests/tool calls, deadline and per-user process-local request throttle.
Company-wide durable budgets belong to subsequent steps. Step 2 adds persistent
request replay for the new task endpoints; the legacy /query endpoint is deprecated.

## Step 2 scope

Alembic 0068_ai_memory adds owner-scoped conversations, tasks and attempt request
keys. The web workspace uses /admin/ai/tasks and can reopen saved conversations,
recover a lost acknowledgement, cancel a saved running task and explicitly retry
a failed/interrupted latest task. Database constraints and short advisory locks
serialize duplicate requests across API workers. No lock spans a provider call.

Each request ID binds to a canonical input fingerprint. Reuse with different input
is rejected. Completed/failed/running/cancelled states can be read without an AI
key; replay does not call the provider. Exactly one active task per conversation.
Each retry has its own permanent request key and at most three total attempts.
An attempt lease expires after the configured run deadline plus 15 seconds;
subsequent reads mark it INTERRUPTED. Nothing resumes automatically. Cancellation
and newer attempts prevent a stale result from being published. An already active
provider HTTP request may still consume tokens after cancellation.

History belongs to the authenticated company and author and is separated by the
admin scope used when the conversation was created. Every read/claim/final reply
revalidates current activity and scope. No team-wide history or cross-role context.
Normal audit holds metadata; question/answer text lives in the dedicated owner
history. Credentials, raw provider error bodies and reasoning are not stored there.

Follow-ups receive at most six complete successful question/answer pairs and
24,000 characters. Prior answers are historical context; current business facts
must be read through authorized tools. Tool results and reasoning from earlier
turns are not replayed as current facts. Long-term knowledge and automatic context
compaction remain step 7. All tools remain read-only: action-level idempotency and
approvals must be added with business mutations in step 3.

Only isolated acceptance databases receive this migration during implementation.
Normal database rollout and live key/model activation remain explicit release
work. Evidence: acceptance/steps/2026-10-09-dimax-ai-memory.md.

## Step 3 scope (2026-10-19)

Business actions are proposals. An action tool stores a row in `ai_proposals` (0079) with the
arguments, a fresh preview (before/after) and the expected versions; the model only learns that
the proposal exists. A separate `POST /admin/ai/proposals/{id}/confirm` with a client request id
re-checks the actor, write scope and `AI_ACTIONS_ENABLED`, re-reads the record under lock,
compares versions, runs the existing office command and the EXECUTED mark in one transaction,
and verifies by reading the record back. Replays and late clicks never execute twice; a changed
record yields CONFLICT; proposals expire after `AI_PROPOSAL_TTL_SEC`. Actions in this step: office
issue report on a position (`IssuesAdminApiService.report_issue`, also `POST /admin/issues`),
issue comment, issue workflow (state / priority / deadline). Installation facts, prices, rates,
assignments, signatures and factory confirmations stay outside the agent.

The selected object (`context: project|door|issue`) is loaded through an authorized tool before any
provider request. Record texts in tool output are wrapped as untrusted text. `AI_PROVIDER=mock`
selects a deterministic demo provider for stacks without a key; status reports `provider` and
`real_model_verified=false`. The admin `/ai` workspace shows the timeline, sources, proposal cards
with a one-time confirmation, and sections open it with their object as context (`AiAssistPanel`).
Evidence: acceptance/steps/2026-10-19-dimax-ai-agent.md.

## Step 4 scope (2026-10-19)

`0080_ai_installers` lets any active user own AI conversations (`owner_role`, nullable scope); a
role change hides the old history like a scope change. Installers get their own tool set
(`my_projects`, `my_project_summary`, `my_project_doors`, `my_door`, `my_project_issues`, `my_issue`)
bounded by their assignments, and two proposal actions that reuse the app's own commands:
`propose_my_issue_report` (InstallerIssuesApiService.create_issue with the assignment check) and
`propose_my_issue_comment`. No installation facts, prices, rates or earnings are tools. The routes
are shared: `/api/v1/installer/ai/*` registers the same handlers as `/admin/ai/*` behind
`require_installer` + the installer linkage check. The web cabinet gets `/installer/ai` (the same
workspace with surface=installer), a nav entry and launchers on the project and the focused issue.
The mobile app gets the `/ai` screen on the installer API (context from the project screen, proposal
cards with a stable decision token, recent conversations) and an explicit offline state that points
to the sync queue; door actions keep queuing offline exactly as before.

## Step 6, worker part (2026-10-19)

`AI_EXECUTION_MODE=background` makes the API record the task as RUNNING and unclaimed and answer at
once; the web and mobile clients poll it (3 s). `app.workers.ai_worker` (compose service `ai-worker`)
claims one task at a time with `FOR UPDATE SKIP LOCKED`, refreshes the lease for the run and executes
the same pipeline as the inline path (live actor re-read with role, tools, proposals, finish/fail,
metadata audit), so several workers never run one attempt twice. Inline tasks are claimed at start by
the API; a retry clears the claim; a worker that dies leaves the lease to expire and the client gets
INTERRUPTED with an explicit retry. Business events (resuming tasks on commits) remain open.

## Steps 7 and 8, prepared parts (2026-10-19)

`0082_ai_company_rules`: the owner writes company rules in plain language (Settings → DIMAX AI);
every save is a new version, every admin can review them, the agent receives the current version as
trust level 2 (it cannot add tools, grant rights or override the business rules) and every reply
records `rules_version`. `AI_DAILY_TASK_LIMIT_PER_COMPANY` is a durable per-UTC-day budget shown in
the status and enforced at start/retry (429). `POST /admin/ai/check` lets the owner run one tool-less
provider round trip and see provider/model/latency or a stable error code (audited). New reads:
calendar events (admin, bounded to 62 days), project journals (status, signed or not, delivery; no
signer identity), installer workload (no money/contacts), and `my_schedule` for installers. Document
text knowledge (answers citing document contents) is not started.

## Verification and rollout

Use isolated acceptance tests, never business-table writes in the normal DB.
Cover role/company isolation, revoked access, invalid tool arguments, excluded
financial fields, pagination, provider failures, no-key state and bounded loops.
Verify admin loading/errors, source links, auth-change cancellation, RU/HE and RTL.
Run architecture contracts, relevant authorization regressions, TypeScript and
changed-file lint. A real model/key check and production deployment are separate
release gates. Record actual evidence in acceptance/steps/2026-10-09-dimax-ai-core.md.
