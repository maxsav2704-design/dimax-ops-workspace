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
