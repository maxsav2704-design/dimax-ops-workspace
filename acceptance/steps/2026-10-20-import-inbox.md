# Document import inbox: factory files imported without a click (2026-10-20)

Owner's request (chat, 2026-10-19): go through the tool that loads documents with project and door
information; it must work automatically ("я стремлюсь к автоматизации").

Marks: **confirmed by tests**, **studied by code**, **seen live** (browser pane, demo stack),
**not verified**, **needs external infra**.

## 1. What the import tool was before this pass (studied by code)

| Area | State | Evidence |
|---|---|---|
| Parsers | csv/txt/tsv/json/xml/xlsx/pdf (pypdf, OCR fallback), five mapping profiles with auto-detection, column diagnostics, row errors with fixed messages | `backend/app/modules/projects/application/file_import_service.py` |
| Endpoints | `POST /admin/projects/{id}/doors/import`, `/import-file`, `/import-upload` (multipart, 20 MB), analyze / import modes, partial import flag, import runs with fingerprint idempotency, failed queue, retry, review / reconcile latest | `backend/app/modules/projects/api/admin.py` |
| Admin | `DoorImportWizard` (file → analyze → import, options), import history, failed queue card on the Operations page | `dimax-operations-suite-main/src/components/projects/` |
| Automation | None: every file needs an admin to open the project, choose the file, press analyze and then import | — |

The parsing and import core is solid and stays untouched. What was missing is the step before it:
a file arriving on its own, being routed to the right project and imported when it is clean.

## 2. What was built

**Import inbox** (backend migration `0083_import_inbox`, `ImportInboxService`,
`app/workers/import_inbox_worker.py`, admin `ImportInboxCard`):

1. A factory file enters the inbox through one of three channels: an upload without choosing a
   project (`POST /api/v1/admin/projects/import-inbox`, multipart, optional `project_id`), a watched
   folder (`IMPORT_INBOX_DIR/<company_id>/`, moved to `processed/` or `failed/`), or a mailbox
   (`IMPORT_INBOX_IMAP_*`, unseen messages from `IMPORT_INBOX_ALLOWED_SENDERS`, supported attachments).
2. The file is deduplicated by sha256 per company (the same manifest from mail and folder is one item),
   stored in MinIO, parsed with the existing parsers, the mapping profile detected, the order numbers read.
3. The project is matched: order numbers already present on the company's doors (`ORDER_NUMBER`), the
   project code in the file name (`PROJECT_CODE`), the project name in the file name (`PROJECT_NAME`).
   One candidate → matched; zero or several → `NEEDS_PROJECT` with candidates for the office.
4. The existing import service runs an analysis on the matched project. When the company policy
   `import_auto_commit` (default on, owner-only switch) is on and the analysis has zero row errors, no
   missing required columns and at least one prepared row, the existing import runs at once
   (`IMPORTED`, audit `IMPORT_INBOX_AUTO_IMPORTED`). Otherwise the item waits as `ANALYZED` with the
   summary and the first errors.
5. The office decides the rest in the **Document inbox** card on the Operations recovery page: choose
   the project and import, import valid rows only (partial import through the same service flag), or
   dismiss. Decided items are hidden behind "Show decided". The card shows source (upload / folder /
   mailbox), detected profile, match reason, rows / to import / skipped / errors and the first errors.
6. DIMAX AI gets a read tool `import_inbox` (admin, hidden from FINANCE, guarded by the same
   manage-imports permission as the endpoints); file names and errors are passed as untrusted text.

Nothing bypasses `ProjectFileImportService`: idempotency by fingerprint, import runs, door type
creation and partial-import rules are the existing ones. No price is read from the file into
earnings; `default_our_price` stays 0 as in the wizard. Audit rows of the automatic channels have no
user: `ck_audit_external_factory_actor` now also allows `entity_type='import_inbox'` with
`after->>'source' IN ('FOLDER','EMAIL')`; every inbox audit row names its source.

Settings (`backend/.env.example`): `IMPORT_INBOX_DIR`, `IMPORT_INBOX_COMPANY_ID` (files in the root
folder), `IMPORT_INBOX_POLL_SEC`, `IMPORT_INBOX_IMAP_HOST/PORT/USER/PASSWORD/FOLDER`,
`IMPORT_INBOX_IMAP_COMPANY_ID`, `IMPORT_INBOX_ALLOWED_SENDERS`. Demo stack: service
`import-inbox-worker` in `docker-compose.workspace.yml` watching `./artifacts/import-inbox` (git-ignored).

## 3. Verification

| Check | Mark | Evidence |
|---|---|---|
| Known order number routes the file to its project and imports it with no click; the same file again is one item and no second import; audit RECEIVED + AUTO_IMPORTED | confirmed by tests | `tests/integration/test_import_inbox.py::test_known_order_number_matches_the_project_and_imports_without_a_click` |
| Unknown document waits for a project; manual commit imports; decided items refuse a second decision (409) | confirmed by tests | `::test_unknown_document_waits_for_a_project_and_then_imports` |
| Project code or name in the file name routes the document | confirmed by tests | `::test_project_code_or_name_in_the_file_name_routes_the_document` |
| Row errors stop the automatic import; whole-file commit is refused and stays ANALYZED; partial import takes the valid rows | confirmed by tests | `::test_row_errors_stop_the_automatic_import_and_the_office_allows_a_partial_one` |
| Policy off keeps clean files waiting; only OWNER changes the policy (403 for OPERATIONS) | confirmed by tests | `::test_policy_off_keeps_clean_files_waiting_and_only_the_owner_changes_it` |
| Unsupported format → 422; broken workbook → FAILED with the parser message, can be dismissed | confirmed by tests | `::test_unsupported_and_broken_files_are_recorded_not_lost` |
| Inbox is private to the company (another company's admin sees nothing, commit → 404) | confirmed by tests | `::test_inbox_is_private_to_the_company` |
| Folder worker ingests per-company subfolders, ignores unsupported files and root files without a default company, moves to processed/, is idempotent | confirmed by tests | `::test_folder_worker_ingests_dropped_files_per_company` |
| Mailbox feeder takes supported attachments from allowed senders only and marks messages seen | confirmed by tests (fake IMAP fetcher) / needs external infra (real mailbox) | `::test_mailbox_feeder_takes_attachments_from_allowed_senders_only` |
| Existing import, AI, factory-contact, work-price and audit suites still green after the audit constraint change | confirmed by tests | 141 passed (`test_project_file_import_api`, `test_dimax_ai*`, `test_factory_contact_authority`, `test_work_price_approvals`, `test_audit_coverage_api`, `test_import_inbox`) |
| Admin card: hidden without import permission; project choice + import; partial import; upload posts FormData; owner policy toggle; non-owner disabled | confirmed by tests | `src/test/ImportInboxCard.test.tsx` (5), `src/test/OperationsPage.test.tsx` still green with the card mounted |
| Admin gates | confirmed | `tsc --noEmit` clean, eslint clean on the three files, type-scale and RTL ratchets pass (raw `text-[11px]` replaced by scale tokens) |
| Live, folder channel: `factory SH26006387 batch folder.csv` dropped into `artifacts/import-inbox/<demo company>/` → worker log `-> IMPORTED`, item `FOLDER / IMPORTED / ORDER_NUMBER`, 2 doors added to "צרפתי שמעון — בניין 1" (580 → 582), file moved to `processed/`, audit rows with system actor | seen live | demo db queries, worker log |
| Live, unknown order: `delivery report october.csv` → `NEEDS_PROJECT`, orders `SH99-UNKNOWN`; in the card (RU) the office chose the project and pressed "Импортировать" → `IMPORTED / MANUAL`, 2 doors (582 → 584), audit `IMPORT_INBOX_IMPORTED` with the admin as actor; "Показать решённые" lists both items with source, profile, match reason and counts | seen live | browser pane, demo db |
| Live, upload channel through the card | not verified live (the browser pane cannot pick a local file; the endpoint and the FormData upload are covered by tests) | — |
| Mailbox channel against a real IMAP server | needs external infra (no factory mailbox credentials on this machine) | — |

Demo stack observation: the whole stack is slow right now (MinIO read of a 182-byte object ≈ 6.5 s,
analysis ≈ 7 s, the manual commit request took 104 s on the 580-door project). The same import
service runs in the wizard with the same cost; the inbox adds the MinIO read only. If it matters in
production, the commit can move to the worker (the `NEW` status is reserved for that).

## 4. Demo data left on the demo stack

Two inbox items and four demo doors (`INBOX-FOLDER-901/902`, `INBOX-UI-1001/1002`, order
`SH26006387` and `SH99-UNKNOWN`) on project "צרפתי שמעון — בניין 1"; the two source files sit in
`artifacts/import-inbox/<company>/processed/` (git-ignored). Demo only; the acceptance database was not touched.

## 5. Open items

- Real mailbox run (credentials on the server; `IMPORT_INBOX_ALLOWED_SENDERS` should list the factory).
- Door identity for repeated factory rows follows the existing import rules (a row with the same
  marking is skipped as before); the inbox does not change them.
- PDF manifests go through the existing PDF/OCR parser; quality depends on the factory's layout as before.
