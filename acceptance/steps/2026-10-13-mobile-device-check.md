# Mobile Device Check (2210129SG, Android 15)

## Completed Scope

First physical-device pass over every visual block since October 12 (M1-M8,
M4a-c, E1-E6, line-art door). The phone ran the existing
`artifacts/android/dimax-installer-debug.apk` (built 2026-09-11, no
`expo-haptics` native module) with the current JavaScript served by Metro
over `adb reverse`. The quality gate (`npm run quality-gate`) passed before
the pass, with one 5 s timeout in a screen test under full-gate load.

Fixed from what the phone showed, each with the test suite green:
- `db2ccd0`: the home sync pill now reuses `buildSyncStatusPresentation`
  (M9), so the pill and the strip can no longer disagree.
- `e7db7dd`: `triggerHaptic` resolves `ExpoHaptics` through
  `requireOptionalNativeModule`, so a binary without the module stays silent
  instead of failing at startup. Needed to run new JavaScript on the old APK;
  also protects future JS-only updates.
- `7eae33d`: Vitest timeout 15 s; the gate flake is gone.
- `7b844b6`: the sync strip overlapped the last card and the raised journal
  tab (strip `marginBottom` 38, `bottomNavClearance` 150); long unit labels
  ran under the door glyph in the sheet (`paddingTop` 164); the Russian
  "Sync now" wrapped mid-word ("Синхронизация").

## Evidence

Screenshots in `artifacts/screens/phone-2026-10-13-*.png` (ignored by git,
local only): home RU and HE, projects list, project screen with floor map,
floor ticks and door rows, door sheet before and after the title fix,
earnings HE, calendar, journal, profile, sync queue.

Confirmed on the phone:
- Type scale readable; brand header clear of the locale switch (M1).
- Engraved progress ring, eased counters, list reveals (E1); bevelled cards,
  glossy buttons, glass navigation (E4); door sheet with grip, backdrop and
  Android back (M4c); line-art door at row and card size; isometric floor map
  with the selected door outlined (E3); per-door floor ticks (E5); the
  7-day pay sparkline with real recorded pay (E5); sync strip on every
  screen, inactive on the queue screen (M5); Hebrew: chevrons point left,
  `תכנית` tab, RTL strip (M8).

Not confirmed:
- Haptics: the installed APK predates `expo-haptics`; needs a new build.
- Completion card (E2) and "Next door" (M4a): every door in the test project
  is already installed and locked; needs a project with open doors.
- Reduce Motion behaviour, keyboard over the not-installed form, 320 px
  layouts.

## Data, Storage And Limits

No API, database or dependency changes. The phone's offline queue (one
blocked door status from October 1) was left untouched; nothing was synced
or signed out. Metro and `adb reverse` were stopped at the end of the pass.
The machine has no JDK, so no new APK was built.

## Next Ordered Step

1. Build a fresh debug APK (needs JDK 17 or EAS Build) to verify haptics
   and bind evidence to its SHA-256 per `ANDROID_GO_NO_GO.md`.
2. Re-run the E2 and M4a checks on a project with open doors.
3. M10 (virtualised floor sections) only if a large project shows jank; the
   9-door test project renders instantly.
