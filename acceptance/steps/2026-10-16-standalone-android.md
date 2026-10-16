# Standalone Android acceptance

## Scope

Follow-up to `2026-10-16-device-addon-price-chain.md`: prepare a bundled APK
that can cold-start without the Metro development server. This is an isolated
USB acceptance variant, not production release certification. Public HTTPS,
external SMTP and owner-controlled production signing are still separate gates.

## Implementation

- `mobile/android/app/build.gradle` defines `acceptance` from `release`, with
  package `com.dimax.operations.installer.acceptance`, version suffix
  `-acceptance`, local debug signing and `debuggable false`. Only `debug` skips
  bundling; acceptance embeds production JavaScript and Hermes. ARM64 is used
  for the attached acceptance device. The normal release still requires a real
  HTTPS API and all four production signing variables.
- The acceptance app label is `DIMAX Test`; its native and Expo link scheme is
  `dimax-installer-acceptance`. The original application ID and scheme remain
  unchanged. Android keeps the two packages' tokens, databases and queues apart.
- Acceptance build inputs and runtime URL must both select exactly
  `http://127.0.0.1:8001`. Only its network policy permits loopback HTTP. Normal
  release still denies cleartext traffic. No ordinary API/database fallback is
  introduced.
- Bundled builds require `NODE_ENV=production` and `EXPO_NO_DOTENV=1`, reject
  embedded E2E credentials and forbid automatic test login. Aggregate Gradle
  tasks cannot bypass release validation. API/profile changes invalidate the
  bundle task's up-to-date check.
- Metro excludes only project-generated native build/cache directories,
  temporary output and private device evidence; application sources, package
  sources and brand assets remain discoverable. No directory is deleted.
- `react-dom@18.3.1` is now an explicit dependency matching React. It was already
  in the lockfile as an inferred peer but Expo Doctor rejected its missing direct
  declaration. No dependency upgrade or business API change was introduced.

## Checks and current evidence

- Local Android build-contract tests: 9 passed. They cover environment/profile
  separation, test credential rejection, production signing separation,
  loopback policy, native/Expo identity and Metro path exclusions.
- Focused API/config Vitest tests: 22 passed. Production policy self-test also
  passed, including seven URL cases and Android network/manifest checks.
- Initial full CI: 825 tests in 64 files and TypeScript passed; Expo Doctor
  failed solely on the missing explicit react-dom peer. The isolated development
  launcher contract passed 14 tests. The follow-up CI passed completely on the
  corrected snapshot: 825 Vitest tests, nine Android build-contract tests,
  14 launcher tests, security/discovery checks, production contract, Expo config,
  TypeScript and Expo Doctor. These are automated checks, not device proof.
- First offline native build failed because release React Native/Hermes AARs
  were not cached. Those official dependencies were downloaded through Gradle.
  The first packaging attempt was interrupted while diagnosing its slow local
  Metro traversal; no APK from it is counted as accepted. A new bounded-memory
  build uses the reviewed source and cached dependencies. Its offline retry
  compiled JS/Hermes and native code, but failed resolving an uncached
  `androidx.activity:activity-ktx:1.7.0` dependency for Android Lint. Retrying with
  Gradle network access passed Lint and `:app:assembleAcceptance` in 34m 16s
  (648 actionable tasks: 380 executed, 268 up-to-date). No checks were disabled.

## APK inspection

- Single local output: `mobile/android/app/build/outputs/apk/acceptance/app-acceptance.apk`.
  Size: 29,564,557 bytes. SHA-256:
  `27219344cdb604e23c27b0b906662339a8e3a6343fbd559fee6b8bd8fc9f0a6d`.
- `aapt` confirms the separate acceptance package, `DIMAX Test` label,
  version `0.1.0-acceptance`, versionCode 1, ARM64 only, minSdk 24 and targetSdk 34.
  The manifest is not debuggable, disables Android backup and uses only the
  acceptance app link scheme. Overlay and external-storage permissions are absent.
- `apksigner verify` passed APK signature v2. The signer is the local Android
  Debug certificate, not a production key. This APK is not for public release.
- ZIP inspection confirms a 2,195,972-byte embedded Hermes bundle with magic
  `c61fbc03c103191f`, ten font files and the matching embedded Expo identity.
  There are no `.env`, keystore, PEM, SQLite/database or source-map entries.
  The bundle and 256 tracked source files were checked against the two known
  local private test passwords without matches; this is not a universal secret
  scan guarantee.
- The packaged bundle SHA-256 matches the verified generated bundle:
  `c840379f214df712b04423a8a3c72752107abbcb14228cc079df476e2eefc4199`.
  Only one APK is retained in the acceptance output directory; no extra APK
  copy or public binary upload was made.
- Compiled network XML was inspected inside the APK: cleartext is denied by
  default and allowed only for `127.0.0.1`, without subdomains.

## Source backups

Local mobile commits: `181a23d` (bundled variant) and `d0aed71` (peer/Metro fix).
After explicit public-source authorization, source-only snapshots were pushed
to [the mobile backup branch](https://github.com/maxsav2704-design/dimax-ops-mobile/tree/codex/standalone-acceptance-20261016).
The current snapshot is `635c93553b44e40f89f332c5a0e872bc9b94fb5c`;
it includes the previously committed local mobile work without publishing its
unpublished historical commits. APKs, databases, local env files, keystores and
private device session files are excluded. The working tree remains on its
original branch. Unrelated root/backend AI changes are not included.

Initial run: [38935552247](https://github.com/maxsav2704-design/dimax-ops-mobile/actions/runs/38935552247).
Follow-up run: [38936323915](https://github.com/maxsav2704-design/dimax-ops-mobile/actions/runs/38936323915).

## Acceptance boundary

Native build and APK inspection passed. Installation and device cold-start
results must be recorded below before declaring this block complete. No release keys were
created, no working app was replaced, and no earnings or installer queue was
modified by this implementation. Reaching a login screen alone does not prove
authenticated sync or cached earnings with Metro and the API unavailable.

## Device handoff

- The connected Android 15 phone was authorized at the start. Only the original
  installer package was present; the acceptance package did not already exist.
  No Metro or acceptance API listener was running on host ports 8081/8001.
- Streaming APK installation stalled. After canceling it, a non-streaming retry
  also stalled: its temporary `/data/local/tmp/app-acceptance.apk` had zero bytes.
  Both installation commands were stopped; neither reported success. The phone
  package query still listed only the original installer application.
- Reconnecting only the ADB USB transport changed its state to `unauthorized`.
  The user was asked to unlock the phone and confirm its normal USB-debugging
  prompt. No device security setting, application storage or account was changed.
- The user confirmed USB debugging, restoring authorized access. A new
  non-streaming attempt transferred all 29,564,557 bytes in 0.802 seconds, but
  Android rejected installation with `INSTALL_FAILED_USER_RESTRICTED: Install
  canceled by user`. The user was asked whether an installation confirmation
  appeared; no installer protection or device security setting was bypassed.
- After the user offered to confirm installation, a retry hit a USB connection
  reset. ADB recovered with the device authorized; the following attempt again
  copied the whole APK (0.805 seconds) and received the same user-restricted
  installation error. Further retries were stopped pending the user's check
  of Xiaomi's separate USB-installation permission. This is a device gate,
  not a successful installation or a demonstrated APK runtime defect.
- Post-failure checks confirm the acceptance package is absent, the temporary
  APK was removed by the installer, and the original app remains version 0.1.0
  with the unchanged update time `2026-10-15 06:02:21`. Both prior USB reverse
  mappings (8081 and 8001) were restored. There is no leftover APK on the phone.
- Installation, cold launch without Metro, normal test sign-in, authenticated
  sync and offline earnings in this exact APK remain pending. The earlier debug
  build's successful financial acceptance is not counted as standalone proof.
- Next: resolve the normal device installation confirmation, inspect package
  presence, install this APK without replacing the original app, inspect the
  cold-start screen and errors, then use normal sign-in against the isolated API.
  Restore USB mappings and remove only test-owned temporary files after testing.
  No Docker stack or Metro was started in this step.
