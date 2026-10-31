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

## 3. Issues

### Found (logic + visuals)
- "Not installed" on a door with an open issue overwrote the issue's text and reset its progress to NEW: a defect
  raised by the site or already in work lost its report and status.
- Admin "apply to filtered": computed against the selected issue (nothing to do when it was already in the target
  state), closed site-raised issues too (the server refuses them, so the whole batch failed), and showed raw codes
  in the confirmation.
- Seen live: rows showed project and door as identifier fragments, the stage column as raw `NEW`, an office owner
  as a UUID, the selected issue header as "door / project-uuid"; dates in the browser's own format; the overdue
  label read "Нарушено соглашение об уровне обслуживания"; no retry on a load error; 200-row cap not mentioned.
- Found in self-review of the first fix: copying all form fields in bulk would have overwritten the priority and
  owner of every filtered issue.

### Done
- Backend: "not installed" appends its note to an open issue and keeps its owner and progress; a closed issue is
  reopened as a new one (as before); the report-append helper moved to `issues/application/lifecycle.py` and is
  shared by installer, office and not-installed paths; the admin list returns `project_name` (one query).
- Admin: bulk sends only the fields the user touched in the form; site-raised issues are left out of a bulk close,
  with the count named in the confirmation; readable labels in the confirmation and the stage column; rows and
  header read "site · door"; dates in the interface language; "Office user" instead of an id; retry on load
  error; a note when the 200-row cap is reached; overdue label shortened.

### Checks
| Check | Mark | Evidence |
|---|---|---|
| Not-installed note added to an open issue, progress kept | confirmed by tests | `test_issue_lifecycle_sync.py` (new test); issue + fix flow + snapshot suites 95 passed; with OpenAPI and isolation 36 passed |
| Bulk sends touched fields only; site issues left out of bulk close; site name in the list and header | confirmed by tests | `IssuesPage.test.tsx` (10, 1 new, 3 updated to readable labels) |
| Site names, "Новая" in the stage column, "Сотрудник офиса", Russian dates | seen live | demo stack, 2026-10-31 |

### Review pass
- code-review (self, on the diff): 1 real defect found in my own bulk change (untouched fields copied) — fixed
  with touched-field tracking and a test.
- security-review: no findings (no new endpoint; project names read within the company).
- simplify: the report-append helper is shared instead of imported across services.

### For the owner
- Issue workflow has no transition rules (the office can move any state to any state). Keep it free, or restrict?

## 4. Installers

### Found (logic + visuals)
- Editing an installer opened the form with empty address, document and notes and saved them as null: every edit
  wiped them (the API never returned them, so the form could not show them).
- Creating an installer with an account checked only the company (an office account could be linked); status was
  free text; phones were stored as typed (the same number twice in different forms); deleting an installer with
  doors still to install left that work assigned to nobody visible.
- Admin: delete installer, delete rate and unlink account ran without a question; saving one rate reset the
  prices typed in the other rows; prices printed with a hard-coded "ILS".
- Seen live: raw `ACTIVE` under the name, "Срез: all", the account link shown as a UUID.

### Done
- Backend: the list returns address and notes and a masked document hint (`•••8877`), never the number; phones are
  stored in one international form (422 when not a phone); status limited to ACTIVE / BUSY / INACTIVE; creating
  with an account applies the link rules (active INSTALLER account, not linked elsewhere); deleting an installer
  with doors still to install is refused (409 with the count).
- Admin: the form starts from the stored values (one builder for the edit button and the deep link); an empty
  document field keeps the stored number; delete / delete rate / unlink ask first; other rows keep their unsaved
  prices; money in the interface format; readable status, slice and account state.

### Checks
| Check | Mark | Evidence |
|---|---|---|
| Edit keeps address / notes / document; phone normalized; bad status and phone refused; delete refused with open doors | confirmed by tests | `test_installers_api.py` (2 new); installer, link, rates, access, isolation, OpenAPI suites: 39 passed |
| Form prefilled, document kept when the field is empty | confirmed by tests | `InstallersPage.test.tsx` (6, 1 new) |
| Card shows "Доступен", "Срез: все", "Привязана: может входить в приложение" | seen live | demo stack |

### Review pass
- code-review (self): the deep link filled the form with its own empty fields — replaced by the shared builder.
- security-review: the document number is no longer needed by the page and is not sent back (only a masked hint).
- simplify: one `formFromInstaller` for both entry points.

### For the owner
- Linking an account still means typing its id; a picker of unlinked installer accounts needs an account list
  endpoint (user management is not built yet, see platform section).

## 5. Journals and site signing

### Found (logic + visuals)
- A retired (deactivated or deleted) door type or add-on type printed as an identifier / "Additional work" in the
  snapshot and the signed PDF: names were read from active types only.
- "Refresh works" rebuilt the table even when the office had locked it.
- The public signing link listed every open issue of the project, office notes included, not only the doors of
  that document and the site's own defects.
- Admin: opening for signing, sending to the client and deleting a shared template ran on one click; a failure of
  the settings requests (integrations, templates) hid the whole journal list; "Retry" was offered on delivered
  messages; the send notice showed an internal "Object key"; projects beyond the first 200 read "Unknown project";
  raw statuses; seen live: "Стол заблокирован" (table → "стол") and "Not set" in Russian.

### Done
- Backend: `door_types.names_by_id` and `addon_types.all_by_id` (all types, retired included) used by every
  journal snapshot / PDF path; refresh refused while the table is locked (409); the public issue list shows the
  document's doors and site-raised issues only.
- Admin: confirmations for open-for-signing, send and template delete; settings failures no longer block the list;
  retry only for failed deliveries; no internal key in the notice; all projects; readable journal and delivery
  statuses ("Ждёт подписи", "Подписан", "Не отправлялось"); translation fixes.
- Kept as is (tried and reverted): requiring the snapshot version at signing would break signing clients that
  do not send it, and skipping it harms only the signer; the check stays when the version is sent.

### Checks
| Check | Mark | Evidence |
|---|---|---|
| Retired door type keeps its name; locked table not rebuilt | confirmed by tests | `test_journal_api.py` (new test); journal, delivery, partial acceptance, fix flow, PDF/snapshot contracts, claims, add-ons: 114 passed |
| Confirmations for send / delete template; list loads with failing settings; statuses readable | confirmed by tests | `JournalPage.test.tsx` (14), `JournalFormPage.test.tsx` |
| Statuses and translations on the journal page | seen live | demo stack |

### Review pass
- code-review (self): the required snapshot version broke existing signing tests — reverted with the reason above.
- security-review: the public link no longer exposes office issue notes of other doors.
- simplify: one names lookup per type kind instead of six inline dictionaries.

### For the owner
- Without the partial-acceptance flag a new journal lists every installed door again, including doors signed in an
  earlier journal (cumulative acts). Keep cumulative acts, or switch the flag on (each act lists only new work)?
  The claims side is protected separately in section 8.

## 6. Catalogs (door types, reasons, product library)

### Found (logic + visuals)
- A deleted door type or reason kept its code forever: creating the same code again answered 409.
- Admin: the edit dialog stayed open after a successful save; a bulk action (activate / deactivate / delete) kept
  rows selected under a previous filter and reached rows hidden by the current one; a success notice of an earlier
  action could stand next to the error of the latest; notices, import mode and the import parse error in English;
  the door-type page footer (work stages) rendered outside the page frame; seen live: "Раздел: All".
- Library: `return_to` from the address was followed as is (an outside address could be navigated to); raw
  `ACTIVE` / `ARCHIVED`; a byte-order mark before "use client".

### Done
- Backend: creating a code that belonged to a deleted door type / reason brings that entry back (same id, new name),
  so history that names it stays linked; a live duplicate is still 409.
- Admin: the edit dialog closes on success; changing a filter clears the selection; the success notice hides while
  an error shows; messages, import mode and the filter name in the interface language; footer inside the page.
- Library: only an internal path is accepted as the return target (`safeInternalNextPath`); readable statuses; BOM
  removed.

### Checks
| Check | Mark | Evidence |
|---|---|---|
| Deleted code created again brings back the same entry; live duplicate 409 (door types and reasons) | confirmed by tests | `test_catalogs_and_settings_api.py` (new parametrized test); catalog, bulk/import, file import suites: 54 passed |
| Catalog pages, work stages, library | confirmed by tests | `DoorTypesPage`, `ReasonsPage`, `WorkStages`, `LibraryPage` tests (14) |
| Door types page: filter name and labels | seen live | demo stack |

### Review pass
- code-review (self): reviving instead of a migration keeps one row per code and the links of old rates / journals.
- security-review: the library no longer navigates to an address taken from the URL unless it is internal.
- simplify: no new helpers; the shared status labels reused.

### For the owner
- Catalog names are single-language (the product library has RU and HE names). Add HE/RU names to door types and
  reasons?

## 7. Prices and earnings (factory price list, extra work, stage earnings)

### Found (logic + visuals)
- Extra work: the office plans the type and the quantity, but the installer could record any quantity above the
  plan and be paid for all of it (online, offline and from the phone).
- Stages: the phone's time of a stage was taken as given. A stage dated before it was assigned, or under an older
  price version than the one in effect on receipt, was valued automatically. Doors and extra work already send such
  times to an office review.
- Price list, Contracts & billing and DIMAX AI pages: every routine access-token refresh (every 15 minutes) remounted
  the whole workspace. An unsaved new price version, an open dialog or a typed payment was lost.
- Price list pager: the range ("1-20 / 40") was reordered in Hebrew.
- My calendar and installers commits of sections 2 and 4 added raw pixel font sizes; the type-scale ratchet failed.

### Done
- Backend: a fact is refused when the recorded total plus the new quantity is above the plan (`ADDON_OVER_PLAN`,
  planned and done in the error). A replay of the same event is answered before the check. The project row lock
  serializes concurrent facts.
- Mobile: the same check against what the phone holds, with RU / HE text; the server stays the authority.
- Backend: a stage whose phone time is before its assignment, or under another price version than the one at
  receipt, keeps its fact and gets status `TIME_REVIEW` with nothing accrued. Office-recorded stages are taken as given.
- Backend + admin: "Confirm the time" on the door stages card (OWNER / OPERATIONS with the price authority, reason
  required). It values the stage at the rate in effect at its recorded time, once, audited `DOOR_STAGE_TIME_CONFIRMED`.
  With no rate of that time it refuses and accrues nothing.
- Admin: the three financial pages drop their open work only when the signed-in person changes (sign-out, a failed
  refresh, another account), not on a routine refresh. Pager range kept left to right. Pixel sizes replaced by the
  type-scale tokens.

### Checks
| Check | Mark | Evidence |
|---|---|---|
| Extra work above plan refused on direct and sync paths; rest of plan still recordable; replay not counted twice | confirmed by tests | `test_addons_api.py::test_addon_quantity_is_bounded_by_the_office_plan`; add-on, sync, payroll, e2e, offline suites: 216 passed |
| Phone refuses above plan, allows exactly the rest | confirmed by tests | mobile `service.test.ts` (75 sync tests) |
| Stage before assignment / under an older version: fact kept, `TIME_REVIEW`, no earning; confirm values at the old version's rate once; no rate of that time refused | confirmed by tests | `test_stage_earnings.py::test_stage_time_the_server_cannot_vouch_for_is_not_valued`; stage, work-stage, offline authority suites |
| Routine refresh keeps the editor; another account drops it | confirmed by tests | `auth-session.test.ts`, `PriceListsPage`, `FactoryAccountingPage`, `DimaxAiPage` tests (71) |
| Confirm-time control and its absence for viewers | confirmed by tests | `WorkStages.test.tsx` (6) |
| Ratchets, admin and mobile type checks | confirmed by tests | ratchets 2/2; tsc: only the 5 known errors in the other agent's tests; mobile tsc clean |
| Price list page and editor after the API restart | seen live | demo stack, session kept |
| Over-plan refusal on demo data | not verified | the demo installer's project has no plan; tests cover both paths |
| Outbox health architecture tests | not verified | 3 known failures of the test fixture, section 12 |

### Review pass
- code-review: 7 findings. Fixed: no way to resolve `TIME_REVIEW` (confirm-time added). A plan-floor rule was tried
  and reverted, because the existing design deliberately allows removing a plan with recorded work ("missing plan"
  in the summary). The rest are below, for the owner, or in section 15.
- security-review: no findings. The new endpoint is company-scoped, needs the planner scope plus the live price
  authority, and takes no price from the request.
- simplify: clean; the authority check follows the existing two-line pattern.

### For the owner
- A plan with quantity 0 now allows nothing. Should 0 mean "no limit" instead?
- Facts waiting in the offline price review are not counted toward the plan, so approving one later can be refused
  as above plan.
- A stage confirmed for time but without a rate of that time stays `TIME_REVIEW` (nothing is invented).
- Installer web cabinet: show what is left of the plan (section 15).

## 8. Contracts and billing (claims, agreements, reconciliation, payments)

### Found (logic + visuals)
- A claim reserved the journal row, not the work. A door listed again by a later signed journal (cumulative acts
  without partial acceptance) could be presented to the factory twice. The estimate also counted it twice, and it
  counted rows of journals that a re-signed journal had replaced.
- A new agreement could start inside work already presented or reserved in a package. The issued packages then
  disagreed with the agreement in effect for their days.
- After a package was corrected, the factory's dispute on the old version vanished from the totals until the factory
  answered again ("false all-clear").
- A refund was limited only by the payment's unallocated money. Money that still covered open packages, the opening
  principal or a held retention could be sent back.
- An ex-VAT payment could be allocated to an opening debt stated with VAT.
- Every billing refusal showed one generic text ("terms changed or the reference already exists").

### Done
- Backend (migration 0098): each claim line carries the work it presents (`DOOR:<door>`, `ADDON:<fact>`,
  `STAGE:<fact>`). The database allows one active line per work, and the period view keeps one line per work. The
  migration backfills existing lines and stops if a duplicate is already active.
- Backend: the estimate counts each piece of work once and skips replaced journals. The early-work list also lists
  each piece once.
- Backend: an agreement whose start date is on or before the latest presented or reserved work day of the contract is
  refused (`PRESENTED_WORK`, with the date).
- Backend + admin: a corrected version not yet answered carries the dispute of the version it replaced
  (`carried_dispute_ex_vat`). It is shown on the package and in the contract summary until the factory answers.
- Backend: a refund is limited to the overpayment at proposal and again at approval (`EXCEEDS_OVERPAYMENT`). The
  overpayment now subtracts everything still owed, a held retention included.
- Backend: allocating to an opening debt not stated ex-VAT is refused (`NEEDS_VAT_RULE`).
- Admin: billing dialogs and the claims panel name the actual refusal reason (RU / EN / HE).

### Checks
| Check | Mark | Evidence |
|---|---|---|
| A door in two signed journals: one claim line, one estimate line; a third act repeats it and stays claimed; the database refuses a second active line | confirmed by tests | `test_factory_claims.py::test_a_door_listed_by_two_signed_journals_is_presented_and_estimated_once` |
| Agreement inside presented work refused with the date; the next day allowed | confirmed by tests | `test_factory_claims.py::test_a_new_agreement_cannot_start_inside_work_already_presented` |
| Dispute carried to the corrected version and the summary until the factory answers | confirmed by tests | `test_factory_reconciliation.py::test_a_dispute_stays_in_view_until_the_factory_answers_the_correction` |
| Refund refused when the money still covers what is owed (held retention included); one approval reserves the whole overpayment | confirmed by tests | `test_factory_payments.py` (2 new tests) |
| Opening debt with VAT refused for ex-VAT money | confirmed by tests | `test_opening_balances.py` |
| All billing suites (commercial drafts, terms, approvals, activation, claims, reconciliation, payments, opening) | confirmed by tests | 119 passed, then payments 5 passed after the last change |
| Refusal reasons and carried dispute in the interface | confirmed by tests | `ContractPayments`, `ClaimReconciliation` and the other billing UI tests (36); lint, ratchets, tsc clean |
| Migration 0098 on the demo database; billing page loads | seen live | demo DB at `0098_claim_work_key`, column and index present; `/factory-accounting` renders (no contracts on demo) |
| Claim → answer → correction → payment → refund clicked through in the browser | not verified | billing flags are off on demo; the disposable stack needs a production build this host cannot run next to Docker today |

### Review pass
- code-review: 7 findings. Fixed: held retention counted as refundable; the agreement message now says "presented
  or reserved". Skipped, listed for the owner: reinstalled door, migration stop on existing duplicates, mixed VAT in
  opening figures. Skipped as minor: per-claim dispute lookup, the estimate's own copy of the row rule (an import
  cycle prevents reuse).
- security-review (inline): no findings. The new checks are company- and contract-scoped, and the new reason fields
  show only the contract's own figures.
- simplify: clean.

### For the owner
- A door reinstalled after a reversal is the same door and is not presented again. Should a reinstall be billable?
- If production data already holds the same door in two active packages, migration 0098 stops. Cancel or correct one
  package first.
- Opening figures add VAT-inclusive and ex-VAT rows into one principal. Keep them apart until the accountant gives
  the VAT rule?
- Stage lines of a "full installation" contract are never presented (owner decision of 2026-10-23, still waiting for
  the stage-rate decision).

## 9. Earnings ledger

### Found (logic + visuals)
- A retry of the same correction after a lost answer got 409 "already corrected". The office could not tell its own
  success from a conflict.
- A correction to the same rate was accepted and wrote a reversal plus an identical correction row.
- The correction dialog showed no money effect before saving, and an error of an earlier row stayed when the dialog
  was opened for another row.
- The project filter loaded only the first 50 projects. A deep link to a later project disabled the ledger as "not
  in scope".
- Seen live: every card showed the raw entry id when a door had no code ("7fc5f4f4-…"). "Addon" and "Door + addon"
  appeared in the English labels.

### Done
- Backend: the same correction again (same rate and reason) returns the saved result. A different second correction
  is still 409. A correction to the recorded rate is refused (422).
- Admin: the dialog shows now / after / difference (quantity × rate) and that a correction cannot be undone. The same
  rate is flagged and not offered. Opening the dialog clears an earlier error. All projects are loaded for the
  filter. Raw ids are no longer shown on cards (they stay in the CSV). Labels read "Extra work" and "All work".

### Checks
| Check | Mark | Evidence |
|---|---|---|
| Replay returns the same correction and writes nothing new; another correction 409; same rate 422 | confirmed by tests | `test_earnings_corrections_api.py`; with stage earnings and payroll lifecycle: 35 passed |
| Preview, same-rate block, deep links, filters | confirmed by tests | `EarningsLedgerPage.test.tsx` (8); lint, ratchets, tsc clean |
| Dialog preview on demo data (80 → 95, +15), save blocked without a reason; nothing saved | seen live | demo stack |

### Review pass
- code-review (inline): the replay matches the exact rate and reason; a changed reason is a new request and stays 409.
- security-review (inline): no new surface; the same OWNER/rates guard and the factory-confirmed refusal apply first.
- simplify: clean.

## 10. Reports

### Found (logic + visuals)
- Missing data looked like real data: the shared number formatters showed "0" / "0.00" for a report that had not
  loaded or had failed. The installer insight card showed 0 doors in that case.
- A period whose start is after its end returned empty reports (zeros) instead of an error.
- The report library claimed 6 / 7 / 6 / 4 reports per group while listing 3 each, so "23 report signals" was
  invented. Badges "new" and "pinned" did not reflect any state.
- Mixed language seen live (Russian interface): the installer insight card and the whole library in English; "API-прежде
  всего, никаких поддельных отчетов"; "прямые репортажи"; "12 сигналы", "1 объектов", "3 отчётов"; SLA block "DANGER",
  "IMPORT FAILURE RATE (24H)", "0pct", "0count", "ПРЕДУПРЕЖДАТЬ"; playbooks in server English; risk drivers "Profit
  Gap", "Delayed Profit"; issue stages TRIAGED / IN_PROGRESS; "P1 Открыть"; "Статус PROBLEM"; sort options "Installed
  Doors", "Payroll", "Desc"; audit filters as raw codes; "all channels"; "NIS" next to "ILS".
- The outbox card read "Ошибка | Просрочено N" with only the overdue count after it.

### Done
- Admin: missing numbers show "-" (a real zero is still 0). The installer card shows "-" and "No data yet" until its data
  is in. Library counts come from the rows shown; only the "live" badge stays, translated.
- Admin: every listed text in the reader's language with correct plural forms. Server codes are mapped to readable names
  by code (SLA metrics, playbooks, risk drivers, audit entities and actions), and statuses go through the shared status
  labels. The outbox card reads "failed N · waiting over 15 min M". Currency is ILS everywhere.
- Backend: a reversed period is refused for every report (422, field `date_from`).

### Checks
| Check | Mark | Evidence |
|---|---|---|
| Reversed period 422 on report endpoints; an ordered period still 200 | confirmed by tests | `test_reports_api.py`; with catalog audit and OpenAPI suites: 47 passed |
| Formatters: missing is "-", zero is 0 | confirmed by tests | `formatters.test.ts` |
| Reports page sections, localized playbook / metric names, no raw "DANGER" | confirmed by tests | `ReportsPage.test.tsx` (27), `IssueExposureBasis`, `IndexPage`, `ProjectsPage`: 99 passed |
| Russian page scanned live for English leftovers | seen live | demo stack: only data names (projects, door codes, a demo reason "Blocked opening") remain in Latin script |

### Review pass
- code-review (inline): codes keep their filter values; only the visible text changed. The period check skips mixed
  timezone forms and malformed dates, which the endpoints answer themselves.
- security-review (inline): no new surface; the period check runs before the endpoint and returns no data.
- simplify: the labels are one map per family (by code) instead of per-render switches.

### For the owner
- Reports have no period limit and no cache, and they share the database pool with phone sync (analysis finding).
  Should long periods be limited, or reports moved to a read replica?

## Answers to the "For the owner" questions (sections 1-10)

One rule set decides every answer, so they agree with each other:
1. Money follows confirmed, recorded work, paid at the price of its execution time.
2. The same work is never paid or presented twice.
3. No price and no VAT is ever guessed.
4. Exceptions are made by the office explicitly, with a reason, in the audit log.

| Question | Answer | Why (rule) | Done |
|---|---|---|---|
| 1. Paused / cancelled object: refuse work? | Yes, from the moment the office paused or cancelled it. Work done before still counts when the phone syncs late. The office records exceptions itself. | 1, 4 | 0099 `lifecycle_changed_at`; door, stage and extra-work paths of the installer refuse later work (`PROJECT_ON_HOLD` / `PROJECT_CANCELLED`) |
| 3. Issue workflow transitions | Keep them free for the office. Every move is audited, and the closing rules of step 5a already guard closing. | 4 | no change |
| 4. Account picker | Built with user management (section 13), not before: a picker needs an account list. | — | section 13 |
| 5. Cumulative acts | Money is safe either way: a door is presented and estimated once (0098). Switching partial acceptance on (acts list only new work) is a deploy setting, to be done after its acceptance on the real stack. | 2 | 0098; setting left to the deploy |
| 6. Catalog names in RU / HE | Yes, as a separate step (names for door types and reasons, then PDF and phone). Not a money question. | — | later step |
| 7a. Plan quantity 0 | 0 means nothing planned yet, so nothing can be recorded. The office plans the quantity. The admin form now says so. | 1, 4 | hint under the planned quantity |
| 7b. A reviewed offline fact above plan | The approval is refused with the reason. The office raises the plan first, then approves: the plan stays the authority. | 1, 4 | no change (the refusal already names the plan) |
| 7c. Time confirmed, no rate of that time | The confirmation is recorded. The stage then shows the truth (no rate / no factory prices then), and nothing is invented. | 3, 4 | confirm-time records always; status leaves `TIME_REVIEW` |
| 7d. Remaining plan in the web cabinet | Yes. | 1 | section 15 |
| 8a. Reinstalled door billable? | No. A door is paid by the factory once. A redo is a fix, and fix reports never earn (step 5a). | 2 | no change (0098 already keys by door) |
| 8b. 0098 stops on existing doubles | Correct: a double presentation must be resolved by the office (cancel or correct one package), never silently. | 2, 4 | no change |
| 8c. Opening rows with VAT | Keep them apart: only ex-VAT rows join the figures. A VAT-inclusive row is shown as "kept apart until the accountant gives the VAT rule". | 3 | `needs_vat_rule` in opening figures; principal never negative |
| 8d. Stage lines of a full-installation contract | The factory pays per door: the door line is presented, and stage facts are the installers' split. A stage contract waits for the stage-rate decision. | 1, 2 | no change |
| 10. Report periods | An explicit period is limited to one year (reports run live on the database that serves sync). Exact figures stay live, with no cache. A read replica is an infrastructure step. | — | 422 above 366 days |

Found while answering question 1: the database check on the project lifecycle came from 0038 (PLANNED, ACTIVE,
COMPLETED, ARCHIVED), and 0055 added the right list only "if not exists". A database built from scratch (the demo
database included) therefore refused ON_HOLD and CANCELLED: pausing or cancelling an object answered 500. Migration 0099
replaces the check with the model's list and stops if a project holds an unknown status.

## 11. Documents (templates, generation, downloads)

### Found (logic + visuals)
- File names: every letter outside Latin became "_" (a Russian or Hebrew template file turned into "____.docx"). Generated
  documents were named "document-1a2b.txt", and the download header was built from the raw name (quotes, non-Latin
  letters).
- Manual fields had to be typed as JSON in a text box ("Manual fields JSON").
- Messages only in English ("Template uploaded", "Failed to …", "Project is required"). Statuses "ACTIVE", "ARCHIVED",
  "READY" raw. The object list stopped at 200, and "Объекты" / "Проект" were mixed on one screen.
- Template upload, archive / restore and document generation were not in the audit log.
- A DOCX could unpack to any size, and the "date.today" field was the server's UTC day.
- The client read only `filename="…"`, so a UTF-8 name would have been lost even after a server fix.

### Done
- Backend: names keep letters of any language (path parts and unsafe signs removed). Storage keys stay ASCII.
  Generated documents are named "template - object code - Israeli date + short code" (unique). Downloads send RFC 6266
  `filename*=UTF-8''…` with an ASCII fallback (shared helper `app/api/v1/downloads.py`). Audit actions
  DOCUMENT_TEMPLATE_UPLOADED / _ARCHIVED / _RESTORED and DOCUMENT_GENERATED (manual field names, not values). A DOCX
  that unpacks above 50 MB is refused. A blank typed value counts as missing on the server too.
- Admin: one labelled input per field the object data does not hold (no JSON). Messages and statuses in the interface
  language. All objects loaded, the word "object" used throughout. The shared download helpers reused, and the client
  reads the UTF-8 name first.

### Checks
| Check | Mark | Evidence |
|---|---|---|
| Hebrew file name kept and downloaded with its UTF-8 name; readable unique document names; audit rows; blank field refused | confirmed by tests | `test_documents_api.py` (new test + blank case) |
| Header safe against quotes and line breaks; empty name | confirmed by tests | `tests/architecture/test_attachment_disposition.py` |
| Oversized DOCX refused on upload and render | confirmed by tests | `test_documents_docx_rendering.py` |
| Manual field typed in its input before generating; filename parser | confirmed by tests | `DocumentsPage.test.tsx` (7), `download.test.ts`; lint, ratchets, tsc clean |
| Documents page with object fields on demo data | seen live | demo stack (no templates on demo; upload not driven: the browser pane cannot attach a file) |

### Review pass
- code-review: 5 findings. Fixed: same-day duplicate names, UTC date, blank manual field. Skipped: overriding an object
  field for one document (owner question below) and ASCII-only template codes (internal only).
- security-review (inline): no new issue. Header injection closed; no path from the name into storage; DOCX unpack
  bounded; values escaped in HTML templates, and files are served only as attachments.
- simplify: duplicated download helpers removed in favour of `src/lib/download.ts`; JSON parsing helpers gone.

### For the owner (answered by the same rule set)
- Changing an object field for one document only (the old JSON allowed it): the object data is the source of truth.
  A one-off change belongs in a manual field of the template, so the document says what was typed and the object stays
  right (rule 4: exceptions explicit). No change.

## 12. Operations and outbox

### Found (logic + visuals)
- False all-clear: when a source failed or had not answered yet, the tiles showed a green 0. The header said "Система в
  норме · 0 инцидентов", and the integration rows said "в норме · очередь доставки чиста" (seen live right after an API
  restart).
- "Retry all" for deliveries and imports used the 8 items previewed on the page; the rest were silently left out.
- The bulk outbox retry accepted a list of any length.
- Tile statuses "WARN" / "OK" and incident kinds "IMPORT" / "SYNC" raw.
- 3 failing architecture tests in `test_outbox_health.py`: the worker drains up to 20 one-message batches per pass
  (commit 6462010), but the mock returned the same message forever (mark_failed called 20 times). The fixture was
  wrong; the worker was right.

### Done
- Admin: a source that failed shows "-" and "Data did not load", and one still loading shows "Loading…" (orange, never a
  green 0). The header says "Checking the systems…" until every source answered, and "Some data did not load" after a
  failure. Integration rows say "checking…" / "data did not load" instead of "nominal".
- Admin: "Retry all" first loads the full failed lists (deliveries up to 200 per run with the channel filter, imports up
  to 100 = the server limit) and retries them all. The confirmation names the real count. Tile statuses and incident
  kinds are translated.
- Backend: the bulk outbox retry takes 1 to 200 ids.
- Tests: the outbox-health fixture gives one message, then an empty queue (no worker change).

### Checks
| Check | Mark | Evidence |
|---|---|---|
| Worker health tests | confirmed by tests | `tests/architecture/test_outbox_health.py`: 25 passed |
| Bulk retry bounds; outbox, RBAC, audit, OpenAPI suites | confirmed by tests | 44 passed |
| Unknown never green; header "Some data did not load"; retry-all over the full scope with real counts | confirmed by tests | `OperationsPage.test.tsx` (18), with `IndexPage`: 27; lint, ratchets, tsc clean |
| Operations page after load (2 incidents, real tiles); "Data did not load" during the API restart | seen live | demo stack |

### Review pass
- code-review (inline): the full-scope fetch is filtered by channel on the client as well; the confirm text falls back
  to the preview count while the summary is missing.
- security-review (inline): no new surface; the server bound limits a bulk retry to 200 ids.
- simplify: the "unknown" state is one pair of notes reused by all tiles and rows.

## 13. Settings and users

### Found (logic + visuals)
- No user management for the company: accounts could be created only by the platform operator with a service token.
  The owner could not see, add, switch off or re-scope the company's accounts, although the `can_manage_users` flag
  existed. Nobody could change their own password.
- Consequence (section 4 question): an installer account could be linked only by typing an id.

### Done
- Backend `/admin/users` (needs the right to manage users): list; create an office or installer account (the server
  generates a one-time password, shown once; an installer account can be linked to its installer card at creation);
  rename, change access, switch off (every session revoked at once) or on; reset a password (sessions revoked, new
  one-time password). `/auth/change-password` lets the signed-in person change their own password (current one checked,
  at least 10 characters, every session ends, rate-limited like login). Audit USER_CREATED / USER_UPDATED /
  USER_PASSWORD_RESET / USER_PASSWORD_CHANGED, never with a password.
- Rules: nobody changes, switches off or resets their own account here; the company keeps at least one active owner;
  only an owner gives owner access or the right to manage users. A non-owner never creates, raises or resets an account
  beyond their own access (they see the one-time password, so this would be a way to sign in with more rights; found
  in the security review).
- Admin Settings: "Company users" (rows with access selector, switch off/on and new password behind a confirmation,
  your own row marked and locked; add form with office / installer app, access or installer card; the one-time password
  panel with a copy button and "shown once"), and "My password" for everyone.

### Checks
| Check | Mark | Evidence |
|---|---|---|
| Create, sign in, switch off (sessions revoked, sign-in refused), switch on, reset (old password refused); no password in audit | confirmed by tests | `test_company_users_api.py` |
| Own account and last owner protected; owner-only grants; installers refused; installer account linked; own password change | confirmed by tests | same file (6 tests) |
| A non-owner cannot hand out or take over more access than they have | confirmed by tests | same file, escalation test |
| Login rate limit, RBAC matrix, OpenAPI, architecture suites | confirmed by tests | 204 passed, then 9 after the guard |
| One-time password panel, confirmation before switching off, own row locked, password form | confirmed by tests | `CompanyUsers.test.tsx` (3); lint, ratchets, unlabeled-controls guard, tsc clean |
| Settings page on demo: 3 accounts, own row marked "вы" and dimmed actions, installer card shown | seen live | demo stack (no account created or changed: accounts are not touched without the owner's approval) |

### Review pass
- code-review (inline): the email check covers switched-off accounts (unique per company); sessions are revoked with
  the company scope; each route checks the right inside its own unit of work.
- security-review (inline): one finding fixed (non-owner escalation through the one-time password). Passwords are only
  in the create / reset responses (no-store), hashed at rest, never audited; switching off revokes sessions, and every
  request re-checks that the user is active.
- simplify: reuses the platform rules (limits, hashing, admin profile) and the installer link service.
- frontend-design: follows the admin's design system; the one memorable element is the one-time password panel.

### For the owner (answered by the rule set)
- First sign-in with a one-time password does not force a change yet; the person changes it in "My password". Forcing
  it would need a login flag and a phone-app screen (section 16).

## 14. DIMAX AI

### Skill choice
- `claude-api` does not apply: the module is built on the OpenAI Responses API (`AI_PROVIDER=openai`), and the skill
  is for Claude/Anthropic code. Switching the provider is an owner decision, not a fix.
- The quality skill used is an independent security review of the agent by a separate reviewer (read-only, not
  anchored on my reading), plus the test suites and a live check.

### Found (logic + visuals)
- The independent review found no exploitable issue. Verified protections:
  - Every stored conversation, task and proposal is scoped to company + owner.
  - Tool rights are re-checked against the live role and scope on every call.
  - The selected object is loaded with the user's rights before any model call.
  - No business write happens without the human confirmation.
  - Replay, expiry and version checks guard execution.
  - No key or provider body reaches logs, errors or the audit log.
  - The answer is rendered as plain text (no markdown or image exfiltration).
- Below the bar, both confirmed in the code:
  - A confirmation interrupted between its two phases stayed CONFIRMED and could execute later with the same request id,
    after the proposal expired.
  - FINANCE received `installer_workload`: counts of doors and issues by status, which that scope cannot read directly.
- Live: the page says honestly that the demo provider answers and no real model is connected. Answers come from system
  records with source links.

### Done
- Phase 2 of a confirmation checks the expiry: an expired stuck proposal becomes EXPIRED (audited) and never executes.
- FINANCE no longer gets `installer_workload` (the same rule as `search_projects` and `import_inbox`).

### Checks
| Check | Mark | Evidence |
|---|---|---|
| All AI suites (admin, actions, installer, memory, rules, worker) | confirmed by tests | 140 passed / 4 skipped before; 77 passed after the fixes |
| Stuck confirmation after expiry never executes; FINANCE tool list | confirmed by tests | `test_dimax_ai_actions.py`, `test_dimax_ai.py` |
| AI page with demo provider, sources and the honest connection note | seen live | demo stack |
| A real model answering | needs external infra | no provider key on this machine (and none should be read here) |

### For the owner
- The company's daily AI limit is shared: any user, a viewer or an installer, can use it up for everyone. A per-person
  share would keep the office working.
- Connecting a real model needs the provider key in the server environment (OpenAI as built). Moving to Claude would
  be a separate step, done only on your decision.

## 15. Installer web cabinet

### Found
- Extra work: the form offered every company type, not only the planned ones. The installer saw only the planned
  quantity, not what was left after everyone's work, and learned about the over-plan refusal (`ADDON_OVER_PLAN`,
  section 7) only after sending.
- Each click of "Queue extra work" made a new event key. A second click after a lost answer could record the work
  twice.
- Schedule:
  - The "Overdue only" filter looked forward from now, so it was always empty.
  - Past events were painted red like a problem.
  - Event types and objects were shown as codes and ids, in the cards, in both filter lists and in the
    "Focused project" chip.
- Live: with the past window on, "Next 7 days" still looked chosen, and the "Preset 7D" chip stayed although no forward
  range applied.
- The web cabinet needs the network but said nothing when it dropped.
- The installer had no place to replace the password the owner gave them (section 13).

### Done
- Backend:
  - The installer object answer gives `qty_left` per extra-work plan: the plan minus everything recorded on it, the same
    number the server bounds facts by.
  - Calendar events carry `project_name`, looked up within the caller's company only.
- Admin, extra work:
  - Only planned types are offered; with no plan the form says so and stays disabled.
  - A "left of the plan" hint is announced to screen readers. Over the plan it explains what to ask the office, and
    sending is disabled.
  - One event key per entry: a retry after a lost answer reuses it, and a changed form gets a new one.
- Admin, schedule:
  - "Past 14 days" looks back 14 days.
  - Past events are muted, with a "Past" word, not colour alone.
  - Types and object names appear in words everywhere.
  - The past window and the forward ranges exclude each other: picking a forward range turns the past window off.
  - The event-type labels moved to `src/lib/event-types.ts`, shared with the office calendar.
- Admin, shell and workspace:
  - An offline banner sits in a permanent live region.
  - The installer workspace has the "My password" card. The mismatch error is tied to the field.

### Checks
| Check | Mark | Evidence |
|---|---|---|
| `qty_left` on the installer object; `project_name` on installer calendar events; contracts | confirmed by tests | backend 104 passed (calendar, audit boundary, installer phase 2, OpenAPI, addons, installer projects) |
| Planned-only form, left hint, key reuse; past window; names in words; exclusive ranges; offline banner; password card | confirmed by tests | admin 56 passed (6 files); lint, ratchets 3/3, tsc only the 5 known errors |
| Past window request (Oct 17 → Oct 31), exclusive range buttons, offline banner text, password card, "office has not planned" with the button disabled | seen live | demo stack, seeded installer on localhost |
| Left hint and object names with real data | confirmed by tests | the demo installer has no calendar events or extra-work plan; none were created (that would change assignments) |
| Changing the password from the cabinet | confirmed by tests | not submitted live: it would change an account |

### Review pass
- Code review: the past filter, its URL state and the forward ranges are consistent. The name lookup moved into one map
  shared by the option, the chip and the card.
- Security: `project_name` comes from a company-filtered query over events the installer may already see. `qty_left`
  is a quantity, not money, and only for objects the installer is assigned to. The password form uses the existing
  endpoint, which asks for the current password.
- Accessibility (WCAG 2.1 AA): past is said in words; the offline banner and the plan hint are announced; the error
  is tied to the field. Measured contrast: 4.96:1, 5.26:1, 5.4:1.

### For the owner
- A forced password change at first sign-in (a section 13 question) would send the installer straight to this card;
  today it is a choice.

## 16. Mobile app (offline queue and sync)

### Found
- Offline time used up the retries. Every sync without a connection counted as a failed delivery: 8 attempts at
  1, 3, 10, 30 and then 60 minutes. After about 4.7 hours offline, the installer's work turned BLOCKED.
- Work stopped by the retry limit never went out again by itself. The office did not see the installation until the
  installer pressed "Retry".
- When the server refused the account on the whole request (403: switched off, role changed), the phone split the
  queue in halves as if one event were malformed. It then blocked every event and rolled back the local door
  statuses, so done work looked undone.
- A per-event `AUTH_REQUIRED` answer (the session, not the work) also rolled the local state back.
- The release of `AUTH_REQUIRED` work ran with every minute's sync, not once per sign-in. The provider test mocked the
  sync module without that function, so this path never ran in tests.

### Done
- No connection is not a failed delivery:
  - A request that never reached the server gives its attempt back and goes again with the next sync (every
    minute), however long the phone stays offline.
  - A timeout still counts as an attempt, because the server may have received the request
    (`RequestTimeoutError`, a kind of `NetworkError`).
- A server that answers again releases the work the retry limit stopped in earlier syncs. The release happens before
  the answer's acks, so work the same answer stops again waits for a later one. The queue text says it goes by itself
  once the server answers. The manual retry stays.
- A refused account is not about any event:
  - A 403 on the whole request is never halved and nothing is rolled back.
  - The work waits as `AUTH_REQUIRED` ("Sign in again") and goes after the next sign-in.
  - A per-event `AUTH_REQUIRED` follows the same rule.
- `AUTH_REQUIRED` work is released once per sign-in, not every minute. Otherwise a refused account would resend the
  whole queue each minute.
- Not changed: real verdicts on the work (conflicts, validation, factory price) still block and roll back as before.

### Checks
| Check | Mark | Evidence |
|---|---|---|
| Offline gives the attempt back (even the 8th); a timeout still counts and blocks at the limit | confirmed by tests | `service.test.ts`, `policy.test.ts`, `api.test.ts` |
| 403 on the request: one request, no halving, all parked as `AUTH_REQUIRED`, no door rollback; per-event `AUTH_REQUIRED` keeps local state | confirmed by tests | `service.test.ts` |
| Retry-limit work released after a server answer, not after a failed one | confirmed by tests | `service.test.ts` |
| `AUTH_REQUIRED` released once per sign-in across minute syncs | confirmed by tests | `AppProviders.test.ts` (fails when the guard is removed) |
| The five new service tests fail on the old code | confirmed by tests | the old `service.ts` was run against them: 5 failed |
| Whole mobile suite and types | confirmed by tests | 870 tests in 69 files; `tsc --noEmit` clean; test discovery contract 69/69 |
| The same on a phone (offline for hours, then back) | not verified | no phone attached to this machine (`adb devices` empty); recipe in the acceptance device memory |

### Review pass
- Code review: every send failure goes through one decision, `recordSendFailure`: offline, refused account,
  transient server failure, or verdict. The halving path and the per-half path use the same rule.
  `isRetryableSyncError` is unchanged, so other callers keep their meaning.
- Security: nothing new crosses the network. A refused account no longer triggers 2N requests from halving, and no
  longer resends the queue every minute.
- Load: the release is one UPDATE per successful sync that matches no rows in the normal case.

### Decision (owner: "do it the way you think is right")
- The batch rule for server errors is left as it is, because the server already isolates a bad event. Each event runs
  in its own savepoint (`sync/application/service.py`). An unexpected failure becomes that event's `SERVER_ERROR` ack,
  the phone retries that event alone, and the rest of the batch is applied.
- So a 5xx on the whole request means the server or the network in front of it is down. Splitting the batch then
  would only multiply requests during an outage.
