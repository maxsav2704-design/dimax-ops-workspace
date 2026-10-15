# Admin Web Audit (dimax-operations-suite-main), 2026-10-15

Read-only pass over the Next.js 16 / React 18 / TypeScript / Tailwind admin
at repo `dimax-operations-suite-main` (branch
`codex/release-hardening-20260908`, HEAD `3903abe`). Nothing was changed.
The other agent's uncommitted work (AI page, sidebar, admin-access, tsconfig)
was not touched and is excluded from the findings. Method: own reading of the
shell, tokens and the largest views; `tsc --noEmit` (exit 0); three parallel
read-only sweeps (architecture, visual, quality) whose high-severity claims
were re-verified by hand. Numbers are grep counts over `src/`, `app/` without
tests.

## Scale

84 k lines of TypeScript, 27 routes, 189 source files, 73 test files
(26 of 28 views have a direct test). Seven view files hold 40 % of the code:
`ProjectsPage.tsx` 13 509 lines (one component of ~12 k lines, 104 `useState`,
45 `useMemo`, 15 `useEffect`, 0 `useQuery`), `ReportsPage.tsx` 9 272 (27
`useQuery`), `OperationsPage.tsx` 4 064, `JournalPage.tsx` 1 919,
`installer/ProjectPage.tsx` 1 869, `IssuesPage.tsx` 1 709, `CalendarPage.tsx`
1 547.

## What is solid (keep)

- One API client (`src/lib/api.ts`): typed `apiFetch`, single-flight refresh
  on 401, network errors normalised, error codes mapped to copy in
  `api-error-display.ts`. Only 3 raw `fetch` calls outside it (public pages).
- Scope matrix in `admin-access.ts` (OWNER / OPERATIONS / FINANCE / VIEWER),
  privileged actions gated in most mutating views.
- Design tokens: `--dmx-*` CSS variables for surfaces, text, status, KPI,
  radii, motion and z-index; light and dark sets; Tailwind mapping; a
  `text-11..24` scale; status colours centralised in `status-tokens.ts`.
  Hardcoded Tailwind palette classes in components: 55, hex literals: 201,
  mostly in the calendar surface and public pages.
- RTL: `<html dir>` set before hydration; logical classes dominate
  (`ms/me/ps/pe` 120, `text-start/end` 346 vs physical 21). `LtrText` for IDs.
- Radix `Dialog`/`AlertDialog` used 118 times; lucide is the only icon set.
- Hygiene: 0 `any`, 0 `@ts-ignore`, 0 `eslint-disable`, 0 TODO, 1 console.
- Tests: ProjectsPage 36, PriceLists 18, Reports 18, Operations 15; mocked
  Playwright specs for the factory-price flows; `tsc` clean.

## Findings by area (evidence)

### A. Architecture and data
A1. Two server-state systems. 12 views use react-query; `ProjectsPage`,
`JournalPage`, `JournalFormPage`, `DimaxAiPage`, `LoginPage`, `RequireAuth`,
`AcceptancePage` and `hooks/use-reference-list.ts` run their own
`useEffect` + `useState` loaders (about 70 `apiFetch` calls) with hand-made
`loading*/loaded/error` flags (`ProjectsPage.tsx:1596-1718`, loaders
`2766-3051`). `OperationsPage` has 9 queries but mutates imperatively and
then calls `.refetch()` on all nine (`1598-1608`).
A2. No query-key factory; same endpoint cached twice: `/outbox/summary` as
`["outbox-summary"]` (`ReportsPage.tsx:2010`) and
`["operations-outbox-summary"]` (`OperationsPage.tsx:1110`); `/auth/me` under
`["auth-me"]`, `["legacy-auth-me"]` and uncached in `RequireAuth.tsx:101`,
`LoginPage.tsx:43`.
A3. `QueryClient` has no defaults (`AppProviders.tsx:12`): staleTime 0,
refetch on window focus on; only 2 `staleTime` in views. Reports alone has
27 queries, so one tab focus refetches ~27 endpoints; Operations, Documents
and the sidebar poll every 30 s.
A4. No runtime validation: `api.ts:205` casts JSON to `T`; `zod` is a
dependency imported nowhere.
A5. No error boundary anywhere: no `error.tsx`, `global-error.tsx`,
`loading.tsx` (`find app` = 0); a render exception blanks the app.
A6. About 20 of 28 bare `catch {}` blocks swallow failures and show empty
data instead of an error (`ProjectsPage.tsx:2824-3016` x9,
`installer-api.ts:120` `safeOptionalFetch`, `IssuesPage.tsx:294,307`,
`AppSidebar.tsx:260`).
A7. Access gap: `/documents` is not mapped in `pathToAdminModule`
(`admin-access.ts:99-143`, falls back to "dashboard"), the sidebar tags it
`module: "projects"` (`AppSidebar.tsx:165`), and `DocumentsPage.tsx` has
zero scope checks while owning 5 mutations: VIEWER can reach the write
actions.
A8. `RequireAuth` re-calls `/auth/me` and blanks the screen on every
pathname change (`RequireAuth.tsx:89,146`); `DashboardLayout` is mounted
inside 15 views instead of the route layout, so the sidebar remounts on
each navigation. Refresh token sits in `sessionStorage` under two keys
(`auth-session.ts:23,74-78`); no server-side guard (no middleware/proxy).
A9. Five i18n mechanisms: the 2 691-line catalog, per-page override
dictionaries, 46 inline `(en, ru, he)` helpers (~1 670 calls), 229
`locale === "ru" ? ...` ternaries, and separate `copy.ts` files. Untranslated
notices exist (`InstallersPage.tsx:470,506...` "Installer created.",
`DocumentsPage.tsx:349`, `Index.tsx:127` " NIS", `EventControlPanel` RU-only
toasts).
A10. Duplicated helpers: `formatDateTime` x10, `formatDate` x3, money x4
(ILS / NIS / bare / browser locale), `downloadBlob` x4, `AuthMeResponse`
type x4, `MetricRow` and `WidgetCard` x2; `src/lib/formatting.ts` is used by
13 files only.
A11. Legacy and dead code: Vite SPA (`src/App.tsx`, `main.tsx`,
`index.html`, `vite.config.ts`, `tsconfig.app.json`, `dev:vite` scripts,
`react-router-dom`), `pages/_document.tsx`, `NavLink.tsx`,
`EventControlPanel.tsx`, `InspectionTable/MasterCircle`,
`ProblemProjectsTable` (tested, unused), `TopReasonsCard`, 29 unused
`ui/*` files, dead deps (recharts, zod, sonner usage, date-fns, ...).
`@typescript-eslint/no-unused-vars` is off; `tsconfig` `strict: false`.
A12. Build: `next.config.mjs` has no `headers()` (no CSP, frame-ancestors,
Referrer-Policy, nosniff), `poweredByHeader` not disabled; public signing
token travels in the URL path (`app/acceptance/[token]`) while the price
approval correctly uses a `#hash`.

### B. Visual and UX (premium gap)
B1. Type scale ignored: 1 448 arbitrary `text-[Npx]` classes across ~23
values (12 px x397, 13 px x350, 11 px x341, 10.5 px x103, 10 px x87) plus
`text-xs/sm/lg...` x470; the `--dmx-text-*` scale is used 20 times. Five
different page-title styles (`dmx-page-title` 22 px; Index/Reports 26 px;
Operations 24 px; Issues 30/38 px; JournalForm `text-lg`); Calendar's only
h1 is the month name. `* { letter-spacing: 0 !important }` (index.css:237)
kills 22 `tracking-*` classes; h1-h4 `line-height: 1.08` is tight for
Cyrillic/Hebrew.
B2. No shared page frame: `DimaxPageHeader` used by 7 of 16 views; 8 views
hand-roll headers; Operations (`2150-2165`) and Reports (`3400-3413`) draw a
second "DIMAX / DIMAX GROUP" brand bar inside the page with 14 px radius and
shadow, against the design rules.
B3. States: `ui/skeleton` used once, `ui/card` never; loading states are
plain text in every view (layout jumps); no shared EmptyState; 14 per-page
`*NoticeClass` banner helpers; `DataStateNotice` (good) used in 2 views.
B4. Formatting: money shown as "ILS", "NIS", bare numbers and
browser-locale `Intl.NumberFormat(undefined)` (`EarningsLedgerPage:106`);
dates via `toLocaleString()` ignoring the app locale in 7 views.
B5. Focus ring nearly invisible: global `*:focus-visible` is a 1 px accent
at 0.22 alpha plus 4 px at 0.12 (index.css:258-263); three different focus
treatments across button, calendar and price lists.
B6. Controls: 317 raw `<button>` vs 124 `<Button>`; two button systems with
different heights (`ui/button` h-10 vs `.dmx-*-action` h-8) plus unused
`PillButton`/`FabButton`; 78 raw `<select>` vs 15 `<Select>`; `ui/badge`
imported 0 times, three local Badge/BoolBadge copies, ~67 inline pill spans.
B7. Tables: 37 raw `<table>` (Reports 17, Projects 13) with 4 header styles
and 6 padding densities; sticky header only in Projects and the calendar.
B8. Token bugs: `.text-accent { !important }` override (index.css:767)
renders dark amber instead of the brand yellow; `bg-app` used in
`OperationsPage.tsx:2152,2154` does not exist in Tailwind; shadows mostly as
literals; `CalendarScheduleSurface.tsx` carries 179 hardcoded colours (its
own event palette, lines 121-140).
B9. Feedback: two toast systems mounted, `toast` called only in dead code
(RU-only); success is inline banners; `InstallersPage.tsx:1023,1069`
hand-rolled modals (no role/focus trap/Escape); `window.confirm` in
`PriceListEditor.tsx:39`; page-mount `motion-stagger` 520-620 ms that the
calendar cancels inline.
B10. Theme/brand: dark tokens exist but are unreachable (no provider,
`color-scheme: light`, 0 `dark:` classes), and the dark `--dmx-*` greys
contradict the navy shadcn dark vars; the web palette (light grey, yellow
`#ffc83a`, link `#2b7fff`) and the mobile palette (`#080E15`, gold
`#E4B24E`, blue `#338EFF`) are unrelated. Mobile sidebar collapses to a
48 px icon rail without tooltips or a drawer; Google Fonts via CSS `@import`
(render-blocking) instead of `next/font`.

### C. Accessibility, performance, tests
C1. ~41 of 258 form controls without a programmatic label; 95 of 177 labels
without `htmlFor` (`InstallersPage.tsx:266-330` x12, `ReportsPage` x13); one
icon-only button without a name (`ProjectsPage.tsx:6995`); heading skips in
Journal/Settings; double h1 in EarningsLedger; no skip link; no jsx-a11y.
C2. Door ledger renders every door twice (mobile cards `ProjectsPage:11736`
and desktop table `:11913`), unpaginated; reference lists load up to 500
rows; no `useDeferredValue` on search; no `next/dynamic`.
C3. Tests: no coverage tooling; `example.test.ts` placeholder; NotFound and
ReasonsPage untested; `AcceptancePage` has one happy-path test;
`run-vitest-gate.mjs` isolates Documents/Operations/Projects tests (memory).
C4. E2E: CI runs 4 of 8 mocked specs; no e2e for project import
apply, earnings corrections, journal mark-ready / acceptance signing;
`playwright.config.ts` `retries: 0` + `trace: "on-first-retry"` means traces
are never saved. `QUALITY_GATE.md` is stale versus the real script.

## Proposed blocks (each: minimal additive change, regression test, browser check, own commit)

Block 1 - Safety foundations (small, high value, no visual change):
security headers + `poweredByHeader: false`; `QueryClient` defaults
(staleTime 30 s, no focus refetch, opt-in for live queries);
`app/global-error.tsx` + `app/(admin)/error.tsx` + installer error.tsx;
`/documents` mapped in `pathToAdminModule` + VIEWER gating in DocumentsPage;
`trace: "retain-on-failure"`; shared `["auth-me"]` key in RequireAuth/Login.

Block 2 - Premium design foundation (tokens and primitives first, then page
by page): map Tailwind `text-xs/sm/base/lg` to the `--dmx` scale and add
`.type-*` utilities; strong, single focus ring token; `PageShell` +
`DimaxPageHeader` with breadcrumbs/actions and one h1 style; `EmptyState`,
`TableSkeleton`/`CardSkeleton`, `InlineNotice` on top of `DataStateNotice`;
`formatMoney`/`formatDate*` wrappers + `<Money>`/`<DateTime>`; `Button`
`size="sm"` and `variant="pill"`, `.control-select`; `.data-table/*`
utilities with sticky header; calendar event tokens; remove the
`.text-accent` override and `bg-app`; motion 200 ms / 4 px. Then apply:
Dashboard, Operations, Projects, Reports, Calendar, Installers, Issues,
Journal, Ledger, Settings. Visual verification in the browser after each
page (needs the owner to sign in once in the built-in browser; no password
is read).

Block 3 - Accessibility: Installers modals to `ui/dialog`; `id/htmlFor`
pairs; `aria-label` on the refresh button; `eslint-plugin-jsx-a11y`
(recommended, warn first); heading levels; skip link.

Block 4 - Server state hygiene: `src/lib/query-keys.ts`; migrate
`ProjectsPage` loaders to `useQuery` one at a time (extract hooks into
sibling files, no rewrite); error flags instead of silent `catch {}`;
`safeOptionalFetch` swallows only 404; optional `schema?` on `apiFetch`
with zod for auth/me, pricing, earnings.

Block 5 - i18n consolidation: one exported `pickLocale(en, ru, he)`; keys
for the raw notices; test that rejects new local copy helpers.

Block 6 - Dead code and legacy Vite removal (deletions: listed explicitly,
each needs the owner's yes under the add-only rule).

Block 7 - Tests and CI: add the 3 mocked specs to CI; coverage tooling;
tests for NotFound/ReasonsPage/PriceActionDialog/PriceListEditor; error
path for AcceptancePage; e2e for ledger correction and acceptance signing.

Block 8 - Brand decision: align web dark tokens with mobile (`#080E15`,
gold, `#338EFF`) and wire `next-themes`, or keep the light yellow system as
the web source of truth. Needs the owner's call before any change.

## Not verified
Live rendering in a browser (login required); bundle size; Lighthouse;
behaviour on real data volumes; the other agent's uncommitted AI page;
ESLint result (still running at the time of writing).
