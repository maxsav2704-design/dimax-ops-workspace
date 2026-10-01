# Native offline add-on and exactly-once payroll: PASS

Follow-up to `2026-10-01-native-issue-lifecycle.md`. This checkpoint concerns
fractional additional work, replay after lost ACK and its earnings, not a full
production release or admin-browser acceptance.

## Scope and baseline

- Company: DIMAX Acceptance A, `d1861479-addc-5655-b5c4-f86456bb04d8`.
- Project: `6423143b-4122-4685-8f8f-20fe848bc8b7`, the nine-door acceptance project.
- Phone: `a269dc99`, `com.dimax.operations.installer`, Test Installer A-1.
- A-1 installer: `4e946dc5-e084-57ac-a298-f9d74238df30`.
- A-2 installer: `6971ffa7-3f62-5063-a87d-0acce1a4b437`.
- Add-on type: `1ffa543e-a393-5f39-8d9c-31eb9593b409`, Test adjustment.
- Only isolated API 8001 / `dimax_acceptance` were used for the phone scenario.
  Automated fixtures used the separate `dimax_acceptance_tests` database.

Before the physical action, this project/type had no facts. An exact-scope guard
checked APP_ENV, database, company, plan absence and the 1250/250 ILS installer
balances, then used AddonsAdminApiService.set_plan and the existing unit of work
to create a 2.00-unit test plan: installer rate 9.00, client price 20.00.
This setup is not claimed as an authenticated office-browser interaction.

No phone database, queue, token or timestamp was edited; no fact or accrual was
manufactured. The normal API/database, real customer work and external delivery
were not modified. User input was required because injected USB taps do not work
on this phone; security settings were not weakened.

## Fixed defects

1. Offline sync bypassed HTTP-only quantity validation, allowing extra precision
   or failing at the database for nonfinite/oversized values. Direct and offline
   paths now share finite, positive Numeric(12,2) validation in the use case.
2. A positive rate could produce a sub-cent or overflowing accrual. Explicit
   half-up cent rounding and bounds validation reject the whole transaction,
   leaving neither an orphan fact nor a partial financial record.
3. Reusing a direct event key for different work falsely succeeded. Identical
   retries remain idempotent; different project/installer/type/quantity/comment
   or supplied completion time now conflicts. Blank/oversized keys are rejected.
4. Plan reconciliation and fact creation did not share a serialization lock.
   Both now lock the project within the existing unit of work, retaining unique
   fact/original-ledger constraints and immutable historical rate snapshots.
5. Closed issue history caused a false floor/door warning. The native project's
   active issue set now excludes CLOSED records without deleting history.
6. Native response inspection found type-level quantities truncated to integers:
   0.25 became 0, and 1.50 + 0.25 became 1. Decimal aggregation now retains the
   fraction. JSON quantity remains numeric; jobs_count remains a row count.

Zero/missing installer prices retain the existing late-plan reconciliation flow.
No migration is required; the schema remains at 0062. The stricter direct HTTP
409 on conflicting key reuse is intentional, not a removed feature.

## Physical sequence

1. Removed only API reverse mapping 8001, retaining Metro 8081. The user physically
   saved quantity `1,50` once in the project's additional-work form.
2. A stopped-app SQLite export proved durable event
   `1790885582942-7es373fzfv`, ADDON_FACT_CREATE, quantity `1.50`, happened_at
   `2026-10-01T20:13:02.942Z`, FAILED / Network request failed / attempts 1.
   Exactly one optimistic OFFLINE fact existed. PostgreSQL had zero facts and
   zero sync events for this ID before reconnect.
3. Started the loopback-only acceptance relay on 18001, scoped to this company,
   user, project, add-on and quantity. Mapped phone 8001 to that relay and cold
   launched the queue. It forwarded the unchanged request, discarded one
   successful applied ACK and then forwarded the same event's replay ACK:
   `ack_dropped` followed by `ack_forwarded`, `applied:false`.
4. Server inspection found exactly one fact and one ORIGINAL ADDON ledger row:
   fact `26b7da03-9664-4bd7-8421-fdb7b45d0faa`, ledger
   `6e46200d-110b-40fc-b067-4b314c164f04`, quantity 1.50, rate 9.00, amount 13.50.
   There is one sync_events row. Both completion timestamps retain the physical
   event's `2026-10-01T20:13:02.942Z`, not its later delivery time.
5. Restored direct API mapping and stopped the exact relay process. A stopped-app
   export showed one server fact, no optimistic duplicate and no pending add-on.
6. Native Earnings showed current-month **263.50 ILS**, two work rows, including
   the prior 250.00 installation and the 13.50 add-on. Cached detail retained
   quantity 1.50, rate 9.00 and amount 13.50. Lifetime A-1 net is **1263.50 ILS**;
   A-2 remains **250.00 ILS**. These period and lifetime totals are not conflated.
7. A further cold launch with API mapping removed showed **263.50 ILS** and an
   explicit offline-copy label. The app did not replace cached pay with zero.
8. Native project UI showed five assigned/installed doors and zero floor issues,
   confirming the closed-issue indicator repair.
9. After the fractional summary fix, restarted only the acceptance API, verified
   host `/ready` 200/database ready and cold-launched native Earnings. It showed
   263.50 ILS / current data. Another stopped-app export confirmed the refreshed
   type summary had numeric quantity 1.50 and amount 13.50, matching its work row.
   Direct 8001 and Metro 8081 mappings were restored; the phone was left on Earnings.

## Data preservation

- All five local door rows matched the first post-sync snapshot exactly. After
  opening the project online, only their cache updated_at advanced: the existing
  project repository writes payload.server_time there. Every door business field,
  status, lock and version remained unchanged; one project only. Both previous
  control doors on the server remained A-2 / NOT_INSTALLED / unlocked, versions
  0 and 4 respectively, with no installed_at.
- The prior blocked reassignment event `1790880635522-ezs7bt1akt` matched every
  stored field before/after. It was not deleted, retried or acknowledged.
- SQLite integrity checks passed. The old account's 13 legacy tables retained
  canonical SHA256
  `bf95547abf1af9bb525949b2b5be1d73ed68c53187d15250f2cc366a16250a0c`.
- Test plan and the real phone's test fact/13.50 accrual remain as acceptance
  evidence. No external email, WhatsApp or signature was triggered.

## Verification

- Initial invalid-quantity/payroll/replay reproduction: 10 failed, 25.59 s.
- Before the final summary repair: add-ons/sync/payroll/architecture, 138 passed,
  162.03 s; mobile full quality-gate, 687 tests / 47 files passed, Vitest 34.01 s,
  plus security/discovery/config/type checks; relay 19 tests passed.
- Fractional type-summary reproduction: 2 failed, 48.23 s (0 vs 0.25, 1 vs 1.75).
- Expanded final backend regression: **190 passed**, 243.11 s, exit 0, covering
  test_addons_api, test_sync_batch_api, test_payroll_lifecycle,
  test_installer_phase2_api and tests/architecture. This replaces the earlier
  138-test run for the final backend revision; overlapping counts are not added.
- Final mobile `npm run quality-gate`: **689 tests / 47 files passed**, Vitest
  32.77 s, plus security checks, discovery, production contract, Expo config and
  TypeScript; final exit 0. This replaces the earlier 687-test mobile result.
- Final native refreshed type summary: PASS, as described above. Acceptance API
  healthy with database-ready response after restart. `git diff --check` passed.

Tests run one heavy process at a time with existing dependencies/images, Node 20,
CI/EXPO_OFFLINE for mobile, no pytest cache/bytecode, explicit isolated test DB
URLs and auto-removed test containers. No admin build, signed native build or
complete repository-wide release gate is claimed.

## Cleanup

Removed all 40 owned temporary files / 39,235,512 bytes: five stopped-app SQLite
exports and archives, screenshot, capture/relay logs. Resolved absolute scope
and parent/descendant reparse points were checked before recursive deletion.
The owned phone UI XML was removed. No APK or dependency copy was produced.
The exact temporary relay process was stopped and auto-removed test containers
are gone. Metro and the acceptance services remain available for the next step.
Existing unrelated admin next-env.d.ts/tsconfig.json changes were left untouched.

## Revisions and next step

Initial fixes: backend `1ccd4d7`, mobile `dad7ae7`, scoped relay `2fedd2b`.
Final summary fix: backend `4ae285c`; mobile contract follow-up: `f5eaeae`.
Commits remain local only; no GitHub backup/push occurred. The earlier public
remote restriction has not been cleared.

Next: native project journal, completed-work selection, test signature, PDF and
local Mailpit attachment, followed by current-revision release gates. A09 and
add-on replay have direct native evidence; this does not close all A15 report
reconciliation, external delivery or production requirements. No overall
readiness percentage is advanced from this single checkpoint.
