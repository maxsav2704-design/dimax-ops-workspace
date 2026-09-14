# Admin/mobile data-source reconciliation

## Scope and findings

The user requested one consistent source of projects and doors, with no unrelated
data on the phone. Installer access remains assignment-based, not administrator
access. The user selected Test Installer A-1 and separately approved resetting
only that synthetic account's password in DIMAX Acceptance A.

- The open admin at `http://127.0.0.1:4173/projects` uses acceptance API port 8001.
  The current project is `QA-IMPORT-20260910`, 9 doors, 4 installed.
- The phone was still signed into Installer One in the normal API 8000 company.
  Its cached data contained 33 projects and 67 doors, last sync September 4.
  API access was deliberately isolated on port 18082 for earlier queue checks.
- The shared `Start-MobileMetro` command also explicitly forced port 8000, and
  the Metro launcher overwrote caller configuration with its port-8000 default.
  Thus a normal restart could undo the selected environment.
- The admin's ignored E2E configuration had an unrelated company/installer even
  though its API pointed at 8001. It now targets the selected acceptance account.
- An admin refresh initially failed partially and displayed zero doors alongside
  retained financial data. A full reload recovered the actual 9 doors. The
  transient request failure is not claimed fixed by the launcher correction.

## Changes

- `scripts/workspace.ps1`: stop forcing the normal API in the device launch.
- `scripts/mobile-metro.ps1`: explicit API overrides still win; otherwise keep
  the shell environment and let Expo resolve its existing dotenv configuration.
  The standalone smoke check retains its previous local default. Three added
  self-tests verify preservation, explicit override and an unset environment.
- `mobile/.gitignore`: exclude local environment files, retaining example files.
- `mobile/README.md`: document API/company alignment, assignment scope, safe
  account switching, queue preservation and temporary test-login cleanup.
- Ignored local configuration pins mobile to API 8001 with auto-login disabled.
  Test credentials remain in the existing ignored admin E2E configuration only.

No API schema, database schema, rates, work completion, earnings or project
assignment was changed. No application reinstall, data reset or new APK.

## Live API Reconciliation

Actual authentication and HTTP requests against `dimax_acceptance`, not API
mocks. An empty event list was sent to `/installer/sync`; no installation was
submitted. Its snapshot was compared by ID, project, label, status and version
against a read-only query of the admin database's current assignments.

| Check | Result |
| --- | --- |
| Test Installer A-1 authentication | PASS |
| One project, `6423143b-4122-4685-8f8f-20fe848bc8b7` | PASS |
| Exactly 4 assigned doors, 3 installed, 1 not installed | PASS |
| Every door ID/status/version matches the admin database | PASS |
| Cold snapshot, `reset_required=true`, cursor 22 | PASS |
| Installer access to admin project API | 403, correctly denied |
| Earnings summary | HTTP 200, month 750 ILS, today 0 ILS |
| Journal list / current-week calendar | HTTP 200, empty |

The admin's total 1,000 ILS includes the other installer's 250 ILS; the phone
must not show another installer's earnings. An initial comparison command failed
to parse multiline psql JSON, then passed with correct whole-document parsing.
Its temporary refresh sessions were revoked. A normal-API identity probe verified
the old account is recoverable; its diagnostic refresh session was also revoked,
without revoking the phone's session or changing old work.

## Source Checks

- Mobile Vitest: 395 PASS, 32 files, 56.82 seconds.
- Mobile TypeScript: PASS, exit 0.
- E2E launcher contract: 14 PASS, 24.65 seconds.
- Metro self-test: 15 PASS, including 3 new environment cases.
- Workspace PowerShell syntax and Git whitespace checks: PASS.
- Git ignores local/production environment files but not the production example.

These do not replace native-device or full backend/admin release verification.
Existing generated admin `next-env.d.ts` and `tsconfig.json` changes were retained.

## Native Verification

The user confirmed finger navigation works; ADB-injected taps did not navigate.
No device security setting was changed. Current source was served successfully
with API isolation before switching accounts (HTTP 200, 8,676,359-byte bundle).
The phone's legacy SQLite/WAL/SHM was temporarily copied with the app stopped;
integrity was `ok`, schema/data ownership and the one pending event were retained.
SecureStore was not exported.

The user then signed out manually, confirmed the login screen, and that screen
was verified in the native hierarchy. Metro was restarted for the selected test
login and USB API port 8001 was added. The real phone signed in as Test Installer
A-1, showing one project instead of the previous account's 33 projects.

The final Metro process runs without test credentials or auto-login. Its Android
bundle returned HTTP 200, 8,676,233 bytes; checks confirmed API 8001, the current
auth cleanup code, auto-login disabled, and no test email or password. An ad-hoc
readiness probe initially failed to decode PowerShell's byte-array response and
was stopped; the corrected probe passed. This was a verification-command error,
not a Metro or app failure. The repository launcher already handles that format.

| Native check | Result |
| --- | --- |
| Cold launch with API USB tunnel removed, Metro still connected | PASS |
| Cached identity remains Test Installer A-1 | PASS |
| Project detail shows the expected project, 3/4 installed, 1 remaining | PASS |
| Restore API tunnel and cold-start without auto-login | PASS |
| Sync timestamp advances after reconnection | PASS, final `2026-09-14T12:48:10.930238Z` |
| Final SQLite door ID/project/label/status/version vs live PostgreSQL | PASS, exact match for all 4 doors |
| Active database owner and cursor | PASS, A-1/company A, cursor 22 |
| Active queue | 0 events |
| Old account before/after comparison | PASS, all 13 data tables unchanged |
| Old failed event | 1 event preserved, not replayed or deleted |
| SQLite integrity | `ok` for all inspected databases |

These checks establish API-offline cached startup in a development client, not
a fully disconnected production APK test. The phone's earnings screen was not
visually accepted: WhatsApp became foreground, so no other app content was read
or controlled. The earnings API comparison above remains valid. DIMAX alone was
stopped for the final consistent SQLite snapshot; Metro and both USB tunnels
remain available for the next ordinary launch. The admin's installer filter was
restored to all installers. No security setting, installation or app data reset
was used, and no work, rate, assignment or accrual was changed.

Temporary SQLite snapshots and the inspection screenshot were removed after
their final comparison: 16 files, 4,483,761 bytes. Both exact temporary targets
were verified absent. Native databases, old queued work, dependencies and
reused Metro logs were retained; no APK or bundle artifact was saved.

Mobile configuration/documentation commit: `b3962c7`. Local commits only.
The public GitHub publication restriction remains; no remote
backup is claimed. Full offline replay/ACK, reassignment, journal delivery and
production acceptance are separate gates, not inferred from a read-only snapshot.
