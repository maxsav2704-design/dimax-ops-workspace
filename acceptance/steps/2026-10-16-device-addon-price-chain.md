# Physical device addon price acceptance

## Scope and result

PASS for the previously retained phone addon through separate factory approval,
explicit administrator accrual, actual mobile ACK, canonical earnings and offline
reading after a cold start. This follows `2026-10-16-device-work-price-chain.md`;
it is not acceptance of the complete release or public production infrastructure.

The existing Android debug app used mobile commit
938e4103a912c75be43aac6733cea1d5099dc707. The isolated API uses database revision
0074 and backend HEAD 159564c1157c89ce1baeb4c54cad0f5f7aefcf5f, with unrelated local
AI edits in the bind mount. This is not proof of an immutable release image.
Only the synthetic Device Price Acceptance company and local Mailpit were used.

## Actual phone work and financial evidence

1. The original phone-created ADDON_FACT_CREATE, event
   `1792100131910-xojfp1u0ys`, was still blocked with CONFLICT_FACTORY_PRICE.
   Its Runtime adjustment quantity was 1, not 1.5. The scenario did not create,
   replay, rewrite or delete an installer command. Initial SQLite earnings were
   9.01 ILS for the previously accepted door; the addon had earned nothing.
2. After normal sign-out from A-1, development-only login restored Device Test
   Installer through ordinary authentication. Its existing scoped database was
   reused. The other company's database and empty queue were preserved.
3. The administrator proposed 9.01 ILS per unit for this exact retained work.
   The OWNER-approved test factory contact received an invitation and separate
   confirmation code through the SMTP worker and Mailpit. The public preview
   bound the proposal, quantity, amount and original execution time.
4. After confirmation, the server ledger still held only the old door earning.
   The actual phone showed 9.01 ILS and one blocked event; refreshed SQLite
   agreed. Factory approval did not acknowledge work or create earnings.
5. Installer attempts to propose a price or accrue returned 403. An administrator
   accrual body with a replacement rate returned 422. Explicit admin accrual
   created one addon earning for 9.01 ILS. An identical request returned the same
   receipt; a new request ID for the already accrued approval returned 409.
6. Read-only resolution checks twice returned the resolved ACK without replaying
   the work. The active company price-list ID and its one item stayed unchanged.
   The original door ledger snapshot was unchanged. SQL showed exactly two
   ORIGINAL earnings, 9.01 each, and no apply errors on the two original events.
7. The app cold-started with automatic login disabled. Actual sync removed the
   addon from the phone queue. SQLite integrity was ok, the queue was empty,
   and only the assigned synthetic project and installed RUNTIME-101 remained.
   The addon fact appeared once, quantity 1.00, source OFFLINE, with its original
   execution time `2026-10-15T21:35:31.910000+00:00`.
8. After earnings refresh, both phone SQLite and the visible earnings screen
   showed 18.02 ILS, two work rows and one project. The early post-start snapshot
   still held 9.01 before refresh completed; it was not counted as a passing
   earnings result. The updated month/today snapshot was 18.02 at 16:12:39 UTC.
9. Only the phone's API USB reverse mapping was removed; Metro remained available.
   Another cold start and earnings navigation showed 18.02 with the offline-copy
   label and an explicit stale-data notice. This verifies cached earnings when
   the API is unreachable, not an APK launch without a development server.
   The API mapping was restored afterward. Repeated sync left two earnings
   totaling 18.02, without a duplicate addon.

## Acceptance tooling and tests

`acceptance/device_addon_price.py` adds guarded observe/review/accrue/verify stages
for this existing synthetic event. Request IDs and evidence are saved privately
before writes so a lost response can be retried without substituting new terms.
The helper refuses changed ownership, quantity, price context, execution evidence,
previous earnings or unexpected ledger rows. HTTP probes are explicitly not
labelled as physical phone proof.

The first accrual invocation hit the existing 5-logins-per-900-seconds limit before
submitting any accrual. Its retained stage was checked, the full applicable window
was respected, and a single retry succeeded. No rate limiter was disabled or reset.
The observation stage no longer performs an unnecessary installer login. Subsequent
manual stage invocations still need to respect the API's normal login limits.

Fourteen unit tests pass locally, including nine addon guards and five existing
door-fixture guards. They also pass on Python 3.11 in
[GitHub Actions](https://github.com/maxsav2704-design/dimax-ops-workspace/actions/runs/38929208791)
for backup commit `10e83f09f6343da036ff16c4757666ab7db7664f`.
The new workflow has no services, credentials or business-data artifacts.

The existing mobile tests for earnings service, sync service, session isolation
and cold resync also pass: 4 files, 114 tests, using the project's Node 20 runtime
and Vitest with one worker. The first sandboxed invocation failed before test
execution because Vitest could not rename its temporary cache (EPERM); the same
command passed outside that filesystem sandbox. No product/test assertion was
changed to obtain a pass. This is a focused run, not the full mobile quality gate.

## Handoff and limits

The user normally signed out of Device Test Installer. A-1 was restored through
ordinary authentication, then development auto-login was disabled and the normal
bundle cold-started successfully. The phone showed Test Installer A-1 and seven
assigned doors. Both SQLite databases passed integrity checks and had empty
queues. A-1 had only its original Excel acceptance project; the separate synthetic
database retained its own project, addon and 18.02 earnings. No company data mixed.

All containers were already stopped at this session's beginning. Only the five
needed acceptance containers were started; MinIO was not started. Those five
were stopped again, not removed, and the session-owned Metro process tree was
stopped. Final checks showed no running Docker containers and no 8081 listener.
Only this run's temporary phone XML/screenshots, local transient screenshot and
Metro logs were removed. No APKs, bundles or mobile database copies were retained.
The phone remains on A-1 with its offline cache; API 8001 is stopped. Do not
silently repoint that test identity to the different ordinary database.

Private fixture data and the inspected 234573-byte phone screenshot are ignored
Git files under `artifacts/device/price-chain`. Temporary SQLite/WAL copies were
read-only and automatically removed. No mobile DB, auth token or queue was edited;
no APK, volume, password, device security setting or business API was replaced.

Public domain/HTTPS and external SMTP delivery, release-APK acceptance, the
working-volume MinIO backup/upgrade/restore and the full release matrix remain
separate gates. Russian count wording on the earnings screen remains a cosmetic
follow-up. This financial test does not claim to fix that wording or certify
performance on the memory-constrained development computer.
