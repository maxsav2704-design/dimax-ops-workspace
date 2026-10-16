# Admin web — block 6 (dead code) deletion list and block 8 decision

Date: 2026-10-16. Repo: `dimax-operations-suite-main`, branch `codex/release-hardening-20260908`.

Rule applied: nothing below is deleted until the owner answers "yes" per group.
Evidence comes from a reachability scan over every `.ts/.tsx` under `app/`,
`src/` and `pages/` (imports resolved through `@/` and relative paths), with
the Next.js route files under `app/` as entry points and the test files as a
second root. Result: 156 of 201 non-test files are reachable from the routes.
The other agent's uncommitted files (`app/(admin)/ai/`, `AppSidebar.tsx`,
`admin-access.ts`) were part of the scan, so nothing they import is listed.

## Group A — legacy Vite SPA (safe: no route reaches it)

| File / entry | Why it is dead |
|---|---|
| `src/App.tsx` | Vite root with `react-router-dom` routes; Next app router renders `app/`. |
| `src/main.tsx` | Vite entry; only `index.html` points at it. |
| `index.html` | Vite HTML shell. |
| `vite.config.ts` | Vite config; `vitest.config.ts` is separate and stays. |
| `tsconfig.app.json`, `tsconfig.node.json` | Vite-era TS projects; `tsconfig.node.json` includes only `vite.config.ts`. `tsconfig.json` has no `references` to them (checked), so they can go without touching `tsconfig.json`, which the other agent currently has modified. |
| `package.json` scripts `dev:vite`, `build:vite`, `build:dev`, `preview` | Run Vite. |
| `pages/_document.tsx` | Pages-router document; there are no `pages/` routes, `app/layout.tsx` owns `<html>`. |
| `src/components/NavLink.tsx` | `react-router-dom` NavLink; unused. |
| dependency `react-router-dom` | Imported only by `src/App.tsx` and `NavLink.tsx`. |
| dev dependency `vite` (`^8.0.13`, installed 8.1.5) | **Keep `@vitejs/plugin-react`**: `vitest.config.ts` uses it. `npm ls vite` shows `vite` only as this top-level dev dependency; Vitest 4 bundles its own. Removing it needs one `npm uninstall` and a Vitest run to confirm. |
| `scripts/validate-production-env.mjs` lines 118-126 (`VITE_API_BASE_URL`) | Validation of a Vite env variable; keep or drop together with the Vite removal (owner's call, it is harmless). |

## Group B — components nothing imports

| File | Evidence |
|---|---|
| `src/components/calendar/EventControlPanel.tsx` | No importer in `src`/`app`; RU-only toasts noted in the audit. |
| `src/components/dashboard/TopReasonsCard.tsx` | No importer. |
| `src/components/dashboard/MetricRow.tsx` | No importer; the live one is `src/components/dimax/MetricRow.tsx`. |
| `src/components/journal/InspectionTable.tsx` + `MasterCircle.tsx` | `InspectionTable` imports `MasterCircle`; nothing imports `InspectionTable`. |
| `src/components/dashboard/ProblemProjectsTable.tsx` + `src/test/ProblemProjectsTable.test.tsx` | Referenced only by its own test (audit: "tested, unused"). Deleting the component means deleting the test. |
| `src/hooks/use-mobile.tsx`, `src/hooks/use-user-role.ts` | No importer. |
| `src/components/ui/use-toast.ts` | No importer (`ui/toaster.tsx` and `ui/sonner.tsx` stay: `AppProviders.tsx` uses them). |

## Group C — unused shadcn `ui/*` primitives (31 of 50 files)

No importer anywhere in `src`/`app`/tests:

`alert`, `aspect-ratio`, `avatar`, `badge`, `breadcrumb`, `calendar`, `card`,
`carousel`, `chart`, `collapsible`, `command`, `context-menu`, `drawer`, `form`,
`hover-card`, `input-otp`, `menubar`, `navigation-menu`, `pagination`, `popover`,
`progress`, `radio-group`, `resizable`, `scroll-area`, `separator`, `sheet`,
`sidebar`, `slider`, `switch`, `tabs`, `toggle-group`, `toggle`.

Note: `src/components/dimax/Breadcrumbs.tsx` is the live breadcrumb; `ui/breadcrumb.tsx` is the unused shadcn one.

## Group D — runtime dependencies that become unused once Group C is gone

Imported only by files in Group B/C (verified per package):

`@radix-ui/react-aspect-ratio`, `@radix-ui/react-avatar`, `@radix-ui/react-collapsible`,
`@radix-ui/react-context-menu`, `@radix-ui/react-hover-card`, `@radix-ui/react-menubar`,
`@radix-ui/react-navigation-menu`, `@radix-ui/react-popover`, `@radix-ui/react-progress`,
`@radix-ui/react-radio-group`, `@radix-ui/react-scroll-area`, `@radix-ui/react-separator`,
`@radix-ui/react-slider`, `@radix-ui/react-switch`, `@radix-ui/react-tabs`,
`@radix-ui/react-toggle`, `@radix-ui/react-toggle-group`, `cmdk`, `embla-carousel-react`,
`input-otp`, `react-day-picker`, `react-hook-form`, `react-resizable-panels`, `recharts`, `vaul`.

Imported by nothing at all today: `@hookform/resolvers`, `date-fns`.

Kept on purpose: `zod` (now used by `src/lib/api-schemas.ts`), `sonner` (`ui/sonner.tsx` via `AppProviders`), `react-dom`, `@swc/helpers`, `next`, `react`.

## Group E — test placeholder

`src/test/example.test.ts` (`expect(true).toBe(true)`). The discovery contract
discovers files dynamically and does not list it by name (checked), so nothing
else changes.

## Proposed order (one commit per group, quality gate after each)

1. Group B + E (components, hooks, placeholder): no dependency changes, fastest to verify.
2. Group C (ui primitives), then Group D (`npm uninstall` of the now-unused packages, lockfile updated).
3. Group A (Vite removal), last, because it touches `package.json` scripts and `tsconfig.json`, which the other agent currently has modified.

Each commit: `npm run lint`, `tsc --noEmit`, discovery contract, affected tests, and `npm run build` at the end of the series.

## Block 8 — theme decision (owner, 2026-10-16)

Admin web stays **light**; the dark theme belongs to the **mobile app** only.
Consequences for the admin repo:

- No `next-themes` wiring, no theme switch, no `prefers-color-scheme` override.
- `src/index.css` keeps the `.dark { … }` token block only as a reserved
  contract; nothing adds the `.dark` class, so it never renders. Removing the
  block is optional and listed here as **Group F** (owner's call; it is ~70
  lines of tokens plus the `--dmx-event-*` dark values added in `b682f3e`).
- `tailwind.config.ts` `darkMode: ["class"]` is harmless and stays.

## Execution (owner's "yes", 2026-10-16)

| Commit | Group | Gate |
|---|---|---|
| `9483af3` | B + E (10 files) | tsc, eslint, discovery 68+12, i18n guard, ratchet (baseline regenerated, counts only down) |
| `02429ec` | C (31 ui primitives + use-mobile, 18 ui files remain) | same gate |
| `65b0681` | D (27 runtime deps, 64 packages gone, 24 remain) | tsc; dialog / foundation / price lists / installers / calendar tests 49 |
| `61b70ba` | A (Vite SPA, 8 files, 4 scripts, react-router-dom + vite) | eslint; all node gate scripts; Vitest smoke; tsc clean with the stale `.next-acceptance/dev/types` stub excluded |

Not done: Group F (`.dark` token block) — optional, left in place. `scripts/validate-production-env.mjs` still validates `VITE_API_BASE_URL` (harmless, listed as owner's call).

Known local artifact: `.next-acceptance/dev/types/validator.ts` (git-ignored, written by a `next dev` run on 2026-09-10) still references `pages/_document`; `tsconfig.json` includes that folder, so a local `tsc`/`next build` reports it until that dev cache is regenerated or removed. A fresh checkout (CI) has no such folder. Removing that cache needs the owner's yes (cache of another task).

Post-cleanup `npm run build`: webpack compiled in 36 s, then the type-check
phase failed on exactly that stale stub (`.next-acceptance/dev/types/validator.ts:277`,
`pages/_document.js`). Nothing in `src/` or `app/` is involved; the same build
passed before group A because the file still existed. Waiting for the owner's
yes to remove `.next-acceptance/dev/types/` (a 2026-09-10 dev-server cache, no
container or script reads it), after which the build is expected to pass.

Owner approved removing `.next-acceptance/dev/types/` (2026-10-16). Removed;
`tsc --noEmit -p tsconfig.json` clean; `npm run build` compiled in 25 s,
29 routes, exit 0. Block 6 closed (groups A–E); group F left in place.
