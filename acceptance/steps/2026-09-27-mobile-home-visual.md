# Mobile home / assigned projects visual hierarchy

## Scope

Second bounded visual block following project / floor / door improvements.
Reviewed the actual mobile home screen, project repository, navigation, existing
theme and motion components, and the supplied Lovable home reference before edits.
Preserved the dark mobile palette, blue selection, gold accents and existing bitmap.
No backend, admin, database schema, public API, payroll or assignment rules changed.
No migration, dependency, new account or business record was needed.

## Changes

- `mobile/app/projects.tsx`: compact identity and sync header, Today / Projects
  views and expandable overall progress. Removed repeated totals and the unused
  earnings request; earnings remain available in their existing section.
- Readable project cards with wrapping names/addresses, separate status/issues,
  progress, remaining work, name/address search and work/issue filters. The card
  opens its doors; Issues routes directly to the selected project's issue list.
  Waze is retained when configured and reports opening errors.
- Reused press feedback and reduced-motion-aware transitions. Existing calendar,
  sync queue and bottom navigation are preserved; no dead decorative controls added.
- Loading, unavailable data, unavailable calendar, saved plan and genuine empty
  assignments have distinct states. A failed sync retains saved projects.
- Focus and sync refreshes ignore stale responses and immediately mask data from
  a previous account. An action lock prevents duplicate same-frame sync requests.
  Normal sync is incremental; cold assignment recovery still protects unsent work.
- `mobile/src/lib/i18n.ts`: translated PLANNED, ON_HOLD and COMPLETED. Hebrew
  installed counts use an explicit out-of-total phrase, avoiding reversed fractions.
- `mobile/src/modules/projects/projects-home-screen.test.ts`: 16 actual-screen
  tests cover loading/retry, filters/reset, routes, unavailable/cached plans,
  external-action failure, duplicate sync, queue protection, return refresh,
  account isolation, stale replies, localization and Hebrew progress wording.
- `mobile/src/lib/i18n.test.ts`: three project-lifecycle translation tests.
- `mobile/preview/home*`, shared fixture adapters and Vite aliases: isolated visual
  preview of the actual screen. Test data never reaches SQLite or the API.

## Verification

- [x] Full `npm run quality-gate`: exit 0, 629 tests in 44 files; TypeScript,
  Expo configuration and security / production-configuration guards passed.
- [x] Browser: RU at 393 CSS px; EN and Hebrew RTL at 322 px. Long project names,
  addresses, status layout and the Hebrew count wording were inspected visually.
- [x] Browser controls: search empty/reset, issue filter and direct issue route,
  language switches, saved assignments after failed sync, unavailable data without
  false zeros, and a genuinely empty schedule/project list were exercised.
- [x] Document width matched the viewport at 393 and 322 px. No browser console
  errors were observed. Previous project / floor / door preview still loads.
- [x] Android Hermes export: exit 0, 1165 modules and 35 assets. This uses existing
  local configuration and is a JavaScript export, not an APK or production release.
- [x] Removed only `.tmp/home-visual-bundle` (4,978,323 bytes) after resolved-path
  and reparse-point checks. Absence verified; no other project folders removed.
- [x] Temporary viewport override reset; preview restored to RU / Online.
- [x] `git diff --check` passed. Existing admin-generated changes were untouched.
- [x] Mobile local commit `49e0777`; this acceptance note is versioned separately
  in the root repository.

Commands (configured Node 20, mobile repository):

```powershell
npm run quality-gate
npx expo export --platform android --max-workers 1 --output-dir .tmp/home-visual-bundle
git diff --check
```

## Boundaries

Preview: `http://127.0.0.1:4188/home.html`, marked HOME / TEST DATA / NO API.
The test preview does not prove real admin-to-phone synchronization or native
interaction quality. Device font scaling, reduced motion, accessibility focus,
offline gestures and performance still require physical-device acceptance.
No APK installed, phone data changed, email sent or signing flow used.
No 100% product or design acceptance is claimed. This block is saved in local Git;
no GitHub push or remote backup is claimed.
