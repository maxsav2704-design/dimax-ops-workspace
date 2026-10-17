# Admin premium visual — study, plan and execution (2026-10-17)

Owner's brief: "take the best design skill from GitHub, draw a premium visual for every
section of the admin, strict logic, complex logical effects". First run of a new block,
so this is a study: evidence, a rule system, a mockup, and an execution plan. No code of
the admin was changed.

## 1. Skill

Installed `anthropics/claude-code` → `plugins/frontend-design/skills/frontend-design/SKILL.md`
into `.claude/skills/frontend-design/` (git-ignored). It is the consensus choice in the
2026 roundups (official Anthropic skill; the third-party "Taste", "UI/UX Pro Max",
"Impeccable" skills are style packs on top of the same idea). Its method is used below:
ground the design in the subject, a two-pass plan (tokens → review against the brief →
build), one bold element, structure that encodes information, motion only in answer to
actions, copy as design material.

## 2. What exists (evidence)

- Design system: `src/index.css` `--dmx-*` tokens (cool greys `#f4f4f6/#ffffff`, brand
  yellow `#ffc83a`, link blue `#2b7fff`, seven status pairs, KPI colours, radii 6/8/10/14,
  motion 120/180 ms, z-index scale, type scale 11–24 mapped in `tailwind.config.ts`),
  Rubik + Noto Sans Hebrew + JetBrains Mono (Google Fonts `@import`). Light only (owner's
  block-8 decision, 2026-10-16); the `.dark` block is a reserved contract.
- Premium pass 1 (2026-10-15/16) already delivered the foundation: `.type-*` utilities,
  focus ring token, `DimaxPageHeader` with breadcrumbs/meta/status, `EmptyState`,
  `InlineNotice`, `TableSkeleton`/`CardSkeleton`, `Money`/`DateTime`, calendar event
  tokens, loading states on dashboard/lists, notices migrated on 9 pages, CSP with nonces.
- Still open from the 2026-10-15 audit, section B: B6 (317 raw `<button>` vs 124
  `<Button>`, 78 raw `<select>`), B7 (37 raw tables, 4 header styles, 6 densities), B9
  (two toast systems, hand-rolled modals in Installers, `window.confirm` in the price
  editor), B10 (sidebar rail without tooltips, fonts via `@import`).
- Per-section measurement (views + their component folders, tests excluded):

| Section | Lines | Header | Skeleton | Tables | Dialogs | Radii | Text sizes | Notes |
|---|---|---|---|---|---|---|---|---|
| Главная (Index) | 1 131 | shared | yes | 1 | 0 | 4 | 11 | 19 KPI mentions, dispatcher board, next schedule |
| Проекты | 13 416 | own | no | 13 | 24 | 4 | 16 | door workspace (matrix + ledger + command bar), import wizard, financial screen; 1 sticky header |
| Календарь | 2 417 | shared | no | 0 | 3 | 5 | 8 | 10 inline styles (lane geometry) |
| Проблемы | 1 691 | shared | yes | 1 | 0 | 4 | 11 | 18 KPI mentions |
| Монтажники | 1 271 | shared | no | 0 | 10 | 2 | 6 | hand-rolled modals (B9) |
| Журнал | 1 874 | shared | no | 0 | 0 | 2 | 5 | 13 grids, 4 h2 |
| Журнал / форма | 410 | own | no | 1 | 0 | 1 | 2 | |
| Прайс-лист | 968 | shared | no | 2 | 24 | 2 | 4 | versions + compare + activation |
| Отчёты | 9 283 | shared | no | 17 | 0 | 6 | 16 | 15 sections, 2 charts, 29 KPI mentions |
| Начисления | 1 233 | own | yes | 27 | 6 | 2 | 7 | |
| Документы | 1 200 | shared | no | 46 | 0 | 3 | 4 | |
| Справочники | 1 791 | shared ×2 | yes | 48 | 24 | 2 | 5 | |
| Типы дверей | 987 | shared | no | 21 | 12 | 2 | 5 | twin of Причины |
| Причины | 987 | shared | no | 21 | 12 | 2 | 5 | |
| Операции | 4 824 | shared | no | 0 | 5 | 7 | 12 | 20 KPI mentions, 1 chart, 10 grids |
| Настройки | 847 | shared | no | 0 | 0 | 2 | 3 | |

Reading: the shell and tokens are sound; what is missing for "premium" is not more
decoration but one rule system applied everywhere (the same table, the same KPI tile,
the same density, the same place for the primary action) and a few state-driven
behaviours that make the screens feel intelligent.

## 3. Design plan (the skill's first pass)

Subject: an operations suite for a door-installation company; the admin is used by the
owner, operations and finance, several hours a day, on laptops, in RU/EN/HE. Its primary
job is to answer "what needs my decision now" and to record money correctly.

- Colour (proposal): keep the brand yellow and link blue; shift the neutrals from cool
  grey to a faint warm bias so the yellow sits naturally: canvas `#F5F4F0`, surface
  `#FFFFFF`, sunken `#EEEDE8`, ink `#17160F`, secondary ink `#6A6861`. Semantic
  colours stay the seven `--dmx-status-*` pairs. The accent is spent on exactly one
  control per screen (the primary action) and on the selected state; everything else is
  ink and neutral. **Owner decision**: neutrals warm (proposed) or unchanged.
- Type: Rubik stays (brand, Hebrew-ready). Two changes: numbers everywhere in JetBrains
  Mono with `tabular-nums` (money, versions, counts), and the display role for page
  titles at 24/1.2 semibold with normal tracking (the `letter-spacing: 0 !important`
  rule stays, so no tracked-out labels, no all-caps eyebrows).
- Layout: one page frame. Header (title, breadcrumb, status pill, meta, one primary
  action) → summary strip (KPI tiles only where numbers are the point) → working area.
  Left-aligned, content width unlimited for tables, 68 ch for prose. Panels are the only
  element with radius 14 and the card shadow; controls radius 8; chips pill. Tables are
  not cards: they sit directly on the surface with a sticky header.

```
┌ title ──────────────────────────────── status · meta · [primary] ┐
│ KPI  KPI  KPI  KPI            (only where the numbers decide)   │
├──────────────────────────────────────────────────────────────────┤
│ toolbar: filter chips · density · search              freshness  │
│ ▌row  (attention stripe)  …  tabular numbers  …   state chip     │
│   row                                                            │
└──────────────────────────────────────────────────────────────────┘
```

- The one bold element: the door matrix. It is the thing only this product has (a
  building drawn as floors × entrances, every cell a door with a state). It becomes the
  visual signature: on the dashboard as a compact "building strip" per active project,
  in Projects as the workspace, in Reports as the risk drill-down. Everything else stays
  quiet.

Review against the brief (second pass): the summary-strip-plus-table frame is the
generic dashboard default; what makes it specific here is (a) the matrix as signature,
(b) the attention logic below, (c) money typography and the immutable-earnings rule
surfaced in the UI. The warm-neutral shift and mono numerals are choices, not defaults.

## 4. Strict logic (the rule system)

R1. Surfaces: canvas (page) → surface (panel) → sunken (inputs, table header) → overlay
(dialogs). Each level has one radius, one border, one shadow. No nested panels.
R2. Hierarchy: one h1 per page (shared header), h2 for panels, no h3 in tables. Type
roles: display 24, title 18, body 14, meta 13, caption 12, data 13 mono. Nothing else.
R3. Emphasis budget: one accent button per screen; selected state uses the accent tint;
status uses semantic colours only. Yellow never means "warning".
R4. Primary action never moves: top-right of the header, and it stays in the condensed
header on scroll.
R5. State language: the seven statuses have one chip, one stripe colour and one icon
each, everywhere (projects, doors, outbox, price versions).
R6. Numbers: mono, tabular, right-aligned, currency from `COMPANY_CURRENCY`; money that
is immutable (recorded earnings) is shown with a lock glyph and never in an input.
R7. Density: comfortable/compact per table, remembered per user; row height 44/36.
R8. Motion: 180–220 ms, 4–6 px, only in answer to an action; one page-load moment per
page (the matrix fills in); `prefers-reduced-motion` turns all of it off.
R9. Empty/error/loading: `EmptyState` (what to do next), `InlineNotice` (what happened
and how to fix), skeletons shaped like the final layout. No layout jumps.
R10. RTL: logical properties only (`margin-inline`, `inset-inline`), stripes on the
start edge, chevrons mirrored.

## 5. Complex logical effects (state-driven, deterministic)

E1. **Attention ranking.** Every row of a working table gets a score from data
(overdue → 3, blocked/failed → 3, missing price → 2, unassigned → 1, stale > 24 h → 1).
Score ≥ 3 draws a problem stripe, 2 a warning stripe, 1 a muted dot; "Sort by attention"
pins them on top. The stripe is information, not decoration (R5).
E2. **Linked highlighting.** Elements carry `data-entity="installer:ID"` / `project:ID`.
Hover or focus on one occurrence highlights all occurrences on the page (KPI tile, table
rows, calendar lanes, matrix cells) with the accent tint; leaving clears it.
E3. **Condensing header.** After 120 px of scroll the header collapses to a 48 px bar
that keeps the title, the status pill and the primary action (R4).
E4. **Threshold tiles.** A KPI tile computes its tone from thresholds (ok / warning /
problem) and shows the delta against the previous period plus a 14-point sparkline; the
tone changes only when a threshold is crossed, so colour means something.
E5. **Drill with memory.** Clicking a tile applies its filter to the table below and
shows the filter as a removable chip in the toolbar; the scroll position and the chip
survive navigation back.
E6. **Price version diff.** "Compare" renders cell-level deltas (↑/↓ with amount and
percent, unchanged rows dimmed) and repeats the rule "recorded earnings are not
recalculated" next to the activation button.
E7. **Matrix logic.** Cells coloured by door state; a progress rail per floor; hovering a
floor shows the floor summary (installed / open / problems); keyboard: arrows move
between cells, Enter opens the door; the matrix fills in floor by floor on load (R8).
E8. **Freshness.** Each data panel knows its age: fresh (< 2 min) silent, stale shows
"обновлено 14 мин назад" and the refresh control, offline shows the offline notice. One
refresh control position per page.
E9. **Capability-aware controls.** Write controls render disabled with a reason tooltip
for VIEWER/FINANCE roles instead of disappearing, so the layout is the same for every
role.
E10. **Consistent confirmation.** Destructive and money-affecting actions open the same
dialog pattern (title = the verb, body = what changes and what does not, checkbox when
the rule requires a review, primary button = the verb).

## 6. Per-section proposal (same rules; what is specific)

| Section | What changes |
|---|---|
| Главная | Summary strip of four threshold tiles (open problems, doors to install this week, unassigned doors, failed deliveries) with drill (E4/E5); "building strips" of active projects (E7 compact); dispatcher board rows with attention stripes (E1); next schedule as a lane list. |
| Проекты | Workspace header condenses (E3); matrix with floor rail and keyboard (E7); ledger table on the shared data-table with density (R7); import wizard steps as a real sequence (numbering is honest here); financial screen with locked recorded earnings (R6). |
| Календарь | Lanes keep the event tokens; linked highlighting between lanes and the installer list (E2); the month name stays h2, the page title h1. |
| Проблемы | Tiles → filtered list (E5); attention ranking by due date and workflow state (E1); the issue card uses the status chip set (R5). |
| Монтажники | Hand-rolled modals → `ui/dialog` (B9); profile panel with linked highlighting into projects (E2); rates shown mono and locked where recorded (R6). |
| Журнал | Templates, delivery channels and integration snapshot as three panels on one frame; delivery status chips from the outbox set (R5); the form keeps the shared header. |
| Прайс-лист | Version list with one selected state (R3); compare = diff view (E6); activation dialog per E10 with the immutable-earnings sentence. |
| Отчёты | 15 sections in three tiers: executive (margin, plan/fact, risk), operations (SLA, outbox, delivery), people (installer KPI, cross-view, profitability). Each tier opens with tiles (E4), the rest are shared tables with E1; the two charts get grid, area fill and emphasized endpoint. |
| Начисления | One shared table (27 raw tables today); locked amounts (R6); corrections as a sequence with reasons; period chips. |
| Документы | 46 raw tables → shared table; document state chips; signing shown as a sequence (sent → opened → signed), honest numbering. |
| Справочники / Типы дверей / Причины | One catalogue frame for the three (they are near twins): search, table, side form; dialogs per E10. |
| Операции | Diagnostics tiles (E4) with freshness (E8); lanes (outbox, imports, sync health) as three panels with attention stripes; the drill-down replaces the ad-hoc "exact lanes" mode with E5 chips. |
| Настройки | Grouped forms with one save bar per group; no tiles. |
| DIMAX AI | Other agent's screen; not in scope. |
| Shell / sidebar | Rail tooltips and a drawer on mobile, `next/font` instead of `@import`; **waits**: `AppSidebar.tsx` is in the other agent's uncommitted tree. |

## 7. Execution plan (after approval)

Each block: minimal additive change, regression tests, type-scale ratchet, `tsc`,
eslint, visual brand smoke, browser check on the demo stack, own commit.

1. Foundation: neutral tokens (if approved), `.data-table` density, attention stripe
   primitive, `useEntityHighlight`, `CondensingHeader` inside `DimaxPageHeader`,
   threshold `KpiTile` with sparkline, `FreshnessBadge`, confirm-dialog pattern.
2. Главная. 3. Проекты (matrix + ledger + financial). 4. Отчёты (tiers). 5. Операции.
6. Finance: Прайс-лист diff, Начисления, Документы. 7. People and work: Монтажники,
Проблемы, Календарь, Журнал. 8. Reference: Справочники/Типы/Причины frame, Настройки.
9. Shell: sidebar and fonts, when the other agent's file is free.

Estimate: blocks 1–3 are the bulk (Projects alone is 13 k lines, already split into
components, which makes this possible); 4–8 are mostly replacing raw tables and buttons
with the shared ones.

## 8. Risks and constraints

- Light theme only (owner's block-8 decision); mobile keeps its dark gold palette; the
  two are related by the yellow, not by a shared theme.
- Changing neutrals touches every screen; it is one token edit but needs the visual
  brand smoke on all routes.
- Reports and Projects are the largest surfaces; the shared table migration is where
  regressions would hide, so each page gets its browser check before commit.
- The other agent's files (`AppSidebar.tsx`, `admin-access.ts`, the AI page) stay
  untouched; the shell block waits.
- Memory on this host: the dev server needs the acceptance stack stopped during builds.

## 9. Mockup

Interactive mockup of the direction (design rules panel + Главная, Проекты, Отчёты,
Прайс-лист with E1–E8 working): published as an artifact, link in the chat. It is a
drawing for the decision, not code of the admin.

## 10. Decisions needed from the owner

1. Approve the rule system (section 4) and the effects (section 5) as the target.
2. Neutrals: warm shift (proposed) or keep the current cool grey.
3. Order of blocks (proposed: foundation → Главная → Проекты → Отчёты → …).

## 11. Execution (2026-10-17, owner approved "do everything as you recommend")

Decisions taken: rule system and effects as the target, warm neutrals, the proposed
block order. Every block: own commit in the admin repo, tests, `tsc`, eslint and the
type-scale ratchet green; the other agent's files untouched.

| Commit | Block | What landed |
|---|---|---|
| `3e1c078` | 1 foundation | Warm neutral tokens (+ matching shadcn hsl vars). New primitives in `src/components/dimax`: `attention.ts` (E1 level from data, `data-attention` + stripe CSS for tables and rows), `useEntityHighlight` + `entityKey` (E2, delegated document listeners, `.is-linked`), `DimaxPageHeader` `condensedAction` with the sticky 48 px bar after 120 px (E3, `useScrolledPast`), `KpiTile` + `kpi-logic.ts` (E4 tone from thresholds up/down, delta, sparkline geometry, E5 toggle), `FilterChip` (E5), `FreshnessBadge` + `freshness.ts` (E8), `ConfirmActionDialog` (E10, review checkbox gate), `.data-table-compact` (R7). 21 tests. |
| `9269fd9` | gate | Type-scale baseline rebuilt from the committed tree: the monolith split had moved the Projects/Reports sizes into component files and the ratchet was red on HEAD (36 "new" files). Rule unchanged. |
| `fcb59c8` | 2 Главная | Five KPI tiles on thresholds (issues warn 1 / problem 5; free installers problem at 0, warn above 85 % load); yellow no longer a status. Issues tile and the board's "doors without installer" / "open issues" items toggle the dispatcher filter with a removable chip (E5). Project rows: attention stripe from blocked / issues / unassigned (E1), entity keys (E2). FreshnessBadge with one refresh for the three queries (E8). Board sizes on the scale. Tests +3. |
| `3212d55` | 3 Проекты | Arrow keys between door tiles in the preview grid and the full matrix (left/right along the floor, RTL mirrored, up/down keep the position; `matrix-shared.nextMatrixTile` + `moveMatrixFocus`), floor-by-floor fill-in on load, opacity only, off under reduced motion (E7/R8). Ledger on the shared data-table with a sticky header, comfortable/compact density remembered per browser (R7), attention stripe instead of the tinted row (E1), door entity keys. Condensed bar for the selected project (E3). Tests +5 (53 existing green). |
| `613539c` | 4 Отчёты | The three executive insight cards drew a fixed decorative SVG regardless of the numbers; removed, the card is the shared tile with tone/value/delta/detail/link. 17 section tables on the shared data-table (B7). Installer rows in KPI table, cross view and profitability matrix carry entity keys; the page runs linked highlighting (E2). Library/saved-view cards on one radius and the scale. 27 tests green. |
| `d020b1d` | 5 Операции | Eight KPI cards → threshold tiles (duplicates/unmatched warn from 1, provider failures warn 1 / problem 5, batch failures problem from 1). Existing freshness, status pill and URL drill-down kept. 17 tests green. |
| `166b548` | 6 финансы | `ui/table` primitive on the shared baseline (Ledger, Documents, Library, Door types, Reasons at once). Reconciliation deltas coloured by sign, matching rows dimmed (E6). Recorded earnings with the lock glyph and its explanation (R6). 71 tests green (+1). |
| `7999568` | 7 люди и работа | Issues: four tiles on thresholds, the SLA tile toggles overdue-only (E5), rows with attention stripes (E1). Calendar: lane rows and event avatars carry installer keys, linked highlighting on (E2). Journal headings on the shared role (R2). Installers modals were already on `ui/dialog` (B9 closed earlier). 43 tests green. |
| `b4cbbe7` | 8 справочники | Settings and the catalog CRUD page on the type scale (31 sizes). 13 tests green. |

Not done, by design or blocked:
- Block 9 (shell: sidebar rail tooltips, mobile drawer, `next/font`): `AppSidebar.tsx` is still in the other agent's uncommitted tree.
- Browser verification of every page on the demo stack: the Docker engine is down again (pipe missing); the visual pass with the owner's demo admin runs as soon as it is back, with the visual brand smoke over all routes. Until then the blocks are **confirmed by tests and studied by code, not seen in a browser**.
- The dashboard sparkline needs a 14-point series the API does not provide yet; the tile supports it, the dashboard passes none.
- Reports tier tabs (executive / operations / people) were not added: the page already has a focus mechanism (`?focus=`) and the tiering is a content reorder the owner should see in the browser first.
- Mockup remains the reference: https://claude.ai/artifact/BbxQxHQq9JcXGEdAFCpgkm

## 12. Browser pass (2026-10-17, demo stack on 8000, dev server on 4173, demo admin)

Full-page screenshots in `artifacts/visual-brand/2026-10-17-premium/` (git-ignored).

| Section | Seen | Result |
|---|---|---|
| Главная | yes (in the browser pane and in DOM) | Tiles with tones from thresholds, freshness "обновлено только что", the "doors without installer" summary item toggles the board and shows the removable chip. |
| Проекты | yes | Shell intact; **defect found**: the hidden condensed bar reserved 48 px above the project card. Fixed in `91f244e` (zero-height sticky wrapper). Project KPI cards at the top still use the old bar colours (follow-up). |
| Календарь | yes | Warm canvas, lanes and toolbar unchanged. |
| Проблемы | yes + DOM | Four tiles, `data-tone` ok at zero values, stripes and chips in the list. |
| Отчёты | yes | Insight cards without the fake charts, stripes by tone, library cards on one radius. |
| Прайс завода | yes | Header, notice and versions unchanged; demo has no versions, the diff view could not be exercised. |
| Документы | yes | KPI cards and forms on the shared table baseline. |
| Монтажники, Журнал, Документы, Настройки | yes (second pass, 2026-10-17 evening) | Shell and tables fine; **finding**: their KPI cards still carried decorative bar colours (blue, yellow). Fixed centrally in `054c2a6`: the legacy `KpiCard` renders on the shared tile and maps bar colours to state tones. |
| Начисления | yes | Shared table baseline with the uppercase 11 px header and skeleton rows; the demo has no ledger rows, so the lock glyph was verified by test only. |
| Операции | yes | Page-specific diagnostic tiles (P1 / OK pills) coherent with the tone system; threshold tiles below the fold. |
| Справочники, Типы дверей, Причины | yes | Shared table baseline and the catalog tiles. |

Other findings: the one 401 per page in the console is the access-token refresh (`/auth/me` 401 → `/auth/refresh` 200 → retry), not a defect; the demo database was built from the ORM and already had `ix_completed_work_door_id`, so migration 0075 is now idempotent (backend `f4e8f5c`). Backend `installed_series_14d` for the dashboard sparkline added (backend commit, test pending Docker); the frontend tile uses it (`dfbd499`).

The pass over all 15 sections is complete (second half after a Docker restart, with only db + api and the dev server running). The full-route visual brand smoke (`npm run test:e2e:visual-brand`) is still to run before a release.

## 13. Follow-ups landed after the browser pass (2026-10-17)

| Commit | What |
|---|---|
| admin `91f244e` | Hidden condensed bar no longer takes layout space (found in the browser). |
| admin `dfbd499` + backend `d3980cb` | Dashboard sparkline is real: the report returns `installed_series_14d` (effective installations per day), the tile shows it with the week-over-week delta. Backend `test_reports_api.py` 38 passed in the isolated container; seen on the live dashboard (flat at zero on demo data, "±0 к прошлой неделе"). |
| admin `054c2a6`, `21bfd04` | Legacy KpiCard on the shared tile chrome (Installers, Journal, Documents, Settings lost their decorative bar colours); tile status pill wraps under long labels (seen live). |
| backend `f4e8f5c` | Migration 0075 idempotent for databases built from the ORM (the demo API restart-looped on it). |
| admin (fonts) | Block 9, the part outside the other agent's file: Rubik and JetBrains Mono self-hosted through next/font, no Google Fonts @import; production build green. |
| admin (tiles) | Project and catalog KPI cards on threshold tiles; no bar-coloured cards left in the views. |

Still open: sidebar rail tooltips and the mobile drawer (block 9, `AppSidebar.tsx` is the other agent's); the browser pass for Монтажники, Журнал, Справочники, Начисления, Операции, Настройки, Типы дверей, Причины; reports tiering (owner to see in the browser first).

## 14. Block 9 and the second wave of effects (2026-10-17 evening, owner: "take block 9, keep adding complex effects")

| Commit | What |
|---|---|
| admin `7a5d96a` | Block 9: mobile navigation drawer (menu button in the topbar, the labelled sidebar in a Radix dialog, slides from the start edge, closes on choice or route change) and rail tooltips below md. Only this session's hunks of `AppSidebar.tsx` were committed; the other agent's two lines (DIMAX AI item) stay in their working tree. Seen in the pane at 375 px. |
| admin `dc9776f` | Command palette on Ctrl/Cmd+K and the topbar search pill: sections the session can reach, the create action for privileged scopes, projects and installers, one ranked list (prefix > word start > substring > subsequence with spread penalty, ties by kind), keyboard roving, five recents. Seen live ("зав" → Прайс завода). |
| admin `89f5b9d` | Dispatcher board: proportional building rail per project (installed / in progress / without installer) and an "attention first" toggle on the shared attention level. |
| admin `899a324` | Numeric KPI values count to their new value (360 ms, off under reduced motion and on first render). |
| admin (since-visit) | Active projects, open issues and free installers show the delta since the previous visit from a local snapshot of that visit. |
| admin (g shortcuts) | g then a letter jumps to a section; never while typing. |

Rules kept: motion answers an action or marks a change, never decorates; every colour is a state; the keyboard reaches everything the mouse does (palette, shortcuts, matrix arrows, drawer).

Still open: reports tiering (owner's call after seeing the page), the pre-release visual brand smoke on the production build, and the other agent's `AppSidebar.tsx` lines which remain theirs to commit.
