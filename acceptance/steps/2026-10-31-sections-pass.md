# Section-by-section pass: logic + visuals → working state (2026-10-31)

Owner's request (2026-10-31): take every section and every tool in it, study the logic and the visuals,
draw a conclusion and fix or add what is needed so each point works; use the skills we have.
Basis: the full analysis of 2026-10-31 (`acceptance/analysis/dimax-full-analysis-2026-10-31.html`).

Marks: **confirmed by tests**, **studied by code**, **seen live**, **not verified**, **needs external infra**.

Rules kept: minimal fixes with regression tests; no change of an owner's business rule without a decision
(those go to the "for the owner" list); each section is reviewed with code-review, security-review, simplify,
run (live) and frontend-design for UI; commits per section, only own files; nothing is pushed.

## Order

Admin menu order, each section with its backend part and, where it exists, the phone part:
1. Objects (projects, doors, assignment, import) · 2. Calendar · 3. Issues · 4. Installers · 5. Journals and
signing · 6. Catalogs (door types, reasons, library) · 7. Factory price list · 8. Contracts and billing ·
9. Earnings ledger · 10. Reports · 11. Documents · 12. Operations and outbox · 13. Settings and users ·
14. DIMAX AI · 15. Installer web cabinet · 16. Mobile app · 17. Platform (auth, rate limits, tokens).

## 1. Objects

### Found (logic + visuals)
- A partial project change overwrote the address: the normalisation always set `address`, the update applied it
  (`PATCH {contact_name}` → address ""; `PATCH {address_city}` → address = city only).
- Assigning the same installer again sent "assigned to you" and then "removed from you" to the same phone, which
  can take the door off the installer's phone; single assignments were not audited; a door of a deleted project
  could still be assigned.
- A deleted project kept its (company, name, address) slot forever: the same site could not be created again.
- The admin list asked for no limit, so the server's default of 50 applied: search, counts and bulk selection saw
  only the first 50 projects.
- After a door action the page jumped back to the project of the deep link; a slow layout answer of the previous
  project could replace the current one; door filters (floor, status…) survived a project switch and hid every door.
- Bulk "reconcile latest import" ran without a question, included projects hidden by the filter and stayed
  clickable without the import right.
- Seen live: raw `ACTIVE`, `ISSUE_OPEN`, `ON_HOLD`… in the Russian and Hebrew UI; the project card said
  "Заблокировано" next to "нет блокеров" (health BLOCKED means open problems, not locked work).

### Done
- Backend: an address change merges with the stored parts; a change without address parts keeps the address
  (`projects/application/use_cases.py`). Same-installer assignment is a no-op without sync messages; single
  assignments are audited (`DOORS_ASSIGN`); assignment requires a live project. Migration
  `0097_projects_unique_active`: the name+address rule applies to live projects only (downgrade refuses when a
  deleted and a live project share them).
- Admin: shared `src/lib/status-labels.ts` (RU/EN/HE names of server codes, meaning by place: project, health,
  installer, journal…), used by the projects page; health "BLOCKED" reads "Есть открытые проблемы". The list is
  read page by page (200); a deep link selects once; stale layout answers are dropped; door filters reset on a
  project switch; bulk reconcile asks first, names the hidden selected projects, needs the import right.

- Seen live and fixed: the revenue and margin tiles said "Коммерческий доступ ограничен" to the OWNER while the
  figures were loading; now "restricted" only without the right, "Загрузка…" while loading, "Нет данных" when the
  answer failed or was empty. Review pass: a second live project with the same name and address now answers a
  readable 409 instead of a database error (create and rename).

### Checks
| Check | Mark | Evidence |
|---|---|---|
| Partial change keeps / merges the address; same installer again sends nothing; deleted project does not block the same site; duplicate live name+address is a 409 | confirmed by tests | `test_projects_admin_api.py` (4 new); projects + assignment + import + inbox + isolation suites: 85 passed |
| Status names, every page read, reconcile asks first and names hidden projects | confirmed by tests | `status-labels.test.ts` (3), `ProjectsPage.test.tsx` (2 new; 58 passed with the labels test); eslint, ratchets, `tsc` clean |
| Russian labels on the project card, list, door filter ("В работе", "Есть открытые проблемы", "Есть проблема", "Не установлено"); money tiles while loading | seen live | demo stack, admin dev server, 2026-10-31 |

### Review pass (code-review, security-review, simplify)
- code-review (high): 4 findings — empty answer kept "Загрузка…" forever (fixed), duplicate name+address gave a
  500 (fixed with a 409 and a test), a free-text-only address PATCH is ignored when parts are stored (kept: the
  admin form always sends all parts; noted), sequential page reads after each door action (kept: fine at this scale).
- security-review: no findings (no new endpoint; company filters kept; audit added; static DDL).
- simplify: one change (the address-touch check computed once); the rest already reuses shared helpers.

### For the owner
- Should a CANCELLED or ON_HOLD project refuse installation and earnings? Today the status is informational.

## 2. Calendar

### Found (logic + visuals)
- PATCH ignored an explicit null: a project link, place or description could never be cleared; unlinking a site
  kept its address copied into the event.
- An unknown `event_type` filter reached the database (500); assignees were read one query per event; no audit
  of create / change / delete; an event linked to a site navigated by the address text, not by the site's
  coordinates or Waze link; nothing showed that one crew was booked twice at the same time.
- Admin: delete without a question; events could only start and end on the same day (an overnight event was cut
  when edited); a load error had no retry; the CSV export had English headers, raw type codes and no BOM (Excel
  showed Hebrew/Russian as garbage); the project picker saw only the first 50 projects.
- Seen live (owner's remark): overlapping events became slivers one letter wide, and a click opened the details
  above the grid, out of sight, so nothing seemed to happen.

### Done
- Backend: explicit null clears place / description / project (and the site address copied in); type filter
  validated (422); assignees and projects read in one query each; audit `CALENDAR_EVENT_CREATED/UPDATED/DELETED`
  without the free-text description; navigation to the site's coordinates or Waze link when the event has no
  place of its own; `overlapping_event_ids` per event (same installer, overlapping time).
- Admin: delete asks first (a failed delete stays retryable in the editor); end date field (night shifts; moving
  the start moves the end by the same days); retry on load errors; shared `src/lib/csv.ts` (BOM, formula-safe,
  localized headers and types); shared `src/lib/projects-list.ts` (all project pages, used by Objects and
  Calendar); double-booked events marked on the card and explained in the details; overlapping cards stacked
  with an offset instead of slivers; a click scrolls the details into view; unavailable Waze / WhatsApp / Call
  buttons disabled with the reason; "Open project" only when a project is linked.

### Checks
| Check | Mark | Evidence |
|---|---|---|
| Null clears optional fields and the copied address; bad type filter 422; double booking ids; site coordinates for navigation; audit rows | confirmed by tests | `test_calendar_api.py` (new test + exact keys), boundary + architecture: 12 passed |
| Delete confirmation and retry; overnight end date; start shift keeps length; double-booked marker and note; CSV BOM and formula guard | confirmed by tests | `CalendarPage.test.tsx` (11), `csv.test.ts` (2) |
| Double booking marked on both cards, details scroll into view on click, stacked cards readable | seen live | demo stack, two test events created and deleted afterwards |

### Review pass
- code-review: 3 findings, all fixed (start date shift, address on unlink, description in audit).
- security-review: no findings (no new endpoint; stricter filter validation; audit without free text).
- simplify: CSV and project-list loading moved to shared modules instead of page copies.

### Not done here
- Filters and the selected period are not in the URL yet (DESIGN_SYSTEM asks for shareable filters).
