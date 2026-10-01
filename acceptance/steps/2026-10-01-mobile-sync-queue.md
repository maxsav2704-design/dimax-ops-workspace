# Mobile sync queue: readable work and guarded recovery

## Scope

Continued after the issue workflow, closed locally as mobile `212fffa` and root
acceptance `49e4016`. Inspected the queue screen, DB account-context serialization,
sync service, queue presentation/policy, repository, shared theme/motion and the
supplied Lovable sync reference. Borrowed its hierarchy, not its mock state switch,
photos or checklist. No backend, admin, migrations or payroll changes needed.

## Changes

- `mobile/app/sync-queue.tsx`: compact heading; readable four counters, full work
  labels and project names; local door/add-on labels replace raw UUID titles.
  Technical IDs/error strings are expandable, not lost. Retry facts are labelled.
- Exact linked-work navigation uses assigned local doors; no fallback to another
  door. Add-on actions link to their existing assigned project.
- Reused press feedback and reduced-motion-aware card reveals. No invented online
  status or claim that locally stored work was accepted by the server.
- One synchronous lock for all screen mutation buttons, including same-frame
  calls. Refresh/mutation controls disable during active mutation.
- Local retry/discard operations capture and verify the current DB owner, and
  re-read event eligibility before writing. Bulk retry considers only originally
  selected IDs that are still blocked and retryable. Network I/O never holds the
  DB activation queue. Existing service transaction/conflict logic is unchanged.
- Discard confirmation identifies project/work; cannot dismiss or repeat while
  pending. A changed policy prevents deletion; acknowledged events are ignored.
- Account changes remount the workspace; stale reads cannot replace a newer load.
  Screen focus, sync-version changes and app resume refresh it. Delayed writes
  cannot start network sync under another account.
- Empty queue still permits sync to receive admin updates. Loading/read failure
  are distinct from a successful empty queue; failed network requests keep work.
- `presentation.ts`: optional display labels preserve existing callers; corrected
  assignment-conflict advice that previously suggested a prohibited retry.
- 20 real-screen regression tests and a memory-only preview with no API/SQLite.

## Verified

- [x] `npm run quality-gate`: exit 0. 675 tests / 46 files, TypeScript,
  Expo config, security patch tests and production-configuration contracts.
- [x] Browser RU at 393 CSS px; EN and HE RTL at 322 px. No document-width
  overflow; long door labels wrap, controls and confirmation remain readable.
- [x] Confirmation/cancel without deleting real or fixture work; technical detail
  expansion; exact destination `/project/preview-project?doorId=door-202&doorStatus=ALL`.
- [x] Offline fixture preserves all three rows and unlocks controls; failed read
  disables sync without showing a successful empty state. Empty queue permits pull.
- [x] Fixed initial preview reset-function typo; no subsequent console errors.
- [x] Viewport reset and fixture restored to Mixed / RU. Preview uses existing
  loopback port 4188 (was stopped, restarted as a hidden local process).
- [x] Android Hermes export: exit 0, 1165 modules, 35 assets. Local JS export,
  not an APK or production deployment.
- [x] Removed exact `.tmp/sync-queue-visual-bundle` (4,995,435 bytes) after
  resolved-path and reparse checks; verified absence. No project data removed.
- [x] Mobile local commit `6707b71`; `git diff --check` passed. This acceptance
  note is recorded separately in the root repository. No GitHub push.

Commands use the configured Node 20 runtime in the mobile repository:

```powershell
npm run quality-gate
npx expo export --platform android --max-workers 1 --output-dir .tmp/sync-queue-visual-bundle
git diff --check
```

## Boundaries

Preview: `http://127.0.0.1:4188/sync-queue.html` (TEST DATA / NO API).
No phone/APK test, admin-to-phone live reconciliation, real discard, email or
payroll operation. Screen tests do not prove native SQLite durability or all
background-sync races. Native accessibility, font scaling, gestures and actual
offline/reconnect acceptance remain necessary. No full-product percentage or
100% release readiness is claimed. Local Git only; no push or remote backup.
