# Mobile Haptics Check On A Fresh Debug APK (2210129SG, Android 15)

## Completed Scope

Built a fresh debug APK from the current mobile tree (JDK 17, Gradle 8.10.2,
isolated `GRADLE_USER_HOME` and project cache under `%LOCALAPPDATA%\Temp\claude`)
and installed it on the phone to close the one item left open on
2026-10-13: haptic feedback.

- APK: `mobile/android/app/build/outputs/apk/debug/app-debug.apk`
- Size: 129,138,718 bytes, built 2026-10-15 05:12
- SHA-256: `6df60dc77541d42f8aa37145f625c3e17cbdc74e377cd901e1ac4f6d520936d0`
- Contains `expo.modules.haptics.HapticsModule` (dexdump) and native code for
  all four ABIs (`-PreactNativeArchitectures=arm64-v8a` was not honoured).
- Installed on device `a269dc99` at 05:34:40; JavaScript served by Metro over
  `adb reverse tcp:8081`.

## Evidence

Screenshots in `artifacts/screens/phone-2026-10-15-0{2,3,4}-*.png` (local,
ignored by git): home RU on the new build, objects list, project screen after
the sync press. Vibrator service dumps before and after the press are in
`artifacts/vib-before.txt` and `artifacts/vib-after.txt`.

Trigger used: the header sync button on the project screen. Sync failed with
"Network request failed" (the test backend is not reachable from the phone),
which runs `triggerHaptic("error")` in `performAction`.

Result: no vibration. `dumpsys vibrator_manager` records touch vibrations
from other apps on the same day but nothing from
`com.dimax.operations.installer` at 05:41; `dumpsys package` lists no
`android.permission.VIBRATE` for the app.

## Root Cause (studied by code, confirmed on device)

`mobile/android/app/src/main/AndroidManifest.xml` line 5 removes the
inherited permission:

    <uses-permission android:name="android.permission.VIBRATE" tools:node="remove"/>

and `mobile/scripts/validate-production-config.mjs` (part of
`npm run quality-gate`) requires that removal: "Android release manifest must
remove inherited VIBRATE". The merged manifest therefore has no VIBRATE
permission, the Vibrator call is rejected, and `triggerHaptic` resolves to
`false` as designed. The JavaScript side and the native module are both in
place; the app simply is not allowed to vibrate.

So the haptics layer is safe (no crash, no error shown) but inert on Android
under the current release-hardening policy. iOS is not affected by this
manifest rule but was not tested (no device).

## Decision Needed (not changed, waiting for the owner)

Two consistent options; neither was applied:

1. Keep the policy. Haptics stay a no-op on Android. Document this in
   `ANDROID_GO_NO_GO.md` and the mobile README as a known limitation.
2. Allow vibration. Delete the `tools:node="remove"` line for VIBRATE in the
   main manifest, drop `"VIBRATE"` from the permission list in
   `validate-production-config.mjs`, extend its tests, and rebuild. This is a
   change to an existing security contract and needs explicit approval.

## Data, Storage And Limits

No API, database or dependency changes. No source files changed in this
step. The phone's offline queue (one blocked door status from October 1) is
unchanged: the forced retry failed on the network before reaching the
server. Metro and `adb reverse` were left running for the next check.

## Next Ordered Step

1. Owner picks option 1 or 2 above.
2. Re-run the E2 completion card and M4a "Next door" checks on a project
   with open doors (still blocked by test data: every door is installed).
3. M10 only if a large project shows jank.

## Update 2026-10-15 12:12 — option 2 approved and verified

The owner chose option 2. Changes (mobile repo only):

- `mobile/android/app/src/main/AndroidManifest.xml`: the line that removed
  `android.permission.VIBRATE` is gone; storage permissions stay removed.
- `mobile/scripts/validate-production-config.mjs`: the contract now requires
  the two storage permissions to be removed and VIBRATE to be kept
  ("must keep inherited VIBRATE for haptic feedback"). The self-test gained a
  negative case: a sandbox manifest that strips VIBRATE again must fail.

Quality gate: exit 0 (815 tests / 63 files, production-config contract with
the new negative case, config check, typecheck).

Rebuilt APK (incremental, `BUILD SUCCESSFUL in 12m 17s`, 65 tasks executed):

- `mobile/android/app/build/outputs/apk/debug/app-debug.apk`
- Size: 149,357,907 bytes, built 2026-10-15 06:01
- SHA-256: `038ceb091b6a867f0231a5de52fcd3966cfececea09f606e1588bf6a7eeb858c`
- `aapt dump permissions`: INTERNET, VIBRATE
- Installed on `a269dc99` at 06:02:21; `dumpsys package` shows
  `android.permission.VIBRATE: granted=true`.

Device result (confirmed by test): on the project screen the header sync
button was pressed at 12:11:59; sync failed on the network as before and
`dumpsys vibrator_manager` recorded a new entry at 12:12:00.255:
`effect | finished | duration: 342ms | usage: UNKNOWN |
com.dimax.operations.installer (uid=10251)`. This is the error pattern of
`expo-haptics` (`triggerHaptic("error")`). Dumps: `artifacts/vib-before-2.txt`,
`artifacts/vib-after-2.txt`; screenshots
`artifacts/screens/phone-2026-10-15-05-sync-haptic-vibrate.png` (captured
before the icon font loaded) and `phone-2026-10-15-06-project-after-sync.png`.

Side effect during the check: an adb tap meant for the sync button landed on
the locale switch while the app was still on the home screen, so the phone
UI switched to Hebrew once; it was switched back to Russian. No data changed.

Still open: success haptic on "Installed" and the completion card need a
project with open doors (test data has none).
