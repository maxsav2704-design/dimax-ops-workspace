# DIMAX AI core and admin workspace

## Scope and architecture

First implementation step of DIMAX_AI_PLAN.md. Add a company-scoped read-only
agent to the existing FastAPI application and a Next.js admin route at /ai.
Reuse CurrentUser, module read permissions, unit-of-work boundaries, repositories,
audit, HTTP client, authenticated layout, shared controls and RU/EN/HE conventions.

The agreed caller-owned Responses function loop enforces application permissions
locally. No hosted sandbox, additional dependencies or database migration.
There is no persistent conversation/task memory or business mutation in this step.

## Implemented

- Five bounded operational tools: project search, exact project counts, paginated
  positions with reasons/type names, paginated issues and installer search.
- OWNER/OPERATIONS/VIEWER use their existing module read permissions. FINANCE
  has installer search only, matching the available admin destination. Installers
  and missing admin profiles are denied. No money, contacts, identity documents
  or price fields in tool responses.
- Company derived from authentication. Actor/company activity and current scope
  rechecked before tools and final delivery; permission changes discard the run.
- Strict tool schemas, argument validation, pagination, model/tool/deadline/output
  bounds, and process-local six-requests-per-minute throttle per company/user.
- Server-built source links to supported project/issue/installer destinations.
  Model text renders as text, with no executable HTML or model-provided URLs.
- Short DB transactions; no provider request inside a business transaction.
  Audit stores run ID, outcome, tool names, request count and duration only.
- Server-only SecretStr credential; explicit missing-key/model/disabled state.
  Responses use store=false and preserve reasoning items between tool calls.
  Provider exceptions expose stable error codes, not response bodies or secrets.
- Admin navigation, form, localized connection/error states, cancellation and
  clearing on authentication changes; late cancelled responses are discarded.
- Demo Compose passes server credential/model/enable variables. Workspace
  Compose already consumes backend/.env. Acceptance stays offline/provider-free.
- Existing InstallerPricingMode test selectors used unsupported exact options
  with getByRole/queryByRole. Removed those five options; string name matching
  and business assertions remain unchanged.

Installers' normal position confirmation remains the basis for completion.
Photographs are not required for work confirmation or earnings. The AI tools
do not write completion, prices, assignments, signatures or financial snapshots.

## Verification

- Final server run: 28 passed in 86.46s, isolated dimax_acceptance_tests DB.
  Includes 18 AI cases, 8 existing issue API cases and 2 architecture contracts.
  Covers real scoped reads, foreign projects, pagination, excluded financial fields,
  role/profile rejection, revoked access, context authorization before external
  calls, unknown write tools, invalid arguments, step limits, no-key behavior,
  sanitized provider errors, reasoning continuity and audit metadata.
- Final client run: 37 passed in four files; AI workspace, sidebar, admin access
  and existing installer-pricing regressions. TypeScript and changed-file lint pass.
- Production Next.js build and TypeScript: PASS, 27 routes including /ai. First
  sandboxed attempt failed with Windows EPERM creating a generated segment
  directory. The same isolated .next-ai-core build succeeded with elevated file
  permissions. The pre-existing next-env.d.ts/tsconfig.json contents were saved
  and restored around each build.
- Acceptance API restarted alone, /ready reports database-ready, OpenAPI includes
  /api/v1/admin/ai/status and /api/v1/admin/ai/query. Normal runtime not restarted.
- Browser RU/HE verification: 2 Playwright tests passed (21.6s), production build
  served on separate localhost port 4191 with mocked API responses. Verified
  question submission, language, source destination, Hebrew RTL and no horizontal
  overflow at 390px. Both screenshots inspected: readable controls/source cards,
  no clipping/overlap, correct Hebrew direction. Playwright
  stopped its owned preview server. Existing next-start/standalone and terminal
  color warnings do not certify a production launch configuration.
- Final git diff whitespace checks pass across the workspace/backend/web repos.

## Remaining work and release limits

User authorized reusing an existing OpenAI key. Presence checks found no key in
local project env files, Windows process/user/machine variables, Codex API-key
configuration, or the normal backend runtime. No new key was created; no secret
copied; no real OpenAI request.
Model tests use scripted responses/HTTP transport mocks. They validate application
mechanics and access boundaries, not model quality or prompt-injection resistance
of a real model. Real-model evals and account/model access checks remain required.

Step 2 adds persistent tasks/conversations and replay protection. Subsequent
steps add authorized mutations, approvals, installer AI, operational workflows,
events, approved knowledge and live pilot. Process-local throttling is not a
distributed budget. Browser cancellation stops waiting, not a server task; all
current tools are read-only and have bounded execution.

No production deployment, external notification, normal-business DB mutation,
price recalculation, Git push or full-release readiness claim.
