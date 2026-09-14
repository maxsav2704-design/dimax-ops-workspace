# Journal form: replace simulated actions with stored work

## Scope

Follow-up to the admin button audit. No production approval is implied.
Use the isolated acceptance environment on ports 4173/8001. No real signing,
external delivery, door completion, assignment or payroll change is authorized
by this test step. Local commits only under the existing publication restriction.

## Findings and implementation

- High: `/journal/[id]` rendered a local-only form, ignored the route ID and
  announced successful Save/Mark ready without making any backend request.
  A hard-coded document number and twenty empty inspection rows did not reflect
  the stored completed work. This was a reachable route, not an unused mockup.
- Connected the form to a company-scoped read-only snapshot endpoint and the
  existing PATCH, mark-ready, refresh-snapshot and authenticated PDF APIs.
  The old unsaved inspection controls were replaced by stored doors/addons;
  no persisted inspection data existed in that form and none was removed.
- Public and admin snapshots share one serializer of saved journal rows.
  Neither reads today's full door list to fabricate a historical snapshot.
  Existing public response fields are unchanged; the new admin response adds
  an unexpired signing URL when the journal is active and unsigned.
- Draft changes are visible, preserved on request failure, and confirmed only
  after a server read. Pending actions are guarded against repeated clicks.
  Back/sidebar navigation requires discard confirmation when dirty, and browser
  unload warns about unsaved/pending work. Route changes abort stale reads.
- ACTIVE/ARCHIVED and viewer forms are read-only. Mark-ready/PDF/snapshot refresh
  do not silently omit unsaved edits. A successful mark-ready remains read-only
  even if its follow-up GET fails. Existing section locks are preserved.
- High: PDF download/share reused an older generated unsigned file even after
  draft changes. Regenerate unsigned PDF before issuing it; keep an existing
  signed PDF unchanged. No changes to signature, payroll or door state rules.
- No schema migration is required: stored models and write DTOs are unchanged.

## Verification checkpoint

- New snapshot/filter contracts: 19 PASS, 41.71 seconds.
- PDF freshness/preservation: 4 PASS, 31.94 seconds, mocked storage only.
- Separate `dimax_acceptance_tests` integration run: 3 PASS, 4 deselected,
  11.33 seconds: admin/public signing flow, installer denial and cross-company
  isolation, including the new endpoint. The one-off container exited 0 and
  was automatically removed. The acceptance business database was not used.
- New form tests: 11 PASS in a standalone run. The initial two-file run had
  a worker startup timeout on JournalPage; it is not a successful full run.
- Final sequential frontend runs: new form 11 PASS (22.75 seconds), existing
  JournalPage 11 PASS (39.33 seconds), and ESLint for the two changed files PASS.
  Together with the backend checks above: 48 focused tests PASS, not a full gate.
- Production Next build with Node 20, webpack and API base `http://127.0.0.1:8001`
  completed with exit 0, including TypeScript and all 24 static pages.
- Backend commit `9f5b488`; admin commit `4ab4dec`. Local only; no remote backup.

## Live verification

- Test API restart had a prolonged unhealthy startup. A later `/ready` returned
  HTTP 200 with database ready and Docker health became healthy; cgroup counters
  reported zero OOM/kill events. Its first unhealthy responses were not a pass.
- New standalone build `journal-20260914` replaced only preview PID 19664;
  preview PID 6584 serves port 4173. Startup log reports ready, no stderr output.
- Browser list/auth reads intermittently showed network errors, then recovered
  using their existing read-only retry controls. The underlying cause of those
  transient browser failures is not established; no write was blindly retried.
- Exactly one marked QA draft was created in DIMAX Acceptance A:
  `3238f088-66a0-414f-a95d-da2ad965848f`, title `QA JOURNAL FORM 20260914`,
  project `6423143b-4122-4685-8f8f-20fe848bc8b7`. It remains a DRAFT fixture.
- New form displays the five stored installed doors and zero addons. A QA note
  was saved with server confirmation and survived a full page reload.
- Dirty state enables Save and disables Mark-ready/PDF. Sidebar navigation opens
  discard confirmation; Continue editing retains typed text. Back followed by
  explicit discard returns to the list without saving the temporary QA title.
- Reopening confirms the original QA title. Screenshot inspection at the current
  509px preview width shows a readable header/actions without overlaps. Main and
  article have no horizontal overflow; the work table scrolls inside its wrapper.
  Document/application view switches preserve the saved note. Desktop-wide visual
  acceptance and all PDF pages were not performed in this step.
- No live signature, mark-ready, PDF download, delivery or door/payroll mutation
  was performed. Integration signing tests ran only in the separate test DB.
- Removed this step's 11 generated Next cache files; retained the running build.
  Restored only Next-generated changes from this build, preserving the preexisting
  dirty next-env.d.ts and tsconfig.json. No phone storage or queues were touched.

## Remaining acceptance

This is not full PDF layout/language acceptance, external email delivery,
immutable archival metadata verification, concurrent editing acceptance or
native/offline journal acceptance. Those release criteria remain open.
The journal list's legacy terminology and mixed-language labels also still need
a separate, scoped UX/localization pass; this step fixed the document form.
