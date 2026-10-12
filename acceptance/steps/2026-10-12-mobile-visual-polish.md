# Mobile Visual Polish (M1-M8)

## Completed Scope

Presentation-only improvements to the installer app, delivered as eight
reviewed blocks. No sync command, amount, assignment check or photo/signature
rule changed; installers still never see a price input. All work is in the
`mobile` repository; backend and admin were not touched by this step.

- M1 `c7bcad9`: `installerTheme.type` scale (caption 12 / meta 13 / body 15 /
  title 17 / display 22) and `maxFontScale` 1.4 applied in `BrandText`. All 98
  literal font sizes below 12px moved to the caption token; a static test scans
  `app/` and `src/` so no screen style can drop below the floor again.
- M2 `fb0874b`: `expo-haptics ~14.0.1` behind a silent-failing `triggerHaptic`
  wrapper fired by outcome on the project screen (installed/add-on saved,
  not-installed warning, failure error, failed refresh warning). `Pop`, `Pulse`
  and `AnimatedFill` motion helpers honour reduced motion.
- M3 `615333c`: stock photos replaced by `DoorGlyph` (status-tinted vector door)
  on the door card and login, and `ProjectSkyline` (one bar per project from the
  loaded summaries) on the home progress card. Never-rendered `DoorTile` and
  abandoned glyph styles removed. Image assets were kept on request.
- M5 `cff7e28`: observable sync status store fed from the single sync funnel
  (`enqueueSync`) and every queue mutation; `useSyncStatus` hook reloads the
  snapshot on change and foreground; `SyncStatusBar` above the bottom
  navigation on all eight screens. Offline is set only after `NetworkError`.
- M6 `64980b1`: `EarningsDayChart` on the earnings screen, built from the
  period's recorded rows with exact decimal day sums; deductions in red,
  tap-to-focus a day. Only server-recorded amounts are shown.
- M7 `e21ee62`: `Skeleton`/`SkeletonList` (rows, cards, tiles) replace the six
  screen-level `ActivityIndicator` states; loading text stays visible and
  announced.
- M8 `e095f2b`: `DirectionalChevron`/`chevronIcon` replace every hand-flipped
  chevron, including `MetricTile` and `Row` chevrons that never flipped in
  Hebrew; trailing values align by reading direction; Hebrew "Plan" tab renamed
  to `תכנית` so it no longer collides with the work journal.
- M4a: "Next door" action on the door card selects the next door still open
  for work in the displayed floor order (wrapping), via the existing
  `openDoor`; it never closes or submits anything. Full suite 803 PASS (59
  files) after this block.

## Evidence

- `npm run typecheck`: PASS after every block.
- Full Vitest suite grew from 768 to 798 PASS (58 files); re-run in full after
  every block. Two component tests needed the i18n provider mocked once
  `mobile-ui` started reading reading direction (fixed in M8).
- `test:coverage-contract`: 58 files covered.
- Diff review: 43 files, +1425/-344 across the seven commits; each commit lists
  only the files of its block.
- Not performed: emulator or physical-device run, APK build, real network
  outage, real haptics. `Animated`, haptics and Expo modules are mocked in
  tests, so motion, vibration and layout on glass remain unverified.

## Device Checklist Before An APK

- M1: door rows readable; long labels ellipsise; compact brand header clear of
  the locale switcher; OS font scaling at maximum keeps layout intact.
- M2: Installed gives a success buzz and a springing check; Not installed a
  warning buzz; a save failure an error buzz; status-icon ring on the installed
  door; floor and project bars glide; with Reduce Motion nothing animates.
- M3: home skyline does not cover text and looks right with one project; door
  card glyph carries status colour and issue flag; login glyph clears inputs at
  320px.
- M5: strip visible on all screens and clear of the centre journal button;
  offline work raises the queued count at once; airplane mode shows Offline and
  recovers; tap opens the queue; inactive on the queue screen.
- M6: bars for the month, deduction in red, tap selects the day, 20+ days scroll.
- M7: skeletons on home, plan, earnings, issues, journal and document screens.
- M8: in Hebrew every chevron points left, trailing numbers align correctly,
  `תכנית` differs from `יומן עבודה`.

## Data, Storage And Limits

No API, database or migration changes. One dependency added
(`expo-haptics`). `assets/premium/*.jpg` remain in the repository (referenced
only by `preview/main.tsx`). Local commits only; nothing was pushed.

## Next Ordered Step

1. Run the device checklist on a physical Android phone; fix anything found.
2. M4 door walkthrough: split `app/project/[id].tsx` into components without
   behaviour change, then floor sections, a door sheet and "next door".
3. M9: have the home sync pill reuse `buildSyncStatusPresentation`.
