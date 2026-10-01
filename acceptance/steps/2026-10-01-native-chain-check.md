# Connected-phone workflow check

## Scope and isolation

Phone `a269dc99`, package `com.dimax.operations.installer`, existing APK 0.1.0
(last installed 2026-08-28). No APK install, data clear, SecureStore export,
password reset, Android security change or direct work insertion.

Only DIMAX Acceptance A and Test Installer A-1 are in scope. Acceptance API is
port 8001; normal API/database on port 8000 remain separate. Existing acceptance
containers were started without recreating volumes. Both acceptance databases
are on migration `0061_journal_pdf_locale`. Automated writes used only
`dimax_acceptance_tests`, real acceptance MinIO and local Mailpit. No external
email/WhatsApp delivery or production deployment.

## Findings and fixes

1. **High: cold deep links mounted before account database activation.**
   Reproduced on the phone without API access: opening the project from a cold
   start left an empty screen with `Local database is not activated for an
   authenticated user`. The auth overlay hid initial work, but did not stop
   route effects from running. `AppProviders.tsx` now mounts route children only
   after initial session/database bootstrap. Later loading states retain mounted
   screens. Four provider tests cover delayed activation, invalid identity,
   storage failure and an offline refresh without remounting.
2. **Medium: exact-door links did not reveal the selected card.** The ID selected
   the right door but left the user at the top of a long project. The project
   screen now scrolls to that card once, respecting reduced motion and guarding
   late measurements against navigation. Ordinary visits, missing doors, manual
   selection and later sync do not trigger a new jump. Four regression tests.

No API, sync payload, pricing, payroll, migrations or existing functionality was
removed or changed. Mobile local commit: `f3ce4b0`.

## Verified

- Mobile quality gate before the bootstrap fix: exit 0, 679 tests / 46 files,
  security/configuration contracts, Expo config and TypeScript.
- Final code: **683 tests / 47 files**, full Vitest run, exit 0 (38.04 s).
  Final `tsc --noEmit`, test-discovery contract and `git diff --check` pass.
- Journal real-service acceptance: **2 passed**, 38.90 s. Includes installer
  work -> journal -> ready/sign -> PDF -> local email, correct recipients and
  attachment, replay without duplicate mail/accrual, access restrictions.
- Selected server workflow regressions: **36 passed, 96 deselected**, 141.43 s.
  Covers offline event time/rate, lost-response replay, reused IDs, issues,
  cold sync, assignments, foreign-door rejection, add-on earnings, reassignment
  without accrual, financial isolation and assigned-only calendar visibility.
- Phone: cached A-1 identity/profile, assigned project and five doors match the
  acceptance database. Cold offline deep-link reproduction passes after the fix:
  the exact B-1-101 card and action buttons are visible; no bootstrap error.
  Native screenshot inspected, not merely the browser preview.
- Current app-scoped Android/React Native error log has no error entries in
  the inspected 300-line window. This is not an exhaustive crash guarantee.

Commands used the existing Node 20 runtime and project Vitest/TypeScript tools.
Backend checks used `docker compose -f docker-compose.acceptance.yml run --rm
--no-deps -T ... api timeout ... python -m pytest -q -p no:cacheprovider`, with
both database URLs explicitly targeting `dimax_acceptance_tests` and external
pytest plugins disabled. Journal opt-in flag: `DIMAX_JOURNAL_MAILPIT=1`.

## Data reconciliation

SQLite snapshots were copied only with DIMAX stopped. Both integrity checks pass.
All **13 legacy-account tables** exactly match their baseline rows, including
the old FAILED event. Canonical legacy-table SHA256 (sorted tables/rows, JSON):
`bf95547abf1af9bb525949b2b5be1d73ed68c53187d15250f2cc366a16250a0c`.

A-1 remains one project, five doors (four installed, one not installed), zero
pending events. Target `3b4a31b4-f872-4ca1-9373-69530af2bc71`, label
`B-1-101-dira-EN-101`, remains NOT_INSTALLED/version 0 with zero completed-work
rows. Its applicable rate is 250.00 ILS from 2026-01-01. Read-only PostgreSQL
confirms net earnings unchanged: A-1 1,000.00 ILS; A-2 250.00 ILS.

## Still not verified on the phone

ADB taps at the observed Profile and Installed buttons returned success but did
not change the UI or create an event. No cause is established; security settings
were not weakened. A physical tap was requested asynchronously and had not been
confirmed at this checkpoint. Do not substitute an SQL/API-generated event and
call it a native workflow pass.

The physical offline completion -> persisted queue -> lost ACK -> replay -> one
accrual chain is **NOT VERIFIED** in this run. Native issue/add-on mutations,
calendar interactions, journal signing/PDF delivery and every-button acceptance
also remain incomplete. Server tests are evidence only at their own layer.

## Environment and cleanup

Metro initially accepted TCP but failed HTTP probes. It recovered during
diagnosis; the underlying delay was not established. The temporary HTTP probe
and debugger are removed. A clean normal Metro on 8081 subsequently answered
status and delivered the updated Android bundle; no Metro/dependency patch.

The phone is deliberately left on the selected test door **without its 8001 API
tunnel**, ready for the requested physical offline tap. USB 8081 remains for the
debug bundle. After observing the local event, arm the existing scoped sync relay
and restore the API path for delivery/replay verification. The unused relay was
stopped: no fault injection is currently armed. Do not connect this queue to 8000.

Mobile browser preview 4188 was restored and returned HTTP 200. The temporary
admin preview on 4173 started during this run was stopped to limit RAM; it is
not certified running. Existing normal backend containers were not stopped.

Removed the exact owned snapshot/probe directory after absolute-path/reparse
checks: **20 files, 10,546,526 bytes**; absence verified. The owned phone UI XML
was also removed. No APK/export directory retained. Local Git only, no GitHub
push or remote-backup claim. No full-release pass or 100% readiness claim.

## Subsequent physical confirmation

The user subsequently pressed Installed. The persisted native event, lost-ACK
replay, single 250.00 ILS accrual and phone earnings display now PASS; see
`2026-10-01-native-offline-delivery.md` for exact evidence. That follow-up also
restored the direct 8001 API tunnel. The offline environment and pending status
above describe this earlier checkpoint, not the current phone state.
