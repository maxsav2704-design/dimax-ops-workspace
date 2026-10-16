# Admin Premium Pass, Part 1 (blocks 1 and 2 foundation), 2026-10-15

Follows `2026-10-15-admin-audit.md`. All changes live in the admin repo
`dimax-operations-suite-main`, one commit per item, each with tests, `tsc`
and the type-scale ratchet green. The other agent's uncommitted files were
not touched. Browser verification ran against the local demo stack
(`docker-compose.workspace.yml`, API 8000, company DIMAX DEV, demo admin
account from the owner) with the Next dev server on 127.0.0.1:4173.

## Commits (admin repo)

| Commit | Item | What changed |
|---|---|---|
| `0eff6ad` | 1.1 / 1.6 | ESLint ignores `.next-*/**` build outputs (lint was red with 13 144 generated-file errors); Playwright `trace: retain-on-failure`; `test:repo-config` guard. |
| `b1c7a4a` | 1.2 | Security headers on every route (nosniff, X-Frame-Options DENY, CSP `frame-ancestors 'none'`, Referrer-Policy, Permissions-Policy), `poweredByHeader: false`; `test:security-headers`. Confirmed in live responses from the dev server. |
| `ab7b180` | 1.3 | `createAppQueryClient`: staleTime 30 s, no refetch on window focus; invalidation unchanged (test). |
| `48d77be` | 1.4 | `AppErrorFallback` + `app/(admin)/error.tsx`, `app/(installer)/installer/error.tsx`, `app/global-error.tsx` (en/ru/he, RTL, digest shown, raw message hidden). |
| `838962a` | 1.5 | DocumentsPage write controls disabled unless OWNER/OPERATIONS; VIEWER test. Route mapping of `/documents` deferred (admin-access.ts is in the other agent's working tree). |
| `80c1cb5` | 2.1 | Type-scale utilities `.type-*`, `.num`, `.data-table*`; `--dmx-ring-focus` (2 px gap + 2 px link ring) replaces the 0.22-alpha ring; `shadow-card/overlay/focus` tokens; headings line-height 1.2; motion 220-260 ms / 4-6 px; `scripts/type-scale-ratchet.test.mjs` with a 44-file baseline (counts can only go down). |
| `d09a5ab` | 2.2 | `EmptyState`, `InlineNotice`, `TableSkeleton`/`CardSkeleton`, `Money`/`NumberValue`/`DateTime`; `DimaxPageHeader` with breadcrumbs/meta/status slots and no stray whitespace; `ui/button` uses the shared focus token; test setup installs in-memory Storage when the host's is inert. |
| `8f58c1b` | env | `engines` node >=20.18 <21 and `.nvmrc` (this machine runs Node 25; its global Web Storage stub broke 11 `PriceReconciliationDialog` tests before the setup polyfill). |
| `a8c85e5` | 2.3 dashboard | `DimaxPageHeader`; money label "NIS" -> shared `COMPANY_CURRENCY` ("ILS"); test expectation updated. |
| `d8d89af` | 2.3 operations | In-page "DIMAX / DIMAX GROUP" bar, `bg-app` and hand-rolled breadcrumb removed; shared header with status pill and meta; "Run diagnostics" translated. |
| `6b9d540` | 2.3 reports | Same treatment for the reports cockpit; unread count as status pill. |
| `47f7be6` | 2.3 issues | 30/38 px hero inside a card replaced by the shared header; KPI grid unframed. |
| `b682f3e` | 2.3 calendar | Page title added (there was none); month name demoted to h2; `--dmx-event-*` tokens (light + dark) and Tailwind `event` colours; 0 hex literals left in `CalendarScheduleSurface.tsx` (was 179). Journal form title on the page-title class. |
| `5cc4c0a` | 3 installers | Hand-rolled overlays replaced by `ui/dialog` (role, focus trap, Escape, focus return, localized close); seven form labels paired via `useId`; tests query by label. |
| `4e2eef5` | B4 currency | Reports "NIS" literals and the ledger's bare amounts now use `COMPANY_CURRENCY` through `formatLocaleMoney`; Reports test expects ILS. |
| `6db183e` | 5 i18n operations/issues | KPI tiles on both pages localized through `copy()`; `card.label` stays the internal key, `card.title` is displayed; `compactMap` takes a localized fallback; `copy` memoized on locale so the cards memo lists it as a dependency (no lint suppression). |
| `843c3b0` | 2.4 dashboard loading | KPI tiles show `Skeleton` blocks (status, value, detail) while pending, "Loading" moved to `sr-only`; dispatcher board and next schedule get `CardSkeleton` / `TableSkeleton` so the page does not reflow. Confirmed by the loading test (5 `role=status`, no "—"/"0" in tiles); in the browser the data arrives inside the auth splash window, so the skeletons were not caught on screen. |
| `755aa24` | 2.4 list states | Issues list, Earnings ledger (mobile + table) and Library (mobile + table) use `TableSkeleton` while loading and `EmptyState` (row variant) when empty; "No issues match…" and "No due date" localized. Dashboard detail lines through `countNoun` ("1 дверь осталась", "1 занят"). Tests for the four pages pass (24). |
| `5c326a6` | 3 price editor | `window.confirm` on closing a dirty price-list editor replaced by an in-app `AlertDialog` ("Discard unsaved changes?" / Keep editing / Discard changes, RU/HE copy added); regression test covers keep → discard → no POST. |
| `b4a6130` | 2.4 notices | Library, Documents, Operations: per-page `*NoticeClass` helpers and inline icons replaced by `InlineNotice` (tone icon, `role=alert` for errors). |
| `5107126` | 2.4 notices | Settings, Earnings ledger (incl. the project-scope warning with its "Show all projects" action), Installers: same migration; the Installers read-only notice for rate viewers localized. |
| `f837662` | 2.4 notices | Calendar (4 banners + modal error) and Reports (2 errors, success, 3 warnings incl. the two scope warnings with their "Show full report" action) on `InlineNotice`; `reportsNoticeClass` kept only for the accent/muted context panels. Calendar + Reports tests: 37 pass. |
| `0acc908` | 5 i18n issues/login | Issues workflow tabs localized (Открытые / Новые / Разобранные / В работе / Заблокированные / Решённые / Закрытые); API `INVALID_CREDENTIALS` mapped to localized copy on the login page instead of the raw detail. Browser (2026-10-16): Reports scope warning renders through `InlineNotice` in RU with its "Показать полный отчёт" action. |
| `0acc908` (browser) | 5 i18n issues | Issues tabs confirmed on the demo stack in RU: Открытые 2 · Новые 18 · Разобранные 1 · В работе 0 · Заблокированные 0 · Решённые 0 · Закрытые 17; rows show "Без срока". The dev server had to be restarted twice (out-of-memory `Array buffer allocation failed`, then an orphaned process on 4173); not an app defect. |
| `601ea35` | 4 data hygiene | `safeOptionalFetch` (installer API) returns null only for 403/404/501; network, 401 and 5xx are rethrown so the installer home shows an error instead of empty data. New `src/lib/installer-api.test.ts` (8 cases). |
| `60cd121` | 5 i18n operations | New `src/lib/plural.ts` (`pluralNoun`/`countNoun` on `Intl.PluralRules`, ru one/few/many) with unit test; incident rows, integration cards, filter chips and header summary localized; Russian regression test renders the page inside `LanguageProvider` and asserts "3 инцидента" (few form), chips, cards. |

Full Vitest after `d09a5ab`: 61 + 3 isolated files, 591 tests, exit 0. Later
items ran their own files plus `tsc`; a full run is due at the end of the pass.

## Confirmed in the browser (demo stack, RU locale, 800 px pane)

- Login page unchanged; login succeeds (21 s on this host).
- Dashboard, Operations, Projects, Reports, Issues, Calendar, Installers,
  Earnings ledger, Settings, Journal, Documents all render with the same
  heading pattern: breadcrumbs or eyebrow, one page title, badge/status,
  subtitle, meta, actions. No second brand bar anywhere.
- Installers create dialog: title, close button, first field focused on
  open, Escape closes, dialog gone from the tree afterwards.
- Calendar: title "Календарь" with subtitle, month name as section
  heading, toolbar intact, grid renders.
- Security headers present on `/login` responses.

## Observed, not yet changed (queued for later items)

- i18n (done in `6db183e`, `60cd121`, browser-checked in RU): Operations
  status pill now "Система деградирует · 1 инцидент", header summary
  "1 инцидент требует внимания · 1 импорт ожидает сверки", tiles
  "Риск синхронизации / Нагрузка очереди синхронизации / 100.0% из 3
  монтажников", "н/д", "свежие"; integrations "WhatsApp / очередь
  доставки · в норме · очередь доставки чиста", "1 сбойный запуск требует
  восстановления"; Issues tiles "Нарушен SLA / 1 P1 в текущей области",
  "Срок сегодня / в окне 24 часов". Still English on those pages: Issues
  status tabs (Open/New/Triaged…), "No due date", import-row payload text
  from the API, login error "Invalid credentials" (queued in block 5).
- Money (done in `4e2eef5`): Reports and Ledger now print ILS through the
  shared formatter.
- Dashboard loading is still plain text and dashes; EmptyState/skeletons
  are not yet applied to views.
- RequireAuth shows the "DIMAX" splash on every route change (audit A8);
  very visible on this slow host.
- Dev-server artefacts on a 3.9 GB host with Docker: route compiles of
  10-20 s and one `ChunkLoadError` timeout for `app/layout.js`; not an
  app defect. The acceptance stack services I started were stopped
  (outbox-worker left running as found) to free memory; volumes intact.

## Not verified
Dark mode (not reachable yet), Hebrew pass of the new headers, mobile
widths of the admin, Lighthouse, full-suite run after the last five
commits (scheduled next).
