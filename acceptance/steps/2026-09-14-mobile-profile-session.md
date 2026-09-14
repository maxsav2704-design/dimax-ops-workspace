# Mobile profile/session isolation: September 14, 2026

## Decision and scope

Mobile commit: `c47ddb9`. Continue account-bound mobile acceptance after
`1e20ebb`, without reconnecting the phone's old pending installation to an API.
This is a source-level authentication correction, not complete native acceptance.
Criteria/weights are unchanged; no release percentage or production approval is
advanced. Backend, admin, migrations, payroll and project data are unchanged.

## Findings

P1, account-profile isolation: `AppProviders.tsx` wrote refreshed profiles directly
through `persistStoredUser`, outside the auth storage mutation queue. It also
duplicated the profile write already performed by `login`. A delayed write could
outlive a session transition. The offline bootstrap guard checked the company,
active flag and role but not the email: inconsistent profile/session records for
two installers of the same company could select the wrong local workspace.

A separate deterministic regression reproduced the completion-order gap in the
existing auth mutation queue. Hold the profile storage write in a login, start
logout, then release that write. Before the patch the login returned its old user
instead of `SessionChangedError` (1 FAIL, 19 skipped, exit 1). This test did not
access a real device, production authentication or SQLite data.

## Changes

- `src/lib/api.ts`: the existing serialized auth storage queue checks the login
  generation again after its operation completes. New `persistAuthenticatedUser`
  uses that queue, checks generation before/after the session read, and requires
  matching company/email before writing a refreshed profile. Token rotation for
  the same session is allowed. No network call is held inside this storage queue.
- `src/providers/AppProviders.tsx`: capture the auth generation before the refresh
  flow, use guarded profile persistence, check the UI auth epoch before selecting
  SQLite, and remove the duplicate post-login profile write. Ignore a stale
  bootstrap result before evaluating its cached identity.
- `src/modules/auth/session.ts`: centralize the offline cached-installer check,
  adding normalized email equality and a nonempty user ID. Existing active-role
  and company checks remain. A mismatched cache follows the existing login-required
  path; it does not delete account databases or their outbox events.
- `src/lib/api.test.ts`: reproduce late login completion after logout.
- `src/lib/auth-profile-isolation.test.ts`: 11 cases covering storage serialization,
  stale generations, missing/mismatched identity, delayed reads/writes, new login,
  storage failure/retry, same-account reentry and same-session token rotation.
- `src/modules/auth/session.test.ts`: 10 offline identity cases, including two
  installers in one company, normalization, missing fields, inactive/wrong roles.

No new dependency, database schema, HTTP contract, work status or UI design.
The existing offline queues remain account-owned; successful authentication is
not treated as evidence that their work has been delivered.

## Verification

Commands ran serially from `mobile`, using existing Node 20.19.5 dependencies.

| Check | Result |
| --- | --- |
| Targeted auth/API tests | 31 PASS, 2 files, exit 0, 8.54 seconds |
| Full `vitest run --maxWorkers=1` | 376 PASS, 31 files, exit 0, 43.24 seconds |
| `tsc --noEmit` after all edits | PASS, exit 0 |
| `node scripts/validate-test-discovery.mjs` | PASS, 31 files, exit 0 |
| `git diff --check` | PASS, exit 0 |

Twenty-two tests were added relative to the previous 354-test checkpoint. These
are deterministic API/storage-adapter and pure identity tests, not rendered React
provider tests or physical SecureStore fault injection. The complete provider
bootstrap/invalidation/error lifecycle still needs review and native acceptance.
Backend/admin release gates were not rerun for this mobile-only change.

## Phone follow-up

- Authorized phone `a269dc99` was present after reconnect (transport 3). The ADB
  reverse list was initially empty. Restored only `tcp:8081 -> tcp:8081` for Metro;
  its `/status` endpoint returned `packager-status:running`.
- The app's API remained the isolated loopback `http://127.0.0.1:18082` from the
  earlier bundle, with automatic login disabled. No API reverse tunnel was added.
- A fresh ADB tap after tunnel restoration still did not visibly open the profile.
  Android's shell package reports `INJECT_EVENTS: granted=true`; that alone does
  not prove injected touches reached the app. No cause was established and no
  Android security setting was changed. A direct package check-permission command
  was unsupported; the permission evidence comes from the package dump instead.
- The registered `dimax-installer://profile` deep link opened the existing app.
  UI inspection again showed "Мой профиль" and "Ожидают действий: 1". This was
  the previously loaded bundle, not native evidence for commit `c47ddb9`.
- No work-action, retry, sync or sign-out confirmation was activated; no app data,
  credentials or account database was deliberately cleared. The visible count is
  not a byte-for-byte comparison of queue/cache or runtime retry metadata.
- Touch/scroll response, confirmation/cancellation, real account switching and
  reconnect/ACK with one accrual per event remain NOT VERIFIED. Do not send the
  existing event for a deleted smoke fixture to manufacture a successful result.

## Cleanup and next step

Removed `/data/local/tmp/dimax-touch-check.xml` and verified its absence. No new
APK, screenshot, copied database or exported JavaScript bundle was created.
The existing Metro process/log pair remains available; no unrelated service was
stopped. The code and this report are local commits, not a GitHub backup. The
previous public-destination publication restriction remains in effect.

Next: finish the remaining auth-provider invalidation/error-path audit, then
establish a verifiable native input path and exercise the updated source with a
recoverable test account. Preserve the old pending event and do not substitute
unit tests or deep-link navigation for native offline/account-switch acceptance.
