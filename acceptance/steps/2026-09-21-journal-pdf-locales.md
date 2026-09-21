# Journal PDF languages and long-document layout

## Scope

Completes the interrupted September 15 PDF localization step. No new business
workflow, logistics, required photograph, payroll change or live signature.

- Migration 0061 stores `journals.pdf_locale` (en/ru/he), with English as the
  backward-compatible default and a database check constraint. Existing archive
  files and references are not rewritten. Apply before loading the new models.
- Admin creation uses the interface language; the journal form can select a
  different document language. Saving is required before export or mark-ready.
  Header locks and ACTIVE/ARCHIVED/viewer restrictions remain in force.
- Language changes have their own audit entry under the existing transaction.
  The update locks the journal row, consistent with signing/mark-ready locking.
- Mobile preparation sends the current locale and caches the returned document
  language. Existing drafts keep their stored language; switching the interface
  language does not rewrite them. Legacy cached details may omit the new field.
- PDF system labels/statuses are localized; user titles, names and comments are
  preserved, not machine-translated. Hebrew columns/alignment are mirrored.
- Plain user text is escaped. Installed python-bidi is applied after ReportLab
  wraps each line, including explicit newlines, without mutating logical lines.
  No new dependency or optional private-index RTL package was installed.
- Tables repeat headings and can split oversized comments inside a row. All
  tables use the actual frame width. Signature, signer/date and final notice
  stay together. Unicode fonts are required; no missing-glyph Helvetica fallback.
- Existing signed PDFs remain immutable on download/resend. Draft exports still
  regenerate through the existing freshness rule. API changes are additive.

## Verification

- Disposable PostgreSQL: empty -> 0060 -> 0061 -> 0060 -> 0061 PASS. A legacy
  archived journal retained its file reference; default and constraint verified.
  The initial fixture lacked the required project address; corrected and rerun
  from a fresh disposable database. This was not a failed production migration.
- Both isolated databases, `dimax_acceptance_tests` and `dimax_acceptance`,
  upgraded successfully to 0061. The normal port-8000 workspace was not migrated
  or restarted in this step.
- Backend: 88 PASS, 144.76 seconds, exit 0, OOM false. Includes PDF layout,
  integrity/freshness, transaction boundary, signing links, snapshots, journal
  API/access, language persistence/locks/audit and real local Mailpit/MinIO.
- Admin: form 13 PASS; final separate JournalPage run 14 PASS, 35.81 seconds.
  The first combined run had a worker-start timeout. A later existing empty-
  templates test hit its one-second DOM wait; its initial async wait is now
  bounded at five seconds, with all action assertions retained. Three added
  cases verify creation language through the actual language provider.
- Changed admin files pass ESLint. Mobile journal service and account-isolation
  tests: 83 PASS, 6.22 seconds; full mobile TypeScript check exits 0.
- These are 198 focused tests across repositories, not the complete release gate.
- Final PDF visual inspection: all 10 rendered pages (EN 3, RU 4, HE 3), with
  35 doors, long comments, notes, mixed-script values, signature and numbering.
  No clipped text, shifted tables or orphan final notice in these fixtures.
  Russian's fourth page contains the complete acceptance/signature block.
- Earlier PDF tests exposed default pypdf extraction dropping Latin beside
  Hebrew. Visitor-based assertions check those Latin values; visual inspection
  verifies actual rendering. No content assertion was simply suppressed.
- No companies from this regression remain in the test DB. Eight older test
  companies date from September 10-14 and were deliberately left untouched.
  Tests remove their own mailbox messages and storage objects.

## Runtime and closeout

- Production Next 16 webpack build exits 0, including TypeScript and all 24
  static pages. Used the existing Next CLI directly with NEXT_DIST_DIR to avoid
  the wrapper's unrelated `.next` cleanup. API base is http://127.0.0.1:8001.
- New standalone build `journal-locale-20260921` runs on 127.0.0.1:4173, PID 11732.
  Its startup log reports ready and stderr is empty. Static/public files were
  copied using the established standalone layout and the CommonJS entrypoint.
  Only this build's generated next-env/tsconfig changes were undone, preserving
  the two preexisting working-tree differences exactly.
- Acceptance API initially exceeded Compose's health wait. It subsequently
  completed startup; fresh host `/ready` returns status=ok/database=ready. The
  gateway was started after this recovery. The initial failed start is not a
  successful health check and no local startup-performance approval is implied.
- Fresh browser loads the new build and renders the Russian login page without
  captured console errors. The old session expired over the interruption; the
  browser explicitly requests a new login. User sign-in was requested. The new
  selector's authenticated live-browser check remains NOT TESTED in this run;
  the 27 passing UI tests are not presented as that evidence. No password reset,
  token injection, live journal edit, mark-ready or send was performed.
- Local commits: backend `0754f49`, admin `c1d4eb3`, mobile `7125dbd`.
- Removed only five named one-off containers and the owned disposable migration
  database. Mailpit total is zero. Removed the owned PDF/PNG QA directory
  (2,675,326 bytes) and this build's cache (264,070,801 bytes). The running build,
  project dependencies, older test data and all business volumes remain intact.
- Backend/mobile working trees and admin/root diff checks are verified at final
  closeout. The two preexisting generated admin-file differences are excluded
  from the feature commit. No phone files or queues were touched.

## Boundaries

No email/WhatsApp was sent to a real recipient. Personal contacts were not put
in source or fixtures. Mailpit does not prove external delivery. No APK, phone
UI, native offline workflow or real customer signing was exercised this step.
The legacy communications-list terminology is outside this document-language
change. All supported content shapes have not been visually certified by the
ten-page sample. Full release remains NO GO; frozen criteria/weights unchanged.
Local Git only; no public GitHub push or remote backup is claimed.
