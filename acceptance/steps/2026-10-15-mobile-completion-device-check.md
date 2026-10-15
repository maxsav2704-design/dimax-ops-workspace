# Mobile Completion Card, Next Door And Success Haptics On Device

Phone `a269dc99` (2210129SG, Android 15), package
`com.dimax.operations.installer`, debug APK SHA-256
`038ceb091b6a867f0231a5de52fcd3966cfececea09f606e1588bf6a7eeb858c`
(VIBRATE kept, see `2026-10-15-mobile-haptics-apk-check.md`), JavaScript from
Metro over `adb reverse tcp:8081`, API over `adb reverse tcp:8001` to the
isolated acceptance stack. Test Installer A-1, company DIMAX Acceptance A.

## Environment Changes (acceptance stack only)

- `docker compose -f docker-compose.acceptance.yml up -d --wait db minio
  mailpit api gateway`: existing containers started, no volume recreation.
- `dimax_acceptance` was on migration `0069_factory_mailbox` while the
  backend tree (commit `159564c`) expects `0074_work_price_accruals`; the
  API failed on `doors.assignment_started_at`. Ran `alembic upgrade head`
  inside the api container: 0070-0074 applied. `dimax_acceptance_tests`
  was left on 0069 (not needed here).
- Door assignments changed through the application's own use case
  `ProjectUseCases.assign_installer_to_door` (scripts
  `artifacts/acceptance-reassign-door-to-a1.py` and `...-door2-to-a1.py`,
  local only): `B-1-102-fire-FR-102` and `B-2-201-dira-EN-201` moved from
  Test Installer A-2 to A-1. Both were NOT_INSTALLED, unlocked, with no
  earnings. The sync change log received the standard
  assign_doors / assigned_to_you / DOOR / removed_from_you entries.
- No accounts, passwords, prices, rates or existing earnings were touched.
  The owner's acceptance password was not read; a first attempt to create a
  synthetic QA admin was blocked by the tool permission layer and dropped.
- Claude Code permission rule added in `.claude/settings.local.json`
  (git-ignored) for `docker compose -f docker-compose.acceptance.yml exec|up|ps`.

## Confirmed By Test On The Phone

1. **Pull after reassignment.** Header sync on the project screen pulled the
   new door: progress went 5/5 -> 5/6 (83%), later 6/7.
2. **E2 completion card + success haptics.** Opened `B-1-102` in the door
   sheet, tapped "Установлено" at 12:49:43. `dumpsys vibrator_manager`
   recorded three new effects from the app: 212 ms + 187 ms (expo-haptics
   success pattern) and a 59 ms TOUCH impact 160 ms later, matching
   `triggerHaptic("success")` followed by the delayed `"tap"`. The sheet
   closed, the list scrolled to the top and the card "Объект завершён ·
   6 / 6 дверей установлено" rendered with the trophy badge and close button
   (`artifacts/screens/phone-2026-10-15-10-installed-2s.png`, `-11-...-6s.png`).
   Queue badge went to "2 в очереди", strip stayed "1 заблокировано"
   (the legacy item below).
3. **Server side of the same action.** `doors`: INSTALLED, installer A-1,
   `installed_at 2026-10-15 09:49:43.447+00` (the phone's clock), locked,
   `installer_rate_snapshot 250.00`. `completed_work`: one ORIGINAL row,
   quantity 1.00, rate 250.00, amount 250.00. `sync_events`:
   DOOR_SET_STATUS `1792057783447-0qfg7u2n60`, `applied_at 09:50:30`, no
   `apply_error`. The phone's project screen then showed "Заработок сегодня
   250.00 ILS · Начислено по объекту" and month 513.50 ILS (3 lines).
4. **M4a next door.** After reassigning `B-2-201`, the sheet of the installed
   door `A-1-101-dira-EN-101` shows "Следующая дверь: B-2-201-dira-EN-201 ·
   осталось 1" (`phone-2026-10-15-13-sheet-next-door-button.png`). Tapping
   it switched the sheet to `B-2-201` (NOT_INSTALLED, status buttons
   enabled, `-14-sheet-after-next.png`).
5. **Error haptic** was already confirmed at 12:12 (342 ms pattern) on the
   network-failed sync; see the haptics step file.

## Observed, Not Changed

- The legacy blocked queue item from 2026-10-01 21:50 is
  "Дверь B-2-201-dira-EN-201 → Установлено · Заблокировано · Назначение
  изменилось" (1 attempt). Reassigning `B-2-201` back to A-1 means a
  forced retry of that item would now be accepted by the server and would
  accrue by the price rules for offline work; the door card shows "Работа
  требует проверки · В записи нет версии прайса". Nothing was retried or
  deleted; this is the owner's call.
- An unrelated `ISSUE` sync-change entry was emitted on the first
  reassignment because the door carries an open issue; expected behaviour.
- The first attempt to press header sync against the live API produced no
  haptic because an automatic reconnect sync was already running (button
  disabled while busy).

## Left As Is

- `B-2-201-dira-EN-201` remains open and assigned to A-1 (one open door for
  future checks). `B-2-202/2` stays with A-2.
- Acceptance stack running (its outbox worker was already restart-looping
  before this session). Metro on 8081 and both adb reverse mappings left
  running for follow-up checks.
- Phone locale was switched back to Russian after the accidental tap noted
  in the haptics step.

## Not Verified

Floor-completion variant of the card and the "next floor" hint (the only
floor with open A-1 doors is floor 2 with one door); Reduce Motion; iOS.

## Update 13:10 — narrow layout, keyboard, reduced motion

Display emulated at 320 dp (`wm size 880x2400` at density 440), app
cold-restarted, then `wm size reset`. Screenshots
`artifacts/screens/phone-2026-10-15-16..23-320dp-*.png`.

Confirmed by test at 320 dp:
- Home, objects list, project screen, floor map (7 tiles on two rows), door
  rows, door sheet (details grid collapses to two columns), add-on form and
  the sync strip all fit without horizontal overflow or clipped controls.
- Keyboard over a form: focusing the add-on comment field moved it from
  y 1654 to y 1009, fully visible above the keyboard (`-23-320dp-keyboard.png`).
  The bottom navigation and the sync strip also rise above the keyboard;
  they stay usable, so no change proposed.

Observed at 320 dp, cosmetic, NOT changed (fixes need owner approval):
1. Bottom tab label "Заработок" truncates to "Зарабо…" (tabs are five
   across 320 dp). Options: smaller tab font at narrow widths or a shorter
   RU label such as "Доход".
2. Long unit labels break mid-token: row "B-2-201-dira-E / N-201", sheet
   title "B-2-201-dira-EN-2 / 01". A smaller title size below ~340 dp or
   breaking only at hyphens would keep them readable.

Observed, by design: both status buttons of `B-2-201` are disabled while a
queued event exists for that door (the blocked 2026-10-01 item), so the
not-installed reason form could not be opened on this project. Duplicate
earning protection working as specified.

Not verified: Reduce Motion. Animation scales were set to 0 and the app was
restarted, but the owner started using the phone during the check, so the
run was aborted; scales restored to 1.0 and display size reset
(`settings get global *_animation_scale` = 1, `wm size` = physical).
Captures taken during the owner's use were deleted unviewed in detail and
are not part of the evidence.

## Update 13:12 — Reduce Motion confirmed

Re-run with the owner's consent: `animator_duration_scale`,
`transition_animation_scale`, `window_animation_scale` set to 0, app
force-stopped and restarted, foreground activity verified before every
capture; all three scales restored to 1 afterwards.

Confirmed by test (`artifacts/screens/phone-2026-10-15-24..27-reduce-motion-*.png`):
- Home: the progress ring and counters are at their final values (86 %,
  6/7) in the first capture after the home screen appears and unchanged
  2 s later; no fill or count-up animation runs.
- Door sheet: fully rendered 0.4 s after the row tap, no slide-in.
- No ReactNativeJS error lines in the 800-line logcat window.

Observed, not changed:
3. Project screen at 0.7 s after navigation (before the local database
   answers) shows a transient empty state: title "Объект", "0 / 0", "Двери
   не найдены" with a "Сбросить фильтры" button. A skeleton or a neutral
   loading row would be less misleading than a "not found" message. Not
   specific to reduced motion.
4. In this Metro-served debug session the vector icon font arrives late:
   header, tab-bar and card icons are blank for the first seconds after a
   cold start. Release builds bundle the font; not a device finding.

## Update 15:00 — fixes for the 320 dp observations, one by one

Environment note first: the Metro process started in the morning had
degraded (one font asset took ~10 s; the host had under 300 MiB free RAM),
so cold starts hit the 8 s font bootstrap timeout and rendered with the
system fallback font, which overflows at every width. Restarting Metro
brought asset time to 0.03 s. Captures taken with fallback fonts were
discarded. This is a development-server effect only; release builds bundle
the fonts.

**Item 1 (tab label "Заработок" truncates at 320 dp): attempted, reverted,
needs a wording decision.** `adjustsFontSizeToFit` with a 0.84 floor
(12 -> 10 px, the agreed minimum) passed the unit test but on the device
clipped the label to "Заработ" without an ellipsis, i.e. worse than before.
Geometry: five tabs share (320 - 24 - 14) / 5 ~ 56 dp each, while the bold
nine-letter word needs ~60 dp even at 10 px. Within the agreed font floor the
word cannot fit on one line. Options for the owner: a shorter Russian label
on screens narrower than ~360 dp (for example "Доход"), or allowing 9 px
for this one label. The change was reverted; nothing committed.

**Item 2 (door labels break mid-token): fixed, mobile commit `ec6e047`.** `breakableUnitLabel` inserts a
zero-width space after each hyphen or slash for the door row and the sheet
title; accessibility labels keep the raw text. Confirmed on the device at
320 dp: rows wrap as "A-1-101-dira- / EN-101", the sheet title
"B-1-101-dira-EN-101" fits on one line
(`artifacts/screens/phone-2026-10-15-31-320dp-rows-wrapped.png`,
`-32-320dp-sheet-wrapped.png`). Quality gate: 819 tests / 64 files, exit 0.
The project screen test's text collector now strips the zero-width marker
so its five existing door-link assertions keep comparing visible text.

**Item 3 (transient "no matching doors" while the project loads): fixed.**
`DoorExplorer` gained an optional `loading` prop (default false, so other
callers are unchanged); the project screen passes `localWorkspace === null`.
While it is true the doors section renders `SkeletonList` (3 rows,
`testID="project-doors-loading"`) instead of the empty state. Regression
test: with a deferred local load the skeleton is present, "No matching
doors" is absent and no door rows exist; after the load resolves the
skeleton is gone and the row appears. Device: skeleton visible 0.35 s after
navigation, real rows at 0.9 s
(`artifacts/screens/phone-2026-10-15-33-project-0.35s-loading.png`,
`-34-project-0.9s.png`). Quality gate: 820 tests / 64 files, exit 0.
The header still shows the generic "Объект" title and "0 / 0" during that
window; left as is (small, and the title needs the same local answer).

**Item 4 (icons blank for seconds after a dev cold start): not a defect** —
caused by the degraded Metro process described above; gone after the
restart (icons present in `-30-393dp-fonts-check.png`). Release builds
bundle the icon font.

## Update 16:15 — item 1 resolved with a compact label

**Item 1 (tab label at 320 dp): fixed** in the mobile repo ("feat(nav):
compact earnings tab label on screens narrower than 360 dp"). Instead of
shrinking the font, screens narrower than 360 dp show the compact Russian
label "Доход" at the unchanged caption size; the accessibility name stays
"Заработок"; English and Hebrew labels are unchanged. The shared native UI
test mock now exposes `useWindowDimensions` with a configurable window, and
the bottom-nav test covers 320 dp (compact), 360 dp (full) and EN/HE.
Device at 320 dp: all five labels fit on one line, no ellipsis
(`artifacts/screens/phone-2026-10-15-35-320dp-tabs-compact.png`). Quality
gate: 821 tests / 64 files, exit 0.

Environment: the phone's USB session dropped the adb reverse mappings a
third time today; each cold start after that shows the RN "Unable to load
script" screen until the mappings are restored. Not an app defect.

New observation at 320 dp (item 5, not yet changed): on the home screen the
empty-plan text "Сегодня нет запланированных работ" wraps to two lines and
the second line is hidden behind the sync strip.

**Item 5 (home empty-plan text cut at 320 dp): not a clipping defect.** The
home ScrollView ends above the navigation (`bounds` to y 1803 at 393 dp);
the empty-plan text and the "Мои объекты" button below it sit past that
edge and are reached by scrolling (`uiautomator` reports the view as
scrollable; a slow drag moved "План на сегодня" from y 1207 to 550 and
exposed the button, `artifacts/screens/phone-2026-10-15-37-home-scrolled-393.png`).
Fast synthetic `adb input swipe` gestures (400-900 ms) did not move this
tab while the Objects tab scrolled with a 600 ms swipe; a 1.5 s drag did.
Treated as a synthetic-input artefact, not reproduced with a finger.
Premium follow-up to consider (not changed): a soft bottom fade on the
scroll edge above the navigation so cut text reads as "more below"
instead of a hard crop. Needs a design decision; no change made.

## Update 16:30 — scroll-edge fade (item 5 follow-up) implemented

Owner asked to continue in order, so the premium follow-up was built: the
bottom navigation now draws a 28 dp, touch-transparent gradient
(transparent -> background) over the last rows of the screen's scroll view
(`testID="nav-scroll-fade"`, `pointerEvents="none"`, positioned above the
bar). No scroll view, padding or clearance changed; every screen that
renders the bar gets it. Unit test checks position, height, pointer
transparency and the transparent start colour. Device: at 393 dp the
empty-plan line near the edge softly dims; at 320 dp the wrapped second
line "работ" fades out instead of a hard crop
(`artifacts/screens/phone-2026-10-15-38-home-fade-393.png`,
`-39-home-fade-320.png`). Quality gate: 822 tests / 64 files, exit 0.
Mobile commit: "feat(nav): soft fade over the scroll edge above the bottom bar".

## Update 16:56 — legacy blocked queue item resolved

Owner asked for the next logical step. Findings first: the retry option
recommended earlier is not available by design. Blocked events are only
retryable when the block came from the automatic retry limit
(`canRetrySyncEvent` / `isAutoRetryLimit`); an assignment conflict is
terminal, and the server already holds the final answer for that
client_event_id (`1790880635522-ezs7bt1akt`, DOOR_SET_STATUS, applied
2026-10-01 18:53 UTC with `CONFLICT_ASSIGNMENT_CHANGED`). Pressing
"Синхронизировать" on the queue screen at 16:50 confirmed it: the item
stayed "Заблокировано · Попытки: 1" and the server received no new event.
This is the duplicate-earning / conflict protection working as specified.

Action taken: the stale item was discarded on the phone through the app's
own confirmation dialog ("Удалить действие из очереди?"). Local-only
change; no server data touched. Evidence:
- queue before: 1 block (`artifacts/screens/phone-2026-10-15-40-queue-before-retry.png`),
  dialog (`-42-queue-discard-dialog.png`), after: "Очередь пуста", strip
  "Синхронизировано 16:52" (`-43-queue-after-discard.png`);
- server after: 0 new sync_events for A-1 since 13:40 UTC, door `B-2-201`
  still NOT_INSTALLED / A-1, 0 completed_work rows for it;
- door sheet opened by deep link
  `dimax-installer://project/<id>?doorId=<B-2-201>`: both status buttons
  `enabled="true"`, no "1 в очереди" / "Работа требует проверки" notes
  (`-44-door-b2201-unblocked.png`). The door is ready for a real
  installation test by the owner.

Observed while doing this: synthetic upward `adb input swipe` drags did not
scroll the project screen back up (downward drags and taps work), so the
sheet was reached by deep link instead; finger scrolling is unaffected.
