# Mobile project / floor / door visual hierarchy

## Scope

First bounded visual improvement requested after the mobile design review.
Inspected the existing project screen, shared theme, motion components, actual
screen tests and the supplied Lovable doors-explorer reference. Kept the dark
mobile palette, blue selection, gold action accents and vertical floor rail.
No backend, admin, API, SQLite, outbox or earnings rule is changed. No migration
or new dependency is needed. No feature is removed.

## Changes

- `mobile/app/project/[id].tsx`: compact project heading and progress summary;
  expand detailed statistics without permanently displacing the door list.
- Keep the open-issue count visible, disclose the existing issue list, and add
  a route to all project issues instead of limiting access to its first five.
- Search and status chips stay visible. Additional order/location filters can
  collapse without clearing selection; an active marker and reset remain.
- Retain the elevator-style floor selector; improve floor/count/stat typography.
  Move door status below the identity rather than squeezing it beside the label.
- Wrap long position labels in the list and the selected-door image. The detail
  image grows with text instead of clipping it inside a fixed-height overlay.
- Use existing press feedback and reduced-motion-aware disclosure/selection
  transitions. Floor selection is disabled during a write, like door rows.
- `mobile/src/modules/projects/project-screen.test.ts`: six added screen tests
  and a busy-floor assertion; existing installation/add-on/queue tests retained.
- `mobile/preview/project-fixtures.tsx`: richer in-memory layout fixtures only.
  The preview does not connect to auth, SQLite, the backend or a real installer.

## Verification

- [x] Initial full mobile quality gate: 610 tests in 43 files; TypeScript,
  Expo configuration and security / production-configuration guards passed.
- [x] Browser review: RU at 393 and 322 CSS px, EN and Hebrew RTL at 322 px.
  Long labels, floor selection, advanced-filter collapse, empty-search reset,
  detail/list navigation and completion-to-queue UI were exercised.
- [x] The isolated completion changed the intended door, updated counts and
  removed the repeated completion action. No real work was recorded.
- [x] No browser console errors or document-width overflow were observed.
- [x] Android Hermes export: 1165 modules, 35 assets, exit 0. This is a
  JavaScript export using existing local config, not an APK or release build.
- [x] Final quality gate after the last refinements: exit 0, 610 tests in 43
  files, TypeScript and all configuration/security guards passed again.
- [x] Removed only `.tmp/project-visual-bundle` (4,974,624 bytes) after checking
  its resolved workspace path and rejecting reparse points. Absence verified.
- [x] Temporary browser viewport override reset; fixture work reset. The
  original user tab and existing preview server were left running.
- [x] Mobile local commit `3c68a08`; final diff check passed. This acceptance
  note is versioned separately in the root repository.

Commands (configured Node 20, mobile repository):

```powershell
npm run quality-gate
npx expo export --platform android --max-workers 1 --output-dir .tmp/project-visual-bundle
git diff --check
```

## Boundaries

Preview: `http://127.0.0.1:4188/project.html`, explicitly marked TEST DATA / NO API.
Device font scaling, reduced-motion behavior, gestures, screen-reader focus and
performance still require physical-device acceptance. Native mocks and web layout
do not prove live admin-to-phone synchronization. Release-readiness percentages
are unchanged; this step does not establish 100% product or design acceptance.
Only local Git commits are intended; no GitHub push or remote backup is claimed.
