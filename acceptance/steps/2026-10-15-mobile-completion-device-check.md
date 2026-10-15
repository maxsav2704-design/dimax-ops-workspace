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
