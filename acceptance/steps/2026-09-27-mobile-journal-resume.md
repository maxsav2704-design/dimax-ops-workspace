# Mobile journal return and offline recovery

## Scope

Follow the server-side sync-to-signed-PDF acceptance with checks of the actual
mobile journal screens and their existing resource hook. Work stays inside the
journal module; no new polling service, dependency, API or migration is added.
No real document is prepared, signed or sent. No phone or external mailbox is
used. The browser fixture at port 4188 is not a connected installer application.

## Reproduced defects

The first regression run against the original implementation had 4 failures
and 24 passes in the actual-screen tests:

- An AppState return event received while link opening still held the action
  lock was dropped. The document could remain ACTIVE after signing until a later
  manual check or successful scheduled sync.
- Multiple sync-version updates received during the same action were dropped.
- A sync update could start a journal read while the app was backgrounded.
- A pre-background read could update the hidden screen before foreground
  revalidation. Its lifecycle was not invalidated by the AppState transition.

Additional UI review found that the previous "ready for signature" notice and
link-opening error could remain alongside an already signed document.

## Fix

- `mobile/src/modules/journal/use-journal-resource.ts`: queue one refresh while
  locked, drain it when the action is released, and check foreground, focus and
  account/document key before reading. Invalidate in-flight UI reads on leaving
  the foreground. A hidden screen waits until foreground/focus returns.
- `mobile/app/journal.tsx` and `mobile/app/journal/[id].tsx`: release actions
  through that hook so return/sync events are not silently discarded.
- Document notices/errors are bound to the status they describe. Obsolete
  signing-link guidance is hidden after the server confirms ARCHIVED.
- Existing workspace guards, cached read-only behavior and manual refresh stay
  intact. The provider's existing successful-sync notification handles online
  recovery; this change does not introduce another timer or repeat any write.

## Added coverage

Thirteen actual-screen regressions cover deferred return, event coalescing,
foreground-only reads, cold background mount, stale background replies, offline
return, account switch, route blur, access revocation, obsolete guidance, PDF
return with failed email, and project-list filter/delivery reconciliation.

One service regression checks ACTIVE online -> ACTIVE cached while offline ->
ARCHIVED/PENDING online -> ARCHIVED/PENDING cached -> DELIVERED online, using the
real service with controlled API/cache boundaries. Every request remains a read;
there is no extra preparation, signature, delivery request or PDF launch.

These tests use React Test Renderer, mocked native primitives/AppState and
controlled services. The service test uses a memory cache, not native SQLite.
They do not establish real OS lifecycle, browser, SQLite or network acceptance.

## Verification

- Journal-focused tests after fixes: **81 passed in 6 files**.
- Full mobile tests: **604 passed in 43 files**, including all 14 new tests.
- Full `npm run quality-gate`: exit 0, including test discovery, TypeScript,
  Expo configuration, image-size / fast-uri guards and production configuration
  contracts. The 604 tests include the 81 journal tests, not an additional total.
- Android Hermes export: exit 0, 1165 modules, 35 assets. This is a JavaScript
  export using the existing local configuration, not an APK or production build.
- Removed only `.tmp/journal-resume-bundle` after resolving its absolute path
  and rejecting reparse points. Removed 4,970,138 bytes; directory absence was
  verified. No permanent export, PDF or screenshot was added.
- Mobile local commit: `de00596`. Diff checks pass. No backend changes; the
  preexisting admin `next-env.d.ts` / `tsconfig.json` differences are untouched.

Commands use the configured Node 20 runtime from the mobile repository:

```powershell
npm run quality-gate
npx expo export --platform android --max-workers 1 --output-dir .tmp/journal-resume-bundle
```

## Remaining acceptance

On an isolated test account, the physical device still needs the complete path:
open signing page, sign the synthetic act, return to the application while email
is pending, verify later delivery, repeat with network interruption, and check
the project list and signed PDF. No real customer work or signature is authorized
by the automated fixture. No physical-device or actual email success is claimed.

Production readiness percentages and frozen release criteria are unchanged.
Local Git only; no GitHub push or remote backup is claimed.
