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
