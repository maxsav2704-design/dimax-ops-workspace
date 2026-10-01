# Mobile issues: visual hierarchy and reporting workflow

## Scope

Bounded next step after the home and project/floor/door improvements. Inspected
the current issue screen, repository, route helpers, durable issue-create service,
shared theme/motion and the supplied Lovable issue list/detail reference.
Kept the existing mobile brand, reporting categories and three-step workflow.
No backend/admin/database/API/payroll rules or dependencies changed; no migration.

## Changes

- `mobile/app/issues.tsx`: compact heading and project-scoped counts; search;
  readable cards with full title, project and door labels. A scrollable detail
  dialog exposes the full description and exact linked-door action.
- Reporting opens in a scrollable dialog; closing retains the in-memory draft.
  Existing press feedback and reduced-motion-aware transitions are reused.
  No fake severity, timestamps, author, discussion or installer resolution action.
- Loading/read failure do not masquerade as no issues. Focus, background sync and
  app resume reload state. Stale replies cannot overwrite a newer screen load.
  Account and route changes remount the workspace and mask its previous data.
- Same-frame save lock prevents duplicates. Close/back/edit controls are disabled
  during the durable write. Assignment removal disables saving. A successful local
  save closes the composer even if subsequent sync/read fails; its acknowledgement
  does not claim server delivery and follows language changes.
- Kept `queueIssueCreateEvent` and its SQLite transaction unchanged. Reporting
  neither completes a door nor creates earnings. Removed misleading photo-help
  copy from a form that has no attachment control; no photo requirement was added.
- `mobile/src/modules/projects/navigation.ts` and `mobile/app/project/[id].tsx`:
  exact `doorId` link, missing-door warning without automatic substitution, and
  preservation of subsequent manual selection across refresh.
- Tests: 22 actual issue-screen tests, three linked-door screen tests and one
  encoded-navigation test. Native test hosts now include KeyboardAvoidingView.
- `mobile/preview/issues*` and repository/sync fixture adapters: memory-only
  preview with open/closed/local records, saved/failure/empty/read-error scenarios.

## Verification

- [x] Full `npm run quality-gate`: exit 0, 655 tests in 45 files, TypeScript,
  Expo config, security patches and production-configuration contracts passed.
- [x] Browser: RU list/details/review at 393 CSS px; HE RTL detail and EN empty
  state at 322 px. Long identity/description text remained readable without
  overlap or document-width overflow.
- [x] Isolated reporting flow saved one new issue and added exactly one queue
  entry despite an offline sync failure; the modal closed and controls recovered.
- [x] Read failure differed from a genuine empty list. Detail modal closed and
  an exact door link selected A-2-202 in the actual project-screen preview.
- [x] Fixed an initial preview import error. No later console errors observed.
- [x] Viewport override reset; fixture scenario restored to Online / RU. The
  extra linked-door verification tab was closed; existing preview server retained.
- [x] `git diff --check` passed; pre-existing admin-generated changes untouched.
- [x] Android Hermes export: exit 0, 1165 modules, 35 assets. Existing local
  config only; not an APK or production build. Removed `.tmp/issues-visual-bundle`
  (4,990,061 bytes) after path/reparse checks and verified its absence.
- [x] Resumed October 1: 50 focused tests passed again; mobile local commit
  `212fffa`. The prior approval-limit interruption did not change source files.
  This acceptance note is committed separately in the root repository.

Commands (configured Node 20, mobile repository):

```powershell
npm run quality-gate
npx expo export --platform android --max-workers 1 --output-dir .tmp/issues-visual-bundle
git diff --check
```

## Boundaries

Preview: `http://127.0.0.1:4188/issues.html`, marked TEST DATA / NO API.
Browser fixtures and native-host tests do not prove physical-device accessibility,
keyboard/gesture behavior, real SQLite durability or admin-to-phone synchronization.
No APK installation, real work entry, email, signature or payroll action performed.
Device acceptance remains required. No 100% release/design readiness is claimed.
Changes are local Git only; no GitHub push or remote backup is claimed.
