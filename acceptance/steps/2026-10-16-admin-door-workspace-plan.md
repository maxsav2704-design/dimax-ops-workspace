# Admin web — door workspace split (Projects 11–13), mini-plan

Date: 2026-10-16. Repo `dimax-operations-suite-main`, branch `codex/release-hardening-20260908`.
Status: approved by the owner on 2026-10-17 ("да"); executed the same day, see Result below.
Context: steps 1–4 of `2026-10-16-admin-monolith-split-plan.md` are done; `ProjectsPage.tsx`
is 6 915 lines and the door workspace is what is left of its render.

## What the workspace is today (render lines of the current page)

| Block | Lines | Ids used / only here | What it holds |
|---|---|---|---|
| Command bar (`project-detail-v28-command`) | 3649–4488 (840) | 50 / 5 | project KPIs (doors, issues, deadline, finance readiness), quick filters (floor, status, issue, marking search), legend counts, scroll shortcuts to the other cards |
| Matrix + focused door (`project-door-matrix`) | 4777–6598 (1 822, incl. ledger) | 77 / 41 | filter row (house, order number, floor, location, door type, status, installer, apartment/marking search), tiles per floor, bulk assign to installer, focused-door panel (installer, issues, reason, comment, override, mark installed / not installed) |
| Door ledger (`project-door-ledger`) | 6227–6597 (371) | 18 / 4 | card list (< md) or table (≥ md) of the filtered doors, selection checkboxes, paged by 100 (`useMediaQuery`, step C2) |
| Manual door dialog | 6666–6911 (246) | 10 / 6 | form state + submit, library product and installer pickers |

State and derivations they share (component scope, 717 lines in total):

- Filters: `matrixHouse`, `matrixOrderNumber`, `matrixFloor`, `matrixLocation`, `matrixDoorType`,
  `matrixStatus`, `matrixInstaller`, `matrixIssueFilter`, `matrixApartmentSearch`,
  `matrixMarkingSearch` + `resetMatrixFilters`, the six `matrix*Options` memos and the
  `matrixInstallerFilterControl` JSX const (used by the command bar and the matrix row).
- Rows: `matrixRows` (from `layout`), `filteredMatrixRows`, `filteredMatrixSummary`,
  `visibleMatrixRows` / `hiddenMatrixRows` / `ledgerRowLimit`, `matrixLegendCounts`,
  `projectDoorTotals`, `projectDetailMatrix` (179 lines, floor grid), `projectDetailFloorPreview`.
- Selection: `selectedDoorIds`, `selectedDoorIdSet`, `filteredDoorIds`,
  `allFilteredDoorsSelected`, `hiddenSelectedDoorCount`, `toggleDoorSelection`,
  `toggleFilteredDoorSelection`, bulk assign (`bulkAssignInstallerId`, `bulkAssignLoading`,
  `handleBulkAssignDoors`).
- Focused door: `focusedDoorId`, `focusedDoorRow`, `focusedDoorInstaller`, `focusedDoorIssues`,
  reason / comment / override fields, `doorStatusAction`, `handleFocusedDoorMarkInstalled` (39),
  `handleFocusedDoorMarkNotInstalled` (90).
- Page-level inputs: `layout` + `loadLayout`, `selectedProjectId`, `projectDetails`,
  references (installers, reasons, library, door types), `canManageProjects`,
  `canViewProjectRates`, `tokenLabel`, `locationLabel`, `formatMoney`, `scrollToProjectSection`.
- Cross-links that must keep working: `setMatrixOrderNumber` from the urgency card
  (`handleUrgencySaved`), `setMatrixIssueFilter` from the side widgets, `setFocusedDoorId` /
  `setSelectedDoorIds` resets on project change and after imports, deep links
  (`order_number`, `focus_section`).

Existing tests that pin the behaviour (ProjectsPage.test.tsx): order-number filter in the
matrix, bulk assign (success and API error without clearing the selection), ledger paging
(100 rows + "Show more"), manual door creation (3 tests: create, library deep link,
duplicate code), the focused-door "mark not installed with reason" flow (1 test), plus
`DoorMatrixTile.test.tsx`. "Mark installed" and the override reason have no test today —
to be added with commit 4 below.

## Proposed order (five commits, one feature folder `src/components/projects/door-workspace/`)

1. **`ManualDoorDialog`** — same pattern as `ProjectDialog`: form state and submit inside,
   `onSaved(projectId)` → page reloads details, layout and import history; module helpers
   (`ManualDoorFormState`, `emptyManualDoorForm`, …) to `manual-door-form.ts`.
   Risk: low (6 of 10 ids are exclusive).
2. **`useDoorWorkspace()`** — a hook in the folder that takes `{ layout, projectDetails,
   installers, reasons, canManage }` and returns the filter state + setters, the row memos,
   selection and focused-door state with their toggles and `resetMatrixFilters`. Code moves
   verbatim (the 717 lines above minus the three API handlers); the page calls the hook once
   and keeps destructuring the same names, so this commit changes no markup at all.
   The page keeps `setMatrixOrderNumber`, `setMatrixIssueFilter`, `setFocusedDoorId`,
   `setSelectedDoorIds` through the hook result for the cross-links. Risk: medium — the
   hook's dependency lists are copied as they are; tsc + the four tests above are the check.
3. **`DoorLedger`** — markup only (371 lines), props from the hook result + `canManage`,
   `tokenLabel`, `locationLabel`. Keeps the C2 paging and `useMediaQuery` behaviour.
4. **`DoorMatrix`** — matrix card without the ledger (~1 450 lines): filter row, tiles,
   bulk assign, focused-door panel. The three API handlers (`handleBulkAssignDoors`,
   `handleFocusedDoorMarkInstalled`, `handleFocusedDoorMarkNotInstalled`) stay in the page
   for this commit and are passed as callbacks (they reload layout/details/plan-fact/risk and
   set page notices); `projectDetailMatrix` (floor grid, 179 lines) moves with the card.
   `matrixInstallerFilterControl` becomes a tiny `InstallerFilterSelect` component used by
   both the matrix and the command bar.
5. **`DoorCommandBar`** — the KPI + quick-filter bar (840 lines), props from the hook plus
   the project summary values the page already computes (`projectCompletionPct`,
   `projectInstalledDoors`, `projectTotalDoors`, `projectUnassignedDoors`, finance flags).

Each commit: tsc, eslint, Projects tests (51) + component tests, the demo stack in the
browser with the 580-door project (order filter, ledger "show more", focused door panel,
manual door dialog opens/closes). Full `npm run test` + `npm run build` after 5. Expected
page size after the five: ~3 000 lines (header, list, queries, loaders, notices).

## Not in scope

No change to door status rules, prices or earnings; no new state library; no change of
test ids, copy or deep links. Anything found broken on the way is a separate commit with
its own test, as in steps 1–4.

## Result (2026-10-17)

| Commit | Step | Files | Page lines after |
|---|---|---|---|
| `4271ccb` | 1 ManualDoorDialog | `ManualDoorDialog.tsx`, `manual-door-form.ts`; page opens it with an initial form and remounts per open | 6 527 |
| `7f9124e` | 2 useDoorWorkspace | `door-workspace/useDoorWorkspace.ts` (56 statements, 562 lines, verbatim), `types.ts`, `constants.ts`; `compareNatural` → shared | 5 971 |
| `19d5b11` | 3 DoorLedger | `door-workspace/DoorLedger.tsx` | 5 624 |
| `85f51fb` | 4 DoorMatrix | `door-workspace/DoorMatrix.tsx` (ledger as children), `matrix-shared.ts`; API handlers stay in the page as callbacks | 4 144 |
| `b0bfd7b` | 5 DoorCommandBar | `door-workspace/DoorCommandBar.tsx` (side widgets are laid out inside it and stay there) | 3 329 |

Deviations from the plan: `matrixInstallerFilterControl` stayed a JSX value passed as a
`ReactNode` prop (used by the matrix and the command bar) instead of becoming a component —
no behaviour reason to touch it in this step; the "mark installed" test mentioned for step 4
was not added (the three API handlers did not move, so nothing new to pin). Each commit:
tsc, eslint, Projects tests 51 + component tests 5 (matrix order filter, bulk assign,
ledger paging, manual door ×3, focused door reason flow all green).
`ProjectsPage.tsx` is now 3 329 lines: header/portfolio/list, queries and loaders,
catalogs and notices, deep links, the three door API handlers and the section calls.
