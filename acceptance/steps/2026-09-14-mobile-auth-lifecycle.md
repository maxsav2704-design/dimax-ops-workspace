# Mobile auth cleanup and storage failures: September 14, 2026

## Scope and decision

Mobile commit: `acb2559`, following `c47ddb9`. This step reviews and hardens the
remaining provider cleanup paths, not the application's full authentication
surface or native release. Criteria/weights are unchanged. No full release
approval or updated readiness percentage is inferred from source tests.

The existing separation of account-owned SQLite databases, generation-guarded
HTTP operations and serialized auth storage is retained. No migrations, external
API changes, dependencies, work states, payroll changes or new business modules.

## Confirmed problems

1. P1: `logout` read SecureStore before entering its `try/finally`. A failed read
   skipped local credential cleanup; the provider suppressed the error and left
   the installer UI. The new regression observed zero cleanup calls instead of one.
2. P1: `persistSession` and `clearSession` used fail-fast `Promise.all` for several
   native mutations. One rejected operation could release the auth queue while
   others were still writing/deleting, exposing newer credentials to late changes.
   Both new delayed-mutation tests failed before correction.
3. P1: provider bootstrap, invalid-account and failed-login cleanup paths directly
   cleared storage or changed UI after asynchronous work without consistent epoch
   checks. A stale failure could detach a newer workspace or reset its UI/loading
   state. Existing epoch guards and storage serialization were not applied to all
   paths. The new shared cleanup helper is tested at each asynchronous boundary.
4. P2: a persistent credential-deletion failure was indistinguishable to the UI
   from an ordinary offline server-revocation failure. A local exit could appear
   complete even though saved credentials might remain on the device.

Initial reproduction command: targeted API/session tests, 3 FAIL / 30 skipped,
exit 1, 4.20 seconds. These are controlled storage-adapter failures, not failures
injected into the user's physical phone.

## Implementation

- `src/lib/api.ts`: move the logout storage read into the existing `try/finally`.
  Add generation-bound local invalidation using the existing auth mutation queue.
  Differentiate credential-deletion failures with `SessionStorageError`; retain
  best-effort remote logout and protection against older session generations.
- `src/modules/auth/session.ts`: wait for all credential mutations to settle,
  then propagate the first failure. This is serialization protection, not an
  atomic SecureStore transaction or rollback mechanism.
- `src/modules/auth/workspace.ts`: one small cleanup function shared by the
  provider's error/exit paths. Check whether the action is still current before
  cleanup and after awaits. Stale failures do not affect a newer UI/database.
  Current cleanup still detaches access after a storage/close failure and reports
  the failure. It closes a SQLite handle; it never deletes account databases.
- `src/providers/AppProviders.tsx`: replace direct cleanup with that helper;
  invalidate callbacks on unmount; guard background sync against changed epochs
  and pause its scheduling while authentication is loading. Handle missing-session
  reconciliation after explicit refresh failure without treating an uncertain
  SecureStore read as proof that the offline identity must be discarded.
  Recheck epoch before ending logout loading. Already-dispatched HTTP requests
  are not claimed to be canceled by these scheduling guards.
- `src/lib/errors.ts`, `src/lib/i18n.ts`: typed local-removal failure plus translated
  warning/dismiss/retry text for EN/RU/HE. The native alert tells the user to retry
  before handing the phone to another person. Retry checks the original epoch so
  an older alert cannot sign out a newer account. Native storage details are not
  exposed in this message.
- Tests: API logout failure classification and missing/read-failed sessions;
  local invalidation versus newer login/profile writes; delayed multi-key storage
  failures; stale cleanup callbacks, failed close/deletion, and cleared-state
  ordering. Existing translation-completeness tests include the new messages.

## Verification

Existing Node 20.19.5 and installed dependencies were used. No package install.

| Check | Result |
| --- | --- |
| Targeted API/profile/session/workspace tests, before final warning additions | 58 PASS, 4 files, exit 0, 7.42 seconds |
| Final `vitest run --maxWorkers=1` | 395 PASS, 32 files, exit 0, 55.24 seconds |
| `tsc --noEmit` | PASS, exit 0 |
| `node scripts/validate-test-discovery.mjs` | PASS, 32 files |
| `node scripts/patch-image-size.mjs --self-test` | PASS, existing ICNS/JXL/HEIF/PNG checks |
| `node --test scripts/fast-uri-security.test.mjs` | 2 PASS |
| `node scripts/validate-production-config.mjs --self-test` | PASS, 7 API cases and Android network/manifest policy |
| Local Expo CLI `config --json` | PASS; DIMAX Installer 0.1.0, `com.dimax.operations.installer` |
| `git diff --check` | PASS |

Nineteen tests were added relative to 376. These are mocked native storage/API/
database adapters and pure checks. The React provider and native alert were
reviewed and typechecked, not rendered or exercised on Android in this step.
Production-config self-tests validate the contract, not a deployed production
environment. Dependency checks above are local regression checks, not a fresh
online vulnerability audit. Backend/admin gates were not rerun.

## Data, artifacts and remaining acceptance

No phone command, work event, retry, sign-out, account switch, API reconnect,
server mutation or native data reset was performed. The pending smoke-fixture
event on the phone was not touched. The current source was not deployed to it.
No APK, screenshot, copied database, exported bundle or build directory was
created for this step. Only source/tests and this checkpoint were added.

Persistent SecureStore failures still require a successful retry before secure
device handoff can be confirmed. The warning is not proof of credential removal.
Native startup, real exit/reentry, alert/retry interaction, queue retention across
account changes and reconnect/ACK remain open. Use a recoverable test account and
preserve the old event for a deleted fixture; do not send it to manufacture a PASS.

Changes are local commits only. The existing public-destination publication
restriction remains; no GitHub backup is claimed. Next: verify a current native
bundle with recoverable test credentials and complete the phone's input,
logout/reentry and offline lifecycle acceptance before advancing release criteria.
