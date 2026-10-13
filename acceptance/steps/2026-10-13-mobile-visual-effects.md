# Mobile Visual Effects (E1-E6, line-art door)

## Completed Scope

Presentation-only effects on top of the October 12 visual polish, each a
reviewed block in the `mobile` repository. Agreed direction from the owner:
every effect must read as 3D depth (bevels, lighting, perspective), never flat
graphics; decorative photos are not replaced on the home card. No sync command,
amount, assignment rule or photo/signature rule changed. The owner reviewed
each block in the Vite preview (`npm run ui:preview`, project/home/earnings
pages) before it was committed.

- `c24c8d1` preview findings: door sheet hugs its content; a door with an
  issue shows one flag; the preview i18n fixture exposes `isRTL`.
- E1 `3ce8d50`: `Reveal` gains index staggering (36 ms steps, max 12) and a
  perspective tilt-in; `useAnimatedNumber`/`AnimatedNumber` ease counters;
  `ProgressRing` sweeps to its value over an engraved groove with a glow and a
  lit edge. Applied to door rows, floor cards, project cards, today's events,
  earnings lines, the project installed counter and the earnings total.
- E4 `308d5d8`: bevelled `SectionCard`, glossy `ActionButton` with a sinking
  pressed state, `StatusPill` gloss, extruded `DoorGlyph`, native-driven
  parallax on the project header, glass bottom navigation with a lit rim.
- `1f1927a` door: after a rejected "cosmic" draft (read as a book), the door
  is thin gold line work in SVG: frame on a floor line, ajar leaf with an inner
  panel, hinges, knob, dark offset for depth, soft status glow. Same API.
- E2 `f2d7aba` (fireworks removed on request): `detectCompletionEvents` finds
  a floor or the project that the installer's own "Installed" just completed
  (never on load or sync); the sheet closes, the screen scrolls to the top,
  success haptics fire and a completion card offers "Next floor".
- `2ff8793`: the building photo returns to the home progress card; the unused
  `ProjectSkyline` is removed and the `DoorGlyph` test gets its own file.
- E3 `2a5e702`: `FloorHeatmap`, an isometric floor map above the explorer: one
  row per floor, one thin-lined tile per door lit by status, issue dot, gold
  outline on the selected door; a tap opens that door.
- E5 `954ea5f`: `TickBar` (one bevelled tick per door, filled in sequence,
  plain fill above 24) replaces the floor progress fill; `Sparkline` of the
  last seven days of recorded pay under the month tile on the project screen,
  built by `buildRecentDailyTotals` with exact decimal sums.
- E6 `bdfb566`: `StatusPill` cross-fades between tones and can ease a numeric
  value; percentages on the project pill, floor cards and home cards ease.

## Evidence

- `npm run typecheck`: PASS after every block.
- Full Vitest suite: 805 -> 815 PASS (63 files), re-run in full after every
  block; `test:coverage-contract` 63 files.
- Preview checks (393 px emulated, RU and HE): door sheet, line-art door,
  floor map, floor ticks, home photo, engraved ring, completion card. Motion
  itself (stagger, counters, sweep, parallax, cross-fade) is verified by tests
  and by final-frame screenshots only.
- Not performed: emulator or physical device, APK build, real haptics, native
  shadows/elevation and native-driver animation behaviour.

## Device Checklist Before An APK

- E1: lists settle in with a slight tilt in order; "Installed" and totals
  count up; the home ring sweeps; with Reduce Motion everything is instant.
- E4: cards show a lit top edge and a dark base; primary buttons look glossy
  and sink on press; the project header drifts and fades on scroll; the bottom
  bar reads as glass with a lit rim.
- Door: the line-art door reads as a door at row size (54 px), card size
  (104 px) and on the login screen (132 px); the status glow matches the row.
- E2: finishing a floor closes the sheet, scrolls up, buzzes and shows the
  card; "Next floor" focuses the next floor; opening an already complete floor
  shows nothing; sync does not re-trigger.
- E3: the floor map tiles match the explorer counts and colours; tapping a
  tile opens that door; the selected door is outlined in gold.
- E5: floor ticks match the door count and fill one by one; the sparkline
  appears under the month tile once the project has recorded pay.
- E6: the queue pill blends from amber to green after sync; percentages ease.

## Data, Storage And Limits

No API, database, migration or dependency changes in this step. Local commits
only; nothing was pushed. The preview server and the browser viewport
emulation were stopped at the end of the session.

## Next Ordered Step

1. Run both device checklists (this file and the October 12 report) on a
   physical Android phone; fix anything found.
2. M9: have the home sync pill reuse `buildSyncStatusPresentation`.
3. M10: floor sections with sticky progress (virtualised list), only after the
   device check.
