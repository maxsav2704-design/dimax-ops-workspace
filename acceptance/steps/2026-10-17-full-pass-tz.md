# Full pass of the application and the admin against the product description (2026-10-17)

Owner's request: go through the whole application and the admin against the product description (the "ТЗ" text of 2026-10-17: factory prices, one company price list, new version with a reason, factory confirmation by personal link + mailbox code, confirmation ≠ activation, installer never sets a price or an earned amount, server computes sums, offline work paid at the price confirmed at execution time, immutable earnings, addons planned by the office, issues managed by the office, attention scale, no warehouse / purchasing / logistics, sync with idempotency + outbox + cold resync, roles and company isolation, reports and dashboard, admin rule system, RU/EN/HE + RTL), find defects, fix them with regression tests. Permission to change and add code given in chat.

Method: four read-only code studies in parallel (backend pricing/earnings, backend access/issues/reports, mobile, admin web), then verification of each finding by me (test or code), minimal fix, regression test, commit per block. Marks: **confirmed by tests**, **studied by code**, **not verified**, **needs external infra**.

Untouchable: the other agent's uncommitted files (AI module in backend/admin, `AppSidebar.tsx` lines, `docker-compose.demo.yml`, `DIMAX_AI_PLAN.md`, the two AI acceptance docs).

## Blocks

| # | Area | Status |
|---|---|---|
| 1 | Backend: price list, earnings, addons, idempotency | in progress |
| 2 | Backend: access control, tenancy, issues, doors, reports, audit/outbox, migrations | in progress |
| 3 | Mobile: installer rules, offline queue, issues, addons, earnings, isolation, i18n | in progress |
| 4 | Admin web: route protection, dead tools, price list UI, ledger UI, projects actions, issues, reports, i18n, installer cabinet | in progress |
| 5 | Live checks in the browser on the demo stack | pending |

## Findings and fixes

(filled per block below)

### Block 3 study result: mobile (read-only study, 2026-10-18 00:10)

Holds: no price/amount in any outgoing payload (only `price_list_id` as a version stamp, server whitelists fields); idempotency key + `happened_at` captured at action time, retry keeps the key; cold resync refused while unsent work exists; per-user SQLite files, logout keeps the other user's queue invisible; earnings read-only.

Defects to verify and fix (ranked by the study):
M1 addon facts allowed for unplanned types (mobile picker LEFT JOIN `projects/repository.ts:250-266`, service only checks the type exists `sync/service.ts:1531-1537`; backend `addons/application/use_cases.py:413-470` accepts and prices them).
M2 stale/future cached `price_list_id` → server `CONFLICT_FACTORY_PRICE`, event BLOCKED, door cannot be re-marked (`prices/repository.ts:24-27`, `sync/service.ts:1485-1494`).
M3 not-installed reason pre-selected to the first catalog entry (`app/project/[id].tsx:175-177`).
M4 status bar hides sync failures (`sync/status.ts:37-44`, `sync/presentation.ts:55-61`, `AppProviders.tsx:180-194`).
M5 office-closed issues disappear after a project refresh (`projects/repository.ts:89,140-147`; backend returns open issues only).
M6 RTL direction only on the sync-queue screen; login/projects/project/earnings/issues/profile roots have none.
M7 untranslated error text (`login.tsx:88`, `sync-queue.tsx:213`, `AppProviders.tsx:266`, missing `sync/messages.ts` entries for `service.ts:1581-1586`).
M8 issue title = localized category label, effectively mandatory (`app/issues.tsx:112-117,196,206-208`).
M9 whole-batch rejection blocks a door event without reverting the optimistic door (`service.ts:1323-1325, 367-382`).
M10 `client_event_id` is not a UUID (`service.ts:57-59`).
M11 earnings freshness hint without a timestamp; M12 earnings totals re-summed on the client; M13 last-sync time without a date; M14 stale reasons never removed outside a cold resync.
Web-only flows: issue comment PATCH, issue media, server-side sync-queue view.

### Block 4 study result: admin web (read-only study, 2026-10-18 00:12)

Holds: every admin/installer page behind `RequireAuth` with the right scope; price list page enforces a reason, shows factory confirmation separately from activation, never edits a confirmed version, rejects a zero price and renders an empty price as "—"; ledger has no edit/delete, correction is a new record with a server-computed amount; door actions and bulk assignment call the server and refresh; installer cabinet sends quantity only.

Defects to verify and fix (ranked by the study):
W1 Issues "apply to filtered" sends the selected issue's whole edit (details, due date, owner) to every visible issue without confirmation (`IssuesPage.tsx:776-795, 827-857, 1636-1651`).
W2 installer web cabinet: not-installed reason and comment shared across door cards and pre-selected (`installer/ProjectPage.tsx:270-271, 660, 1704-1756`).
W3 expired session not detected while on a page (`RequireAuth.tsx:81-140`, `use-auth-session.ts:50-62`).
W4 ledger shows missing values as 0.00 ILS and sums money in the browser (`EarningsLedgerPage.tsx:109-114, 431-434, 570-571`).
W5 dashboard revenue/payroll shows "0 ILS" for null, no rates-permission gate (`Index.tsx:135-137, 443-448`).
W6 addon null client price shown as 0, plan totals computed in the browser (`AdditionalWorksCard.tsx:381-383, 492-494`; `ProjectsPage.tsx:961-977`; `ProjectPlanFactSection.tsx:47-101, 565, 641`).
W7 literal `${...}` in RU/HE strings (`IssuesPage.tsx:804-810`; `OperationsPage.tsx:1711-1927`).
W8 reports mark-read and outbox retry fail silently (`ReportsPage.tsx:586-628`).
W9 reasons / door types hard-deleted without confirmation (`CatalogCrudPage.tsx:240-249, 689, 780`).
W10 issue status and workflow can contradict; closing needs no note (`IssuesPage.tsx:249-286, 1474-1529`).
W11 issues have no link to project/door (`IssuesPage.tsx:1210, 1310`).
W12 installer home swallows 401/500 as "no data" (`installer-api.ts:220-222, 123`).
W13 correction error not shown inside the dialog (`EarningsLedgerPage.tsx:842-857`).
W14 ledger raw untranslated types (`EarningsLedgerPage.tsx:584, 594, 890, 893, 1064, 1067`).
W15 arrows not flipped in Hebrew (calendar, installer back links); W16 left/right classes in views; W17 hard-coded English strings (list in the study).
W18 `/documents` falls back to dashboard permissions (`admin-access.ts`, the other agent's file: report only).
W19 no refresh after a failed door status action; `loadLayout` clears error banners (`ProjectsPage.tsx:1990-2004, 2081-2095, 1384`).
W20 admins cannot comment on issues; only 4 comments shown (`IssuesPage.tsx:1352`).

### Block 1 study result: backend pricing / earnings / addons / idempotency (read-only study, 2026-10-18 00:20)

Holds on the factory path: no edit route for price lists, each change is version latest+1 with a mandatory reason; the link alone never confirms (code required, sealed, attempt/resend limits); confirmation only sets CONFIRMED, activation is a separate OWNER/OPERATIONS endpoint with preflight blockers; one active version (activation constraints); a missing factory price raises instead of inventing one; installer request schemas forbid price/amount fields, sync payloads are whitelisted, the device `price_list_id` never selects a price; quotes select by execution time (`activation_at(performed_at)`), work across an activation boundary is held for admin review; no update/delete path for `completed_work`, corrections append REVERSAL + CORRECTION; sync v2 dedupes on `(company_id, client_event_id)`.

Defects to verify (ranked by the study):
P1 legacy installer rates (pre-activation mode) edited/deleted in place, no reason, backdating allowed (`installers/application/rates_admin_service.py:81-93`, `rates_schemas.py:27-29`).
P2 pre-activation work priced at the first CONFIRMED list, possibly never active (`timeline_service.py:135-151`), asserted as intended by tests.
P3 legacy mode does not validate execution time (`sync/application/service.py:809-819`, addon `done_at` not clamped).
P4 unplanned addon facts paid automatically in factory mode, no qty cap (`addons/application/use_cases.py:99-101, 414-418`) = mobile M1.
P5 legacy addon earnings priced at plan-write time with retroactive reconcile.
P6 no DB immutability trigger for ordinary `completed_work` / `factory_earning_prices`; ON DELETE SET NULL on earnings foreign keys.
P7 online addon fact without `client_event_id` duplicates on retry (`addons/api/installer_schemas.py:17`).
P8 invented zeros: plan `installer_price` 0 (`addons/application/pricing.py:35`), addon default price 0, client price `or "0"` (`doors/application/completion.py:128`, project import).
P9 no DB triggers on confirmed price lists/items/activations (runtime hash checks only).
P10 report legacy-rate scalar subquery without effective_from/ORDER/LIMIT (`reports/infrastructure/repositories.py:3785-3791, 2511-2513`).
P11 factory mailbox is owner-declared and the admin receives the confirmation URL.
P12 door client `our_price` visible to VIEWER/FINANCE in project detail without the rates capability (`projects/api/admin.py:439-454`).
P13 legacy rates accept price 0. P14 batch `entity_id` never checked against `payload.door_id`. P15 admin override INSTALLED records server time; reversal reason optional.

### Block 2 study result: backend access / issues / doors / reports / audit / migrations (read-only study, 2026-10-18 00:25)

Holds: every admin router behind `require_admin` (OWNER-only settings, writes OWNER/OPERATIONS, read prefixes), installer routers behind `require_installer` + installer id, repositories company-scoped, factory confirmation token hashed with expiry/revocation/contact/snapshot checks, code HMAC with limits; door structure and marking/type/installer fields; not-installed requires an active catalog reason; photo/signature not enforced; outbox drained by a worker with SKIP LOCKED and backoff; single Alembic head 0075.

Defects to verify (ranked by the study):
A1 system risk issues (SYNC_RISK / DELIVERY_OUTBOX_RISK) attached to an arbitrary first door; collide with the door's one issue slot (IntegrityError inside a GET) or get overwritten / closed by the installer (`issues/infrastructure/repositories.py:211-300`).
A2 GET dashboard / reports run `SyncHealthService.run_for_company` (writes + blocking httpx.post) even for VIEWER/FINANCE.
A3 report aggregates fan out when an installer has several legacy rate versions (unbounded rate join, ten places).
A4 installer re-report resets office triage (workflow, priority, owner, details) (`issues/application/installer_api_service.py:124-131, 192`).
A5 installer install closes office-managed issues (tested as intended) — product decision.
A6 direct install / sync skip IN_PROGRESS — intended for the mobile flow (not a defect).
A7 zero accepted as client price. A8 project update/delete, assignment, admin install/not-installed, calendar/library/documents/addons not audited. A9 no issue transition rules. A10 comments/media endpoints are stubs. A11 public journal endpoints unthrottled, token expiry nullable. A12 per-process rate limiter. A13 outbox batch may resend after rollback. A14 admin door endpoints 500 on malformed id. A15 cross-tenant tests cover installers/rates only.

## Fixes landed (2026-10-18, night)

| Commit | Block | What |
|---|---|---|
| admin `a8f591d` | W1, W7 | Issues bulk apply carries only status / workflow / priority / owner and asks for confirmation; literal `${...}` in RU/HE notices (Issues, Operations). |
| admin `2b9b756` | W2, W4, W5, W6, W8, W9, W11, W13, W14, W19 | Installer cabinet reason + comment per door, nothing pre-selected; catalog delete confirmation (single and bulk); ledger shows a gap instead of 0.00, no browser money sum, translated kinds, correction error inside the dialog; dashboard money tile hidden without the rates capability and never "0 ILS" for null; addon client price gap; reports mark-read / retry errors shown; issue rows link to the project's doors; door action error survives the refresh. |
| admin `14a4512` | W3 | Expired or cleared session sends the user to login (guard re-checks on auth change, hook drops a 401/403 session). |
| admin `6be0560` | W15, W16 | Logical spacing and flipped arrows for Hebrew, `scripts/rtl-utilities-ratchet.test.mjs` + baseline wired into the quality gate. |
| mobile `a6c5fdc` | M2, M3, M4, M6, M7, M9, M10, M13, M14 | Reason chosen by the installer (form opens, confirmation waits); sync failures and failed items in the status bar; last-sync date; RTL from the root stack; localized errors; UUID event ids; batch rejection reverts the door; future price list not claimed; reasons catalog replaced on hydrate. |
| mobile `fa0368e` | M1, M5, M11 | Only planned addon types offered and accepted; office-closed issues stay as CLOSED; cached earnings notice carries the computation time. |
| backend `7dcf073` | P4, P7, P12, P14, A1, A2, A3, A4, A11, A14 | Unplanned addon facts refused (direct + sync); idempotency key required on direct addon upload; door client prices only with the rates capability; batch entity_id must match the payload door; system risk issues never take an occupied door; dashboards and reports read sync health, the maintenance worker and the run endpoint evaluate it; one legacy rate version per door in reports; installer re-report keeps office triage and appends; public journal endpoints rate limited; malformed door ids are 422. |

Studied and left as designed (recorded, no change): W12 (installer home shows optional panels as "no data" by an explicit code comment, the dedicated pages show errors); A6 (direct install skipping IN_PROGRESS is the mobile flow); M12 (earnings totals on the device are view aggregates of server rows for the chosen filter, no invented money); W10 (the server already rejects a status / workflow contradiction on close, `admin_api_service.py:266-286`).

Open for the owner's decision (product rules beyond a code fix): P1 legacy per-installer rates edited in place without a reason (pre-activation mode); P2 pre-activation work priced at the first CONFIRMED list; P3 legacy mode without execution-time checks; P5 legacy addon reconcile at plan-write time; P6/P9 database-level immutability triggers for `completed_work`, `factory_earning_prices` and confirmed price lists (new migration); P8/A7 zero accepted as a client price (import default); P11 factory mailbox is owner-declared; A5 installing a door closes the office's issue (tested as intended); A8 audit coverage of project update/delete, assignment and admin door actions; A9 issue transition rules beyond the close check; A10 comments/media endpoints are stubs (W20 depends on them); A12 per-process rate limiter; A13 outbox resend after a batch rollback; A15 cross-tenant tests for more modules; W18 `/documents` permission mapping (the other agent's file); the full hardening of A1 needs a schema change (system risk as a project flag, not a door issue).

### Closing (2026-10-18, 01:40)

| Commit | What |
|---|---|
| backend `4c036b6` | P10: the legacy-rate scalar subquery in issues/addons impact picks the one version in force (three versions used to raise a cardinality error). |
| admin `29a3fd3` | Issue filter selects translated (seen live still showing codes), ledger quantity shown as a count instead of "1,00 ILS" (seen live), DimaxFoundations test aligned with the retrofitted tile (the only red test in the full suite). |

Block 5, live checks in the pane on the demo stack (dev server 4173, demo api 8000): Issues page renders with the bulk button "Применить к отфильтрованным (20)" and the confirmation flow; the live data shows SYNC_RISK issues sitting on real doors (A1 as found, the new code only prevents new collisions, existing rows stay until the health run moves on); Earnings ledger shows translated kinds, no browser sum, counts as numbers; Price list page loads (no versions on the demo company: the factory contact / confirmation / activation chain could not be exercised live, it is confirmed by the backend tests listed in block 1).

Final state: admin full Vitest 620 green (79 files), both ratchets green, tsc and eslint green on every touched file; mobile 844 green; backend 194 + 151 + 38 green across the touched integration files plus 167 architecture tests. Not verified: production build of the admin after this pass (`npm run build`, heavy on this host), the mobile changes on a physical device (RTL root direction, status bar, planned-only picker), the maintenance worker's sync-health loop against a live stack (studied by code, unit of work per company).

## 16. The decision list, taken on (2026-10-18, owner: "yes, take on the decision list")

| Item | Decision | Commit |
|---|---|---|
| P6 / P9 immutability in the database | **Done.** Migration `0076_ledger_immutability`: `completed_work` cannot be deleted, its money / identity columns cannot change (a parent delete may still detach a foreign key); `factory_earning_prices` and `factory_price_activations` are read-only; items of a confirmed list cannot change; a confirmed list cannot be deleted. Test teardown runs below the triggers. A project with recorded earnings cannot be deleted (409, archive it). | backend `5e5c4bc` |
| P1 legacy per-installer rates edited in place | **Done.** A version already in force is history: no edit, no delete (single and bulk, 409); the office adds a new version with a later `effective_from`. Future versions stay editable. Admin UI tests adjusted to future versions. | backend `5e5c4bc` |
| P3 legacy execution-time checks | **Partly.** Addon `done_at` is clamped to the server receipt in legacy mode too (doors already were). The assignment-boundary / historical review machinery stays factory-mode only: in legacy mode there is no price timeline to review against. | backend `5e5c4bc` |
| P8 / A7 zero as a client price | **Done as a counter, not a rejection.** Factory sheets are imported without prices, so 0 stays storable; the KPI carries `zero_client_price_installed_doors` and the dashboard money tile names the count, so revenue 0 is never read as real revenue. | backend `5e5c4bc`, admin `de0d34a` + `b3b3913` |
| A8 audit coverage | **Done** for project update / delete, bulk assignment, admin install / not-installed, issue comments. | backend `5e5c4bc`, `48e42d5` |
| A13 outbox resend after rollback | **Done.** The worker commits each message's outcome on its own (single-worker deployment noted in code). | backend `5e5c4bc` |
| A10 / W20 comments | **Done.** Migration `0077_issue_comments`; admin and installer list and add comments on issues they may see, audited; the admin issue panel has a comment box; media endpoints stay stubs (no media store). | backend `48e42d5`, admin `9b4f2ed` |
| A15 cross-tenant tests | **Done** for projects, door layout, admin door install, issues and comments. | backend (test commit after `48e42d5`) |
| P2 pre-activation work priced at the first CONFIRMED list | **Kept.** The admin review path (`HISTORICAL_PRICE_REVIEW`) decides such work; three tests document the design. Changing it means re-deciding how the company moves from legacy rates to factory prices, which is a product change, not a defect. |
| P5 legacy addon reconcile at plan-write time | **Resolved by P4.** Facts without a plan are refused, so a later plan has nothing to reconcile for new data. |
| P11 factory mailbox owner-declared, admin sees the invitation URL | **Kept.** Confirmation needs the code from the factory mailbox; the link alone never confirms (`test_link_alone_never_confirms`). The owner approving the contact is the authority step. |
| A5 installing a door closes the office's issue | **Kept.** The physical blocker is gone when the door is installed; the office sees it in the issue history. |
| A9 issue transition rules | **Kept** (the server already refuses a status / workflow contradiction on close). |
| A12 per-process rate limiter | **Kept.** The public flows are additionally bound by codes, tokens and attempt counters stored in the database. |
| W18 `/documents` permission mapping | **Not touched**: `admin-access.ts` is the other agent's file in progress. |
| A1 system risk issues on a door (schema change) | **Deferred, mitigated.** New collisions are prevented (deterministic free door or none). Moving system risk to a project-level flag touches ~40 door-bound issue usages (lists, health, reports) and needs its own migration block; existing SYNC_RISK rows on the demo project stay until the health run moves on. |

Checks: backend 274 + 235 + 82 + 5 + 18 green across the touched integration and architecture files on a test database migrated to 0077; admin IssuesPage / IndexPage green, tsc, eslint; not verified live: the comment thread in the browser (dev server picks it up on the next load), the maintenance worker loop, the demo database migration to 0076/0077 (the demo api applies migrations on restart; 0076 is idempotent for an ORM-built database).

## 17. System risks moved from doors to the project (2026-10-18, owner: "take on the move")

| Commit | What |
|---|---|
| backend `ce6040b` | Migration `0078_project_risks`: one row per project and kind (SYNC, DELIVERY_OUTBOX) with status, details, opened / closed time; existing SYNC_RISK / DELIVERY_OUTBOX_RISK issues are moved and removed from `issues`. `ProjectRiskRepository` on the unit of work; the sync health run and the delivery webhook open / close risks idempotently and recalculate project health; audit entries point at the risk. Project health: an open risk puts the project AT_RISK, only a reported door issue BLOCKS it; completion is not held back by a system risk. Project detail returns `open_risks`. The door-bound risk code and the free-door workaround are gone. |
| admin (after `ce6040b`) | The facts strip under the project header shows "System risks" (warn, kinds in the detail) only when one is open; the Issues section no longer lists them as door problems. |

Checked: `test_project_risks` (danger → risk OPEN, project AT_RISK, no issue rows; recovery → CLOSED, NORMAL), repository idempotency, the outbox webhook test on the new table, 70 green across issues / sync health / dashboard / projects / lifecycle / OpenAPI / migration safety on a test database migrated to 0078; admin ProjectsPage 53 green, tsc, eslint, ratchets. Not verified live: the demo database migration (the demo api applies 0076–0078 on restart; the three SYNC_RISK rows seen live on 2026-10-18 move to `project_risks` then); the installer device after the move (it simply stops receiving those rows as door issues).

With this the decision list of block 16 has no deferred item left except W18 (the other agent's file).
