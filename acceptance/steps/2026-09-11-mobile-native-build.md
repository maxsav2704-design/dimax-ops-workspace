# Mobile acceptance: current Android build

This follows `2026-09-11-mobile-preflight.md`. Scope is the native debug build,
its provenance and current Android JavaScript bundle, not installer business
actions or production approval. Mobile source remains clean at
`515cb12117727a069dab56da04a88039e4b5eeff`.

## Confirmed Native Build

The existing `workspace.cmd test-mobile-native-build` completed successfully:

- Gradle 8.10.2, Java 17.0.17, Node 20.19.5.
- Existing single-worker/768 MB Gradle heap settings were retained.
- `BUILD SUCCESSFUL in 17m 59s`; 386 tasks, 80 executed and 306 up-to-date.
- The command verified the actual APK with `aapt` and `apksigner`.
- Application ID: `com.dimax.operations.installer`.
- minSdk 24, targetSdk 34; Android Debug signature verified.
- APK generated/verified at `2026-09-11T17:29:42+03:00`.
- Artifact: `mobile/artifacts/android/dimax-installer-debug.apk`.
- Size: 138,986,186 bytes.
- SHA256: `2FF4362630E0E50412000F464FC9AED7341C5C659BD4C178ACB2C35AE61E7FA4`.
- Metadata: `mobile/artifacts/android/native-build-latest.json`, current source
  hash above and `source_dirty: false`.
- ZIP inspection confirms arm64-v8a, armeabi-v7a, x86 and x86_64 libraries.

Log: `artifacts/acceptance-20260909/mobile-native-build-20260911.log`.

This was a build against the existing Gradle/dependency cache, not a clean-room
toolchain installation. The existing build helper removed only its known,
resolved generated Android directories under the workspace. The previous APK
was replaced only after successful compilation and artifact verification.

### Why the APK Hash Has Not Changed

The rebuilt native debug artifact has the same SHA256 as the saved August APK.
The build did run at the current source revision. Independent ZIP inspection
found no embedded `index.android.bundle`, `.jsbundle` or `.bundle` entry. The
React Native debug variant loads its JavaScript from Metro; a native artifact's
hash does not prove that the current JavaScript is being used on a phone.

Do not distribute this debug APK as a standalone offline or production release.
It still needs the correct Metro session for device testing. A current APK build
alone is not evidence of successful native startup or offline cold restart.

### Warnings Kept Visible

Manifest merging emitted three non-fatal warnings for existing `remove/replace`
rules with no matching source declaration: VIBRATE, usesCleartextTraffic and the
Expo FileSystemFileProvider authorities. No manifest or security policy was
changed to silence these warnings. Compilation and signature verification passed.

## Android JavaScript Probe

Status: PASS. A real Metro bundle probe completed using
the existing `scripts/mobile-metro.ps1 -Action smoke` helper, Node 20.19.5, one
worker, temporary port 62816, isolated API `http://127.0.0.1:8001`, and automatic
login disabled. No test-account credentials were supplied.

- Actual Android bundle request: HTTP 200.
- Bundle size: 8,646,782 bytes, above the helper's 500,000-byte minimum.
- Probe time reported by the helper: 348.4 seconds; command exit code 0.
- The helper's error-payload check passed.
- After completion, the temporary probe directory was absent and no listener
  remained on port 62816. The existing admin preview was not switched or stopped.

Log: `artifacts/acceptance-20260909/mobile-bundle-smoke-20260911.log`.
This verifies compilation and delivery of the current Android JavaScript bundle,
not its execution on a native device, API authentication or successful sync.
`EXPO_OFFLINE=1` in this helper is not evidence of app-level offline behavior.

## Device and Safety Boundary

ADB returned no connected devices before the native build, after the build and
again after the bundle probe. No phone
installation, app launch, login, database inspection, offline action or sync
operation has been performed. The configured emulator was not started on this
4 GB workstation while its other services were running.

Normal and acceptance Docker services were left running; no databases or volumes
were reset. No existing phone application was uninstalled and no SQLite/outbox
data was cleared. Code and business behavior did not change in this build step.

Next: verify a connected/authorized Android device.
Inspect the installed app and preserve any pending work before replacing it.
Do not use uninstall or clear-data commands to bypass installation problems.
Actual installer visibility, completion, offline and document flows remain
separate acceptance items. No frozen readiness percentage is advanced here.

Native build and bundle checks are complete; installation/startup remains BLOCKED
by the absence of a detected device. This checkpoint is stored locally only.
No GitHub publication was attempted; a local commit is not a remote backup.
