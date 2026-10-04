# Release acceptance progress: September 21, 2026

## Decision

Full live-demo, pilot and production approval are NOT granted. This is an
intermediate evidence record, not a completed acceptance report. Criteria and
weights remain frozen in `criteria.json`; no untested workflow is marked PASS.

## Latest Checkpoint

[Price conflict review](steps/2026-10-04-price-conflict-review.md) adds a protected
read-only execution-time comparison for both retained sync queues, a price-only
filter and an admin review dialog. No automatic retry, price override or earning
mutation is available. Selected coverage: 27 backend and 75 frontend checks PASS;
production admin build PASS, local API ready and admin 4173 updated. Interrupted
broader regression is not PASS. Authorized resolution, activation, native-device
and full release acceptance remain open; backups remain local only.

[Mobile price cards](steps/2026-10-03-mobile-price-cards.md) adds read-only rates,
quantity estimates distinct from earnings, missing-price states, queue links and
saved execution evidence. Project/cache reads share an account guard. Mobile
tests: 767 PASS / 50 files; TypeScript, discovery and config checks PASS.
Isolated browser checks cover RU/EN/HE, 320/391/480 CSS-pixel widths, completed
work, missing prices and conflicts. A narrow addon-input overflow was corrected.
No real prices were approved/activated and no business data was changed. Native
phone acceptance, authorized conflict review, activation and full release gates
remain open. This is not production approval or a GitHub backup.

[Mobile price sync](steps/2026-10-03-mobile-price-sync.md) records the additive
installer price snapshot, account-owned cache and immutable offline price-version
references. Selected backend regression: 190 PASS; full mobile tests: 723 PASS
(49 files), TypeScript/config/discovery PASS. Cold reset/retries preserve
queued evidence; price conflicts do not create earnings. Mobile transport now
separates local undo metadata from commands, and batch replay cannot rewrite the
original work. Price-card UI, authorized resolution, reviewed activation and
physical-device/full-release acceptance remain open. See the checkpoint for
final verification: API ready/healthy, contract present, anonymous sync 401,
acceptance business checksums unchanged and no leftover test container. Local
implementation commits are `0e85956` (backend) and `ef4e839` (mobile). This does
not grant production approval; activation and remote publication remain blocked.

[Factory-confirmed earnings](steps/2026-10-03-factory-earnings.md) records the
server integration of execution-time prices, immutable earning evidence and
manual-override protection. Final selected backend regression: 516 unique PASS;
migration/rollback/history guards and runtime readiness PASS. Acceptance business
data is unchanged. Activation remains unavailable pending mobile cache/sync and
rollout checks. This is not full release approval; backups remain local only.

[Journal PDF languages and pagination](steps/2026-09-21-journal-pdf-locales.md)
records the RU/EN/HE document language, migration 0061, draft selector and mobile
preparation. Focused checks: backend 88, admin 27 and mobile 83 PASS; changed-file
ESLint and mobile TypeScript PASS. All 10 pages of the long PDF fixtures were
visually inspected. Empty/legacy/rollback migration checks and both isolated DB
upgrades passed. Production admin build passes and runs on 4173; API readiness
is verified after a slow startup. The login page renders, but the old session
expired: authenticated selector verification awaits sign-in. Temporary QA files,
containers, migration DB and new build cache were removed. Local commits only;
this is not native, external-delivery or full-release approval.

[Journal outbox IDs and transaction correlation](steps/2026-09-15-journal-outbox-ids.md)
records backend `ff723dd`: manual send responses and audits now carry actual
queue UUIDs. Final focused regression: 49 PASS, including each channel, resends,
three rollback points and real local Mailpit/MinIO delivery. The first pre-fix
probe timed out without a test report and is not counted. Owned test containers,
fixture data and messages were cleaned. After restart the API is healthy,
`/ready` confirms the database is ready, and the admin journal route returns 200.
No frontend/mobile changes, external messages, remote backup or release GO.

[Human journal invitation links](steps/2026-09-15-journal-links.md) records backend
`2ddb375`: manual email/WhatsApp, fallback email and template previews now point
to the human signing page, sharing ACTIVE/unsigned/unexpired eligibility with
admin/installer snapshots. PDF/media API URLs remain unchanged and signed PDFs
remain sendable without dead signing links. Final focused run: 49 PASS, exit 0,
including real MinIO/Mailpit invitation and signed attachment checks. The test
container/messages were cleaned. After a slow restart the acceptance API is
healthy, the database is ready and the reloaded admin journal retains its draft
and five rows. Acceptance business data and frontend/mobile source are unchanged.
No remote backup or release GO is claimed.

[Signed journal archive and isolated delivery](steps/2026-09-15-journal-integrity.md)
records central signed-PDF preservation, bounded canvas-signature validation,
visible PDF notes and Israel-local timestamps. The final combined journal run
has 60 PASS, exit 0, including real MinIO/SMTP Mailpit attachment verification.
Supplemental core E2E/Mailpit has 2 PASS; final geometry/freshness has 27 PASS.
Together these cover 62 unique cases without double-counting repeated tests.
Both short sample PDFs were rendered and visually inspected; temporary files and
test containers were removed. Backend commit `56ca995` is local only. After a slow
restart the API is healthy, `/ready` confirms database readiness, and the reloaded
admin journal retains its five rows and saved draft. No acceptance business data
or phone state changed; full PDF localization/native/external delivery and
production approval remain open. No GitHub backup is claimed.

[Acceptance gateway stability](steps/2026-09-14-gateway-stability.md) traces the
intermittent browser failures to observed gateway DNS/connect errors. Cached IPv4
service discovery, aligned idle connection lifetime and restricted-origin error
responses are deployed only to the acceptance proxy. Final isolated regression:
8 scenarios PASS (9 Node tests including the parent), 148.40 seconds, exit 0;
lost-response writes are not replayed. Ten live readiness checks return 200,
unauthenticated identity returns 401, and journal/calendar/projects load. Two
post-restart log inspections show zero gateway errors. Temporary fixtures are
removed. Host-load/DNS reliability and production infrastructure are not certified;
full release and PDF/signature/delivery acceptance remain open.

[Journal form and unsigned PDF freshness](steps/2026-09-14-journal-form.md)
records backend `9f5b488` and admin `4ab4dec`: a reachable simulated journal form
now reads saved work and uses real server actions; unsigned PDF downloads/shares
regenerate the file while existing signed PDFs are preserved. 48 focused tests,
changed-file lint and production build PASS. The new preview is running on 4173.
One clearly marked DRAFT in Acceptance A verifies five installed rows, saved-note
persistence, dirty-action guards and discard navigation. No live signing/delivery
or door/payroll changes occurred. Test API recovered to healthy after a slow
restart; transient browser read failures recovered but remain undiagnosed.
Full PDF/language, delivery, concurrent editing and native acceptance remain open.
Only local commits were made; no remote backup or production approval is claimed.

[Native lost-ACK preparation and backend follow-up](steps/2026-09-14-native-lost-ack.md)
records 14 passing fault-relay tests, the separately passing batch/no-accrual
case and five passing snapshot replay/reassignment cases (156.88 seconds, exit 0).
The earlier short replay attempt timed out; the complete later summary, not its
progress output, establishes PASS for these five cases. This is not a full gate.
Native injection remains unverified: the observation window received no work
event, and the authorized USB Profile tap still did not navigate. Normal phone
connectivity is restored and the relay is stopped. Current A-1 has one project,
five assigned doors (four installed), zero queued events and unchanged 1,000 ILS
net earnings. The old account's 13 tables and failed event are unchanged. All
temporary snapshots/relay logs and one-off test containers were removed.

[Server authority during offline conflicts](steps/2026-09-14-sync-server-authority.md)
records High mobile fix `2bd4b4f`: same-version server door state survives queue
rejection, discard and retry. SQLite schema 11 adds local metadata without changing
event identity or API payloads. Final mobile checks: 401 tests in 32 files,
TypeScript and discovery PASS. Native migration of both account databases and
structured before/after comparisons PASS; the old failed event remains intact,
A-1 queue is empty and domain data is unchanged. Metro was recovered in CI mode
after stale-bundle/resource issues; subsequent edits require a runtime restart.
Acceptance API is ready again, with unchanged 5/9 installations and 1,250 ILS
payroll. The limited backend rerun ended without a pytest summary and is NOT a
pass. Physical lost-ACK injection and offline reassignment remain unverified;
no full release or production approval is claimed.

[Native offline completion and payroll time](steps/2026-09-14-native-offline-completion.md)
records one real phone-created offline completion, persistence through restart,
automatic delivery, ACK cleanup and duplicate-safe 250 ILS accrual. Admin totals
are now 5/9 installed and 1,250 ILS payroll; A-1 month total is 1,000 ILS. The
check exposed a High work-date/rate defect in both sync paths, corrected in backend
commit `37059ea`. Final checks: 33 backend and 74 mobile sync tests PASS; the earlier
600-second backend timeout is not a pass. Post-restart acceptance `/ready` returned
HTTP 200/database ready after a slow startup; phone earnings show current data and
admin totals reconcile. Temporary artifacts removed: 22 files, 3,871,576 bytes.
No lost-response injection on the physical transport, full release-suite pass or
production approval is claimed.

[Admin/mobile data-source reconciliation](steps/2026-09-14-admin-mobile-parity.md)
records the port/company mismatch, corrected launch configuration and live API
parity for the selected Test Installer A-1. Four door IDs, statuses and versions
match the acceptance admin; admin access is denied, monthly earnings are 750 ILS.
Native account switching, API-offline cached cold launch, reconnection and final
SQLite-to-PostgreSQL parity PASS. All 13 old-account data tables and its one failed
event are unchanged. Final Metro has no test credentials or auto-login. These
checks do not establish new offline work replay/ACK, a production APK test or
release approval; no remote backup is claimed.
Mobile configuration/documentation is committed as `b3962c7`. Temporary device
inspection artifacts were removed: 16 files, 4,483,761 bytes.

[Mobile auth cleanup and storage failures](steps/2026-09-14-mobile-auth-lifecycle.md)
records mobile commit `acb2559`: stale cleanup callbacks cannot detach a newer
account, credential batches settle before releasing the auth storage queue, and
logout attempts local cleanup even after a session-read error. Persistent removal
failures now have an RU/EN/HE warning and guarded retry. Final source checks:
395 tests in 32 files, TypeScript, discovery, Expo config and the existing local
security/production-contract checks PASS. No phone actions or native deployment
occurred in this step; real logout/reentry, offline reconnection and full release
acceptance remain open. Local commits only, no remote backup claimed.

[Mobile profile/session isolation](steps/2026-09-14-mobile-profile-session.md)
records mobile commit `c47ddb9`: profile refresh writes now share the existing
auth mutation queue, late storage completion cannot report a successful old
login, and offline startup rejects another installer's cached profile within the
same company. Final checks: 376 tests in 31 files, TypeScript and discovery PASS.
The USB Metro tunnel was restored; the existing phone profile still showed one
queued action. Touch/scroll, sign-out cancellation and account switching remain
unverified. The source change was not deployed to the phone in this checkpoint.
No queued work was sent or deleted. Local commits only, no production approval.

[Mobile profile queue state](steps/2026-09-14-mobile-profile-queue.md) records
mobile commit `1e20ebb`: an unread or failed queue no longer appears successfully
synchronized, and sign-out confirmation rechecks local work without sending it.
Final checks: 354 tests in 29 files, TypeScript and discovery PASS. The updated
Android bundle and cold-started profile displayed one queued action. ADB touch/
scroll effects remain unconfirmed; actual sign-out/cancellation and account-switch
acceptance are still open. Temporary phone inspection/screenshot files were
removed. No working queue delivery, credential clearing or remote backup claimed.

[Mobile authenticated cache isolation](steps/2026-09-14-mobile-cache-isolation.md)
records P1 protection for calendar, earnings, journals and project details across
account changes, mobile commit `0a38b0c`. Final checks: 324 tests in 28 files,
TypeScript and discovery PASS. The Android bundle includes the fix; a cold phone
launch and bundle delivery were observed with API access deliberately isolated.
The post-restart UI check was not completed because another app was foreground;
native account-switch/queue persistence and online acceptance remain open. No
existing queued work was sent or cleared. No remote backup or full release approval.

[Deleted-project installer access](steps/2026-09-12-deleted-project-access.md)
records reproduced unauthorized mutations after project deletion and backend fix
`53189d0`. Verification passed: 24 targeted and 76 related backend checks (96
unique), 249 mobile tests, TypeScript and test discovery. Historical payroll
corrections remain available. The earlier interrupted/OOM runs are not passes.
Both APIs were restored and returned database-ready responses after resource
recovery. Phone connection is confirmed; native follow-up is recorded separately
in that checkpoint. No full offline/production approval or GitHub backup claimed.

[Native queue recovery](steps/2026-09-11-mobile-session-isolation.md#native-queue-recovery)
records mobile fix `dcb2165`: truthful queue loading/error states, exhausted-retry
presentation and a phone-reproduced failure of deferred error handling. Final
mobile checks: 249 PASS in 27 files, TypeScript and discovery PASS. A real API-offline
retry retained the work and scheduled another attempt; native SQLite comparison
passed with only expected retry metadata and one local door timestamp changed.
All eight temporary DB/screenshot files were removed (5,139,764 bytes). The old
event belongs to a deleted smoke fixture; no server event or accrual was created.
Native online delivery and full release approval remain open. Local commits only.

[Sync replay follow-up](steps/2026-09-11-mobile-session-isolation.md#replay-follow-up)
records a reproduced false-acknowledgement defect when an event ID is reused
with different work, backend fix `2e98c2f` and mobile test commit `dde7847`.
Backend: 64 PASS; mobile: 227 PASS, TypeScript and discovery passed. The phone's
account matches port 8000, not the isolated acceptance database on port 8001.
No native queued work was sent. Temporary test containers and synthetic replay
records were cleaned up; live reconnect/ACK and full release acceptance remain open.

[Connected phone follow-up](steps/2026-09-11-mobile-session-isolation.md#connected-phone-follow-up)
records successful Android activity startup with the current Metro bundle and
the API deliberately isolated. Read-only SQLite comparison confirmed unchanged
domain/cache rows, ownership/cursor and the existing queued event payload after
startup; all temporary DB copies were then removed outside the project. DIMAX
was reopened. Visual acceptance, online queue delivery and fully disconnected
cold startup remain open; this is not full native/offline or release approval.

[Mobile sync session isolation](steps/2026-09-11-mobile-session-isolation.md)
records the reproduced account-boundary defect and scoped DB/API/sync guards in
mobile fix `7d9a3fd`. All 223 tests in 27 files, TypeScript and discovery pass.
The updated Android bundle probe passed: HTTP 200, 8,650,804 bytes, exit 0.
Native persistence and the remaining account-switch paths are not approved;
this is local evidence, not a remote backup.

[Mobile cold resync](steps/2026-09-11-mobile-cold-resync.md) records reproduced
P1 defects in full-snapshot optimistic replay, revoked-assignment handling and
stale door rollback. Mobile fix `040c02b` passes 204 tests in 26 files, TypeScript
and test discovery. The updated Android bundle probe passed (HTTP 200, 8,648,489
bytes, exit 0); actual device startup, SQLite/offline persistence and full sync
acceptance remain open.
No backend, admin, money or live project data changed; no remote backup is claimed.

[Current mobile native build](steps/2026-09-11-mobile-native-build.md) records a
successful debug APK build at clean mobile source `515cb12`, with verified
package/SDK/signature and all four native architectures. The debug APK contains
no embedded JavaScript. A separate current Android Metro bundle probe passed:
HTTP 200, 8,646,782 bytes, exit 0; its temporary server and files were cleaned up.
No phone is detected, so installation, native startup and offline operation
remain unverified. This checkpoint is local only, not a GitHub backup.

[Mobile preflight and safe launch](steps/2026-09-11-mobile-preflight.md) records
the first mobile acceptance item: no connected ADB device, an unbooted configured
emulator, available build tools and a saved APK from an older source revision.
Mobile fix `515cb12` removes implicit seeded automatic login and requires an
explicit test API/account for the device launcher. All 189 mobile tests, 14
launcher checks, typecheck and Expo configuration validation pass locally.
At that checkpoint, native launch, a fresh APK, offline workflows and remote CI
were unverified. The build and bundle evidence above supersedes only its build
limitation; the frozen readiness criteria are not advanced.

[Payroll lifecycle verification](steps/2026-09-11-payroll-verification.md) records
the completed live correction/cancellation/reinstallation chain, independently
reconciled ledger totals, 69 completed backend checks and 62 admin tests.
It also records the project page's Decimal-string/USD display defect and its
scoped frontend correction, successful production build and standalone startup fix.
Final build/runtime checks are recorded in that file;
this is not full release or native/offline approval.

[Assignment/completion acceptance](steps/2026-09-11-assignment.md) records a
reproduced ownership/concurrent-completion defect, backend correction `db007e8`,
109 expanded integration checks, 39 architecture/security/OpenAPI checks and 77
mobile source compatibility checks. Actual UI assignment, separate installer
visibility and three completions reconciled with payroll 750 and revenue 3400.
This is web-client evidence, not native/offline acceptance.

[Dashboard window correction](steps/2026-09-11-dashboard-window.md) records the
separate defect discovered during reconciliation: a module-level timestamp kept
new work outside the dashboard's period. Correction `0ffb4f2` passes 32 focused
and related UI regressions plus the TypeScript/24-page production build. A fresh
live route-return check shows the fourth installation and payroll 1000 without
a full reload. Final synthetic state is 4/9 installed, revenue 4400, payroll 1000;
the earlier three-work reconciliation remains recorded as an intermediate state.

[Live Excel and session acceptance](steps/2026-09-11-import-session.md) remains
the evidence for JWT recovery, nine imported synthetic doors, duplicate prevention
and strict invalid-workbook behavior. Earlier workspace/frontend checkpoints were
published through `afbe415`/`52b59fe`. Latest backend/frontend publication was
separately rejected pending explicit permission for the public destinations;
local commits are retained. No full new-revision release or production approval.

## Environment and Resources

- Windows host: 3,978,360 KiB usable physical memory (nominal 4 GB).
- Initial free RAM: 236,040 KiB; available commit headroom: 1,700,192 KiB.
- Initial free C space: 8.48 GiB after the separately approved cache cleanup.
- During checks: 214 MiB free RAM, 1,029 MiB commit headroom, 3.90 GiB free C.
- After stopping the test DB: 3.88 GiB free C. Full concurrent local release
  builds are blocked by resource headroom. No further files were deleted.
- Docker reported about 974 MiB available before the narrow test. Observed
  check-container memory was 148.5 MiB under its 384 MiB hard limit; test DB
  used 32.43 MiB under 256 MiB. No second frontend or emulator was started.
- Isolated database: `dimax_acceptance_tests`, Alembic
  `0060_installer_journal_handoff`. UI-demo DB and working company are separate.
- Normal API/admin were left running. Acceptance DB was stopped after tests;
  its volume was retained. Normal delivery/maintenance/sync workers were already
  stopped before this step and were not exercised or declared operational.

## Defect Register

### P1: Installer earnings use a different day from the workspace

Status: FIXED AND VERIFIED locally and by the full backend CI gate.

Reproduction: create a synthetic completed installation for 250 ILS at
2026-09-06 21:30 UTC (September 7, 00:30 in Jerusalem). Request installer earnings
for September 7. Before the fix, day/week total and month `today_total` omitted
the work. Day grouping also used the stored UTC date.

Cause: `earnings/application/installer_api_service.py` used UTC calendar ranges
and `.date()` directly, while the installer workspace already used Jerusalem.

Fix: local calendar boundaries, local day/week grouping and a single default
anchor date per summary. UTC storage, decimal amounts, rate snapshots,
accrual timing, correction/reversal rules, API fields and permissions unchanged.
No migration required: the stored timestamp already has timezone support.
Cached offline responses refresh on the next successful online earnings fetch.

Files in backend commit `e5b95b4`:
- `app/modules/earnings/application/installer_api_service.py`
- `tests/integration/test_installer_phase2_api.py`
- `TESTING.md`

Evidence:
- Before patch: 9 failures, 23 deselected, 64.23 seconds; exit 1.
- After patch: 76 PASS, 242.50 seconds; exit 0.
- 27 added timezone cases cover day/week/month, midnight, month/year boundaries,
  implicit current date, workspace totals, DST range ends, unchanged stored data.
- Existing correction, financial constraint and calendar tests passed alongside.
- Local ignored logs: `artifacts/acceptance-20260909/timezone-before.log` and
  `timezone-after.log`. These are API tests, not UI or device evidence.

## Timezone Checkpoint Checks

| Gate | Exact revision | Result | Evidence |
| --- | --- | --- | --- |
| Backend full gate | e5b95b4c8af2a7c4a792fdc247cd3ad7242b33b2 | PASS | https://github.com/maxsav2704-design/dimax-ops-backend/actions/runs/34487005870 |
| Admin source gate | 51fa91d21de2f66a85fba563af1747ee5180945e | PASS | https://github.com/maxsav2704-design/dimax-ops-frontend/actions/runs/34486306168 |
| Mobile source gate | c17810e2a13d5bcfb53dd7ee79d8c42bba71df57 | PASS | https://github.com/maxsav2704-design/dimax-ops-mobile/actions/runs/34486343747 |

Backend passed 365 integration tests and 38 architecture/security tests. OpenAPI
and error-contract jobs passed (1 and 30 tests, overlapping integration coverage,
not added again). Clean/legacy migration and separate backup/restore jobs passed.
GitHub's checkout-action Node runtime warning remains a tooling maintenance item;
it did not fail these jobs. No warning was suppressed.

Admin passed its lint/test/TypeScript/production-build workflow (24 generated
pages). The local `next-env.d.ts` and `tsconfig.json` retain generated acceptance
output paths from the interrupted dev run; the remote result covers the commit,
not these uncommitted generated differences. No frontend feature changed here.
Mobile passed 176 Vitest tests, security/config/type checks and 17/17 Expo Doctor
checks. No native build, physical device or signed release was tested this step.

The backend fix was pushed to the existing release branch. The local workspace
API was restarted after CI passed to load it, without rebuilding images or
removing data. The normal workspace command checks Alembic head on startup;
this change adds no migration.

The removed cache directories were not recreated. Read-only follow-up checks
did not identify the entire additional disk-space consumption: the Windows
pagefile remains 11.5 GiB, the logical Docker data VHD size remains 37.896 GiB,
and several protected/reparse directories were excluded or inaccessible. Do not
attribute the decrease to a particular component without allocation evidence.

## Import Checkpoint

The next step is recorded in [the import checkpoint](steps/2026-09-10-import.md).
It supersedes the earlier bootstrap-repeat pending status, records the numeric
import fix and full backend gate, and distinguishes the blocked local UI run
from automated verification. No production approval is implied.

Runtime recovery and subsequent fixture/readiness corrections are recorded in
[the runtime checkpoint](steps/2026-09-10-runtime.md). It supersedes the pending
Docker restart and bootstrap-normalization status above; UI acceptance is separate.

## Remaining Acceptance

The financial lifecycle follow-up is recorded in
[the payroll checkpoint](steps/2026-09-11-payroll.md), including confirmed defects,
local fixes and explicitly pending verification. It does not close A15 by inference.

- Continue the isolated UI demo from the 9 imported doors with calendar actions.
  Assignment, separate visibility, base completions and the corrected dashboard
  route-return were observed; preview counting/locale issues remain open.
- Reconcile the independently calculated base/addon/correction/reversal example
  across admin, mobile and reports; the narrow timezone fix does not prove A15.
- Offline restart/reconnect, retries, reassignment, cold resync and account switch
  require fresh workflow evidence; do not use source tests as a substitute.
- Project journal, every RU/EN/HE PDF page, test signing and Mailpit attachment
  receipt remain unverified in this run. Never sign real customer documents or
  send messages to actual recipients during acceptance.
- Production configuration, external test inbox, HTTPS, owner signing and fresh
  physical-device acceptance remain separate prerequisites.
- Fixture normalization/bootstrap completed after Docker recovery. Complete demo
  reproducibility by another person still requires acceptance evidence.

No readiness percentage is advanced by this intermediate step. Full criteria
results and the investor demo script must be completed from observed workflows,
not inferred from these successful source checks.

## Native Add-on Checkpoint, October 1

The current physical-phone add-on, lost-ACK replay and earnings checks are recorded
in [the native add-on checkpoint](steps/2026-10-01-native-addon-payroll.md), which
also links the preceding issue lifecycle check. Use its explicit verification
status for this block; historical CI results above do not certify newer commits.
The full production and cross-client reconciliation criteria remain separate.

## Price Authority Requirement, October 2

The owner requires one price list for all projects, including requested/agreed
edits, with explicit confirmation of each version by the factory representative
through a personal link. [The price-authority checkpoint](steps/2026-10-02-price-authority.md)
separates current installer-input protection from this still-pending workflow.
Earlier payroll PASS results do not establish factory price approval. This new
business requirement blocks production approval until implemented and verified.

The [factory price-list draft checkpoint](steps/2026-10-02-factory-price-list-drafts.md)
adds backend commit `709ba08`: tenant-scoped immutable draft versions, reasons and
agreement references, idempotent creation, concurrency protection and atomic audit.
Final price-list tests: 49 PASS; the expanded run's 170 other cases PASS, with the
test-helper correction and separate rerun recorded explicitly. Guarded fresh/
rollback migration smoke PASS; both isolated databases are at 0063 and five
acceptance business-table checksums are unchanged. This is draft infrastructure,
not factory confirmation, price activation, UI/mobile rollout or release approval.
Only local Git commits are made; no remote backup is claimed.

## Factory Confirmation Checkpoint, October 2

The [factory confirmation checkpoint](steps/2026-10-02-factory-price-approval.md)
records backend `e7851c7` and admin `588d4c5`: hashed, expiring/revocable personal
links, explicit version-bound factory decisions, confirmation/revocation race
protection and the RU/EN/HE public page. Final selected backend regression:
225 PASS. Frontend component tests: 8 PASS; browser checks with mocked responses:
3 PASS, including inspected desktop/mobile-width screenshots. Changed-file lint,
Next production build/TypeScript and guarded clean/roundtrip migration smoke PASS.

Both isolated databases are now at 0064. Five acceptance business-table checksums
are unchanged, and no factory prices/invitations were seeded there. Live API
readiness and routes were checked after restarting only the acceptance API.
The page records approval but does not activate prices or reprice prior earnings.
Admin invitation management, controlled external delivery, confirmed-rate payroll
activation and mobile sync remain open. A link is a bearer capability, not verified
factory identity. No real message, signature, native test, remote backup or full
release PASS is claimed. Temporary migration/browser-test artifacts were removed.

## Factory Price Admin Checkpoint, October 2

The [admin management checkpoint](steps/2026-10-02-factory-price-management.md)
adds `/price-lists`: versioned drafts, catalog-based decimal entry, cancellation,
named representative invitations, one-time manual link sharing, revocation and
decision history in RU/EN/HE. OWNER/OPERATIONS can manage prices with rate access;
FINANCE can read them; VIEWER/installers are denied. No confirm-as-factory action,
automatic external delivery, activation or historical repricing was introduced.

Final selected frontend regression: 71 PASS in 6 files. Changed-file ESLint,
production build/TypeScript (26 pages) and 6 mocked Playwright cases PASS.
Desktop/mobile-width screenshots were inspected, and owned browser outputs
removed. Existing local configuration edits remain outside the feature commit.
The local preview is available on 4173 against acceptance API 8001. The acceptance
database still contains no factory price lists/invitations and its completed-work
checksum is unchanged. Backend/mobile suites were not rerun this UI-only step.

This supersedes the absent admin-management status above, not the remaining
controlled delivery, legacy-rate reconciliation, confirmed-rate activation,
mobile sync and release gates. Auth-event resets can discard unsaved forms;
side-by-side comparison is still pending. No native test, real factory approval,
GitHub backup or full production PASS is claimed.
Local admin commit: `41ac9ee`; backend checklist-only commit: `19156d5`.

## Legacy Price Reconciliation, October 3

The [reconciliation checkpoint](steps/2026-10-03-price-reconciliation.md) adds
readonly company inventory before a draft and comparison against one version.
It distinguishes operative rates from defaults/future prices, identifies
different prices for one work type, snapshots/surcharges, missing prices/parents,
changed catalog units and saved add-on work without accrual. RU/EN/HE admin
filters, pagination, retry and account-change isolation are available.

Final selected regression: 199 backend and 57 frontend tests PASS. Changed-file
lint, final production build/TypeScript and 7 mocked browser cases PASS; screenshots
were inspected and owned outputs removed. Live API readiness, route presence and
unauthenticated 401 were checked. READ ONLY inspection of Acceptance A returned
9 legacy sources; the factory-price tables remain empty. All five historical
business-table checksums match the starting checkpoint at migration 0064.

This completes the inspection tool, not the commercial settlement or activation
of a confirmed price list. Historical earnings were not changed. Confirmed-rate
activation, mobile/offline rollout, controlled factory delivery and full release
gates remain open. Mobile was unchanged; no native test or external message was
performed. Local preview: 4173 against isolated API 8001. No GitHub backup or
100-percent production readiness is claimed.
Local backend commit: `d3fdad7`; local admin commit: `e4a0119`.

## Factory Price Application Check, October 3

The [pre-application checkpoint](steps/2026-10-03-price-application-check.md)
adds a readonly selected-version check of the exact factory receipt/snapshot,
company work-price coverage, catalog availability/units and legacy transition
issues. A CONFIRMED label alone cannot pass. RU/EN/HE distinguish BLOCKED,
REVIEW_REQUIRED and VERIFIED; VERIFIED does not mean ACTIVE, and the report
always returns `affects_earnings=false`. There is no activation or payroll write.

Final selected regression: 218 backend and 51 frontend tests PASS. Changed-file
lint, production build/TypeScript (26 pages) and 7 mocked browser cases PASS.
Summary and scrolled-table screenshots were inspected; footer visibility and
modal interaction restoration are tested. Live API readiness, the additive
contract and unauthenticated 401 were verified. All five acceptance business
checksums still match; price tables remain empty and both schemas remain at 0064.
Owned browser outputs were removed after inspection. Initial fixture/JSX errors
and the first OpenAPI timeout are recorded, not counted as successful gates.

Offline policy is explicitly agreed: confirmed execution-time prices for new
work; the first confirmed company list for old queued work without a version.
Recorded earnings are not repriced. These are business rules for the next rollout,
not functionality implemented by this advisory check. Active-version history,
immutable ledger provenance, mobile rate cache/sync, controlled delivery and full
release gates remain open. Activation must recheck inside its locked transaction.
No migration, native test, real factory decision or external message is claimed.
Preview: 4173 against acceptance API 8001. No GitHub backup or 100-percent
production readiness is claimed; the public-remote restriction remains unresolved.
Local backend commit: `e4dac1a`; local admin commit: `f38d109`.

## Factory Price Timeline Engine, October 3

The [timeline checkpoint](steps/2026-10-03-price-timeline.md) adds migration
0065 and an internal company-scoped transition/execution-time quote engine.
Activation rechecks factory evidence and prerequisites under the company lock,
requires authorized OWNER/OPERATIONS rate access, explicit review/reason and
expected-version/retry checks, and atomically records history/audit. Effective
times cannot be supplied by the client; downgrade cannot discard that history.

Quotes select the version effective at execution, not upload. Only an explicitly
classified pre-transition versionless queue uses the first confirmed list;
missing/damaged first evidence or a missing price cannot fall forward to a later
amendment. Cached-version conflicts, decimal quantity/amount bounds and frozen
unit/rate evidence are enforced. No activation route or UI action is exposed.
Quote provenance is not yet stored in the earning ledger and existing payroll
writers/manual corrections are not switched; mobile cache/sync remains next.

Final selected regression: 316 backend tests PASS in 494.54 seconds, including
54 timeline cases plus existing factory APIs, addons, earning corrections and
architecture checks. Fresh/rollback/metadata/history-protection smoke PASS in
the guarded temporary DB, which was removed. Both isolated schemas are at 0065,
with zero current acceptance prices/decisions/activations and no test activations
left. All five current business checksums match the preceding checkpoint.

Acceptance API 8001 is healthy; final strict readiness and unauthenticated 401
checks PASS. Live OpenAPI retains the readonly false earnings flag and exposes
no activation route. Existing admin preview 4173 returns HTML/200. Normal
API 8000 was not restarted/migrated; admin/mobile builds and native tests were
not rerun. Initial clock-sensitive test/probe errors are recorded in the
checkpoint and excluded from PASS. The existing admin config edits are preserved.
No external message, real factory decision or complete release GO is claimed.
Local commits only; no GitHub backup while the public-remote restriction remains.
Local backend commit: `52f31e0`. Admin remains at `f38d109` with its existing
config edits; mobile remains at `f5eaeae`.

## Factory Earnings Integration, October 3

The [earning checkpoint](steps/2026-10-03-factory-earnings.md) connects all door
and additional-work completion paths to the internal effective-price timeline.
Migration 0066 preserves original price/item/receipt/time evidence separately
from existing financial rows. Replays never reprice, reversals offset the exact
original, and arbitrary manual rates/installer surcharges cannot override a
factory price after activation. Project-plan edits cannot backfill old uploaded
unpaid work. Only explicitly classified old offline commands use the first
confirmed list; missing prices/times retain unresolved commands, not false earnings.

Final selected PostgreSQL regression: 444 main + 72 supplemental = 516 unique
PASS, including 35 new earning cases. Fresh/rollback/metadata/legacy-data and
both evidence/time-loss downgrade guards PASS in the subsequently removed QA DB.
Both isolated schemas are at 0066; all five business checksums remain unchanged,
and the current acceptance company has zero factory prices/approvals/activations.
API 8001 is healthy/ready, financial APIs return unauthenticated 401, and live
OpenAPI contains evidence but no activation route. Preview 4173 returns 200.

Mobile price cache/outbox/version evidence, explicit conflict handling, reviewed
admin activation and full native/release/deployment checks remain open. Normal
API 8000, admin/mobile source, existing config edits and current financial data
were not changed. No external message, native build or production approval is
claimed. Only local Git checkpoints are allowed while the public-remote
publication restriction remains unresolved.
Local backend commit for this step: `cd9d611`.
