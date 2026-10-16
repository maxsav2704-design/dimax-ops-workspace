# Admin web — splitting ProjectsPage and ReportsPage into sections (plan)

Date: 2026-10-16. Repo `dimax-operations-suite-main`, branch `codex/release-hardening-20260908`.
Status: study only; no code changed. Waits for the owner's approval of the order below.

## Why

`ProjectsPage.tsx` is 13 612 lines, `ReportsPage.tsx` 9 226. Their route chunks are
316 kB and 268 kB; every state change re-renders the whole page; tests of the
Projects file take 8–10 minutes on the dev host. The C2 assessment in the pass log
shows no cheaper lever is left (dialogs are small, lists are short).

## Method (what "split" means here)

- One section = one folder `src/components/projects/<section>/` (or `reports/`) with
  `Section.tsx` (markup) and, when it owns server state, `useSection.ts` (its
  react-query entries and local UI state). The page keeps routing, the selected
  project, catalogs and cross-section notices, and passes **props in / callbacks
  out**. No context, no global store: the data flow stays visible in the page.
- Markup moves verbatim. Copy, test ids, aria names and class names do not change,
  so the existing tests keep passing and the browser checks compare 1:1.
- Server state already on react-query (details, documents, financials, import
  history, failed queue, references) moves with the section that reads it.
  `loadProjects` and `loadLayout` (still hand-rolled) stay in the page until the
  sections that depend on them are out.
- One section per commit: `tsc`, `eslint`, the section's tests + the page tests,
  then the demo stack in the browser. Route chunk sizes recorded after each.
- Strictly no behaviour change. Anything found broken on the way is a separate
  commit with its own test, as in the rest of the pass.

## ProjectsPage — section map (render lines today, state footprint)

| # | Section | Lines | Uses ids | Shared with others | Verdict |
|---|---|---|---|---|---|
| 1 | Project dialog (create/edit form) | 12364–13612 (1 249) | 39 | 11 | **First**: self-contained form state, one `onSaved` callback. |
| 2 | Door import wizard | 9257–9721 (465) | 30 | 9 | Second: owns mapping profiles, upload, analysis; emits `onImported`. |
| 3 | Import history + run details | 9722–10296 (575) | 21 | 14 | Third, together with the failed-import queue card (8883–9256, 16/5): they share the focused run. |
| 4 | Documents | 6885–7150 (266) | 14 | 4 | Own query already; trivial. |
| 5 | Urgency surcharges | 7571–7846 (276) | 7 | 3 | Own query; trivial. |
| 6 | Additional works | 7265–7570 (306) | 14 | 9 | Own query; shares pricing mode and references. |
| 7 | Financial screen (plan/fact, risk) | 7847–8512 (666) | 8 | 6 | Own queries; read-only. |
| 8 | Project details card + side widgets | 6504–6884, 6267–6503 | 8 + 13 | 5 + 10 | Read-only; props from `projectDetails`. |
| 9 | Import layout check | 12149–12363 (215) | 4 | 4 | Trivial. |
| 10 | Bulk reconcile / bulk import review cards | 8513–8882 (370) | 7 | 6 | After 3. |
| 11 | Door ledger | 11727–12148 (422) | 20 | 15 | After the matrix; shares selection and filters. |
| 12 | Door workspace (command) | 5445–6266 (822) | 40 | 37 | **Last**, with 13: the two share selection, filters, focused door and the layout. |
| 13 | Door matrix + focused door panel | 10297–11726 (1 430) | 71 | 40 | **Last**. Candidate for its own hook `useDoorWorkspace` holding selection/filter state that 11, 12 and 13 share. |
| — | Header, portfolio, list, catalogs notices | 4700–5444 (745) | 57 | 21 | Stays in the page (it *is* the page). |

Identifiers used by many sections and therefore passed as props everywhere:
`projects`, `tokenLabel`, `canManageProjects`, `canViewProjectRates`, `selectedProjectId`,
`formatMoney`, `error`. 332 component-scope identifiers in total.

Expected result after 1–10: the page drops to roughly 6 000 lines and the remaining
weight is the door workspace, which is one coherent feature and gets its own folder
in 11–13.

## ReportsPage — section map

Every report section is loosely coupled: 4–25 identifiers each, 1–8 shared, and the
shared ones are page-level flags (`canExportFinancialReports`, `canRunPrivilegedActions`,
`readError`, scope hints). Each section owns its query. Proposed order, simplest first:

| # | Section | Lines | Uses / shared |
|---|---|---|---|
| 1 | Operations center | 3833–4019 | 5 / 2 |
| 2 | Issues analytics | 4263–4426 | 4 / 2 |
| 3 | Installer profitability matrix | 6193–6666 | 4 / 2 |
| 4 | Installer cross view | 6667–6937 | 4 / 3 |
| 5 | Installers KPI | 6938–7206 | 4 / 3 |
| 6 | Project margin executive | 5899–6192 | 5 / 1 |
| 7 | Issues add-ons impact | 4427–4802 | 5 / 2 |
| 8 | Failed outbox | 8482–8714 | 7 / 5 |
| 9 | Project risk drilldown | 5516–5898 | 8 / 4 |
| 10 | Installer details | 7413–7877 | 9 / 3 |
| 11 | Operations SLA | 4020–4262 | 11 / 2 |
| 12 | Order numbers KPI + orders | 7207–7412, 7878–8165 | 12 / 5, 16 / 8 |
| 13 | Delivery risk + scope | 8166–8481 | 16 / 7 |
| 14 | Audit catalogs, issue audit | 8715–8890, 8891–9226 | 17 / 5, 25 / 6 |
| 15 | Project plan-fact | 4803–5515 | 17 / 4 |
| — | Dashboard v3, toolbar, notices/focus | 3396–3832 | stay in the page |

Reports is the better place to start: every step is small, mechanical and verifiable
by its existing section tests, and after 15 steps the page is a thin shell with the
dashboard, toolbar and focus handling.

## Proposed order of work

1. Reports sections 1–7 (one commit each, ~200–500 lines moved per commit).
2. Projects 1 (dialog) and 2 (import wizard): the two biggest self-contained blocks.
3. Reports 8–15.
4. Projects 3–10.
5. Projects 11–13 as one feature folder with a shared `useDoorWorkspace` hook; this
   step gets its own mini-plan once 1–4 have shown the real state boundaries.

Each commit's gate: `tsc`, `eslint`, section + page tests, discovery contract,
browser check on the demo stack, route chunk size noted in the pass log. Full
`npm run test` and `npm run build` after steps 1, 2, 3, 4 and 5.

## What this does not do

No visual or copy changes, no new state management library, no change of API calls
or query keys, no change to deep links or test ids. Behaviour fixes found on the way
are separate commits.
