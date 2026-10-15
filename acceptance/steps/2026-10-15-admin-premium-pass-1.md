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

- i18n: Operations status pill "System degraded · 1 incidents" and tile
  labels ("Sync queue pressure", "fresh", "n/a"), Issues tiles ("SLA
  BREACHED", "DUE TODAY", "1 P1 in current scope", "within 24h window"),
  login error "Invalid credentials" all stay English in RU.
- Money: Reports shows "16 970,00 NIS"; Ledger "Сумма на экране 2 000,00"
  has no currency; dashboard now says ILS. Item B4 next.
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
