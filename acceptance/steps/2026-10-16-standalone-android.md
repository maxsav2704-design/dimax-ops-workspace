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
  Only one APK is retained in the acceptance output directory; no extra host
  copy or public binary upload was made. The device handoff below tracks the
  temporary copy for normal installation from the phone's Downloads folder.
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

Native build, APK inspection, separate installation, ordinary sign-in, initial
sync, unauthenticated route protection, authenticated offline cold start and
earnings refresh after reconnection passed in this exact APK. No production
release keys were created, no working app was replaced, and no new work or
earning was created. This is standalone startup/cache acceptance, not a repeat
of every offline-write/conflict or factory-approval scenario in this APK and not
production certification.

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
  mappings (8081 and 8001) were restored at that checkpoint. The failed installer
  left no APK on the phone.
- The user subsequently confirmed that USB installation is enabled. ADB itself
  again delayed even read-only package queries; restarting only the host ADB
  service restored responsive, authorized access with no reverse mappings.
  The phone was awake and unlocked, with no effective user/device-policy install
  restriction. A fresh complete transfer still received the same installation
  cancellation. No permission, verifier or security setting was changed.
- The Android system buffer identifies the actual gate:
  `com.miui.securitycenter/com.miui.permcenter.install.AdbInstallActivity`
  opened at 21:17:24 and closed at 21:17:36 (Asia/Jerusalem, October 16).
  `PKMSImpl` then reported installation canceled by user. This proves that the
  confirmation window appeared; it does not establish whether its dismissal
  was a timeout or a tap. Do not describe the USB-installation toggle as disabled.
- To avoid repeating that short confirmation window, the same APK was copied
  once to `/sdcard/Download/DIMAX-Test-standalone-20261016.apk` for normal
  user-confirmed installation from Files/Downloads. Its device-side SHA-256
  matches the inspected host APK. This copy was removed after the installation
  described below. No public binary upload,
  application storage injection or installer-protection bypass is involved.

## Installed device proof

- Android package inspection confirmed successful separate installation at
  `2026-10-16 21:23:17`, version `0.1.0-acceptance`, versionCode 1, with no
  DEBUGGABLE flag. The installed `base.apk` SHA-256 equals the inspected host APK.
- With no ADB reverse mappings and before starting any test containers,
  force-stopping only DIMAX Test and launching its activity returned `COLD`,
  Android activity time 933 ms. The actual screen and UI hierarchy showed the
  normal empty sign-in form, rendered brand fonts and icons, not a Metro error
  or a blank page. Activity timing is not an end-to-end performance benchmark.
- A second force-stop followed by the acceptance `://earnings` deep link returned
  `COLD` (1037 ms). The actual hierarchy again contained SECURE SIGN IN,
  Company UUID and Sign In. The unauthenticated protected-route check passed.
- Process-scoped AndroidRuntime/ReactNativeJS/ReactNative/Expo error-log inspection
  after the first cold launch returned no matching error entries. This is a
  scoped startup observation, not exhaustive runtime stability certification.
- An initial injected locale tap had no visible effect. Later, after the user's
  explicit request to sign in on their behalf, ordinary keyboard input and a
  normal form-button tap worked. No touch-injection security permission was
  changed and no account/tokens were injected into application storage.
- Only the existing isolated DB, API and gateway containers were then started.
  The API needed startup time before `/ready` became healthy. A normal API login
  with the saved synthetic installer confirmed the expected company and
  INSTALLER role; its October total remains 18.02 ILS. No credentials or tokens
  were bundled or published to GitHub. This preliminary API check is distinct
  from the subsequent mobile sign-in evidence below.

## Authenticated standalone acceptance

- Only API port 8001 was mapped; Metro remained stopped and unmapped. The user
  entered the correct company UUID and installer email, but the first login
  received INVALID_CREDENTIALS. After explicit authorization to complete login,
  the existing synthetic password was entered into the focused password field
  through normal keyboard events and the ordinary sign-in button was pressed.
  There was no password reset, automatic-login build or direct session write.
- The phone displayed Device Test Installer. Server evidence confirms mobile
  `/auth/login` returned 200 and the expected installer/company performed sync
  with zero outgoing events. Initial cursor 0 returned `reset_required=true`,
  a one-project/one-door snapshot and cursor 83. Later sync used/acknowledged
  cursor 83 with `reset_required=false`, zero changes and zero failed ACKs.
- Actual earnings UI displayed 18.02 ILS, two work rows, one project and current
  data. Removing the only API reverse mapping left no reverse mappings at all.
  DIMAX Test was force-stopped and cold-started into earnings without Metro/API
  (Android activity time 889 ms). It retained the signed-in installer and 18.02
  ILS/two rows, explicitly labelled the result as an offline copy and explained
  that the last saved calculation was being shown. It did not return to login.
- Offline navigation to the assigned fixture project displayed RUNTIME-101,
  one installed door out of one and zero queued actions. The queue screen
  independently showed zero pending actions, errors and blocks, and an empty
  queue. No completion, issue, additional-work or pricing action was submitted.
- Restoring only the 8001 mapping and returning to earnings restored the
  current-data label and removed the offline-copy label. The same 18.02 ILS and
  two rows remained. The earnings endpoint returned 200 and incremental sync
  resumed at cursor 83 without resetting the snapshot or sending work events.
- A final read-only administrator ledger check confirmed exactly two entries,
  DOOR and ADDON, each 9.01 ILS, scoped to the expected project and installer.
  Total remained 18.02 ILS. Scoped error-log inspection of the offline-restarted
  process returned no AndroidRuntime/ReactNativeJS/ReactNative/Expo errors.

## Restored state and follow-up

- The Downloads APK and all session-owned screenshot/XML files on both the
  phone and host were removed after verification. Only the original local build
  output APK is retained. The original installer app still has version 0.1.0
  and update time `2026-10-15 06:02:21`; its storage was not cleared or manually
  edited. DIMAX Test remains signed in to its separate synthetic installer;
  the original app's A-1 account was not replaced or signed out.
- The three temporary DB/API/gateway containers were stopped after verification,
  restoring the initial stopped-container baseline. Original reverse mappings
  for 8081 and 8001 were restored. No volumes, databases or app data were deleted.
  No ordinary stack, Metro, mail worker or production service was started.
- Remaining production gates: real domain/HTTPS, external SMTP, owner-controlled
  signing, and the broader production release matrix. This debug-signed,
  loopback-only acceptance APK is not a public production build.
- Follow-up UX finding: an invalid login displayed the raw API JSON error rather
  than a localized human-readable message. Successful login was verified, but
  that error presentation remains to be improved; no unrelated UI redesign was
  folded into this acceptance step.
