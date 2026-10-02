# Company-wide factory price-list drafts

## Scope

This bounded step implements versioned backend drafts, not factory confirmation,
price activation or mobile rollout. The agreed workflow remains: factory offers
prices, an authorized admin records them, the factory representative explicitly
confirms the exact version through a personal link, then installers see approved
read-only rates and server-calculated earnings. Amendments require a new confirmed
version; existing earned amounts must remain unchanged.

No historical price has been labelled approved. Existing per-installer door rates
and project add-on plans are unchanged and still feed the legacy payroll paths.
The new requirement remains a production blocker until the remaining flow is
implemented and verified. There is no public confirmation endpoint in this step.

## Implementation

- `0063_factory_price_lists`: company-scoped version headers and door/add-on line
  snapshots, numeric/subject/status constraints, tenant-parent foreign key,
  catalog references and version/request uniqueness. No backfill or legacy-table
  modification. Downgrade refuses to discard nonempty price-list history.
- `/api/v1/admin/price-lists`: paginated summaries, detail, draft creation and
  cancellation with a reason. No PATCH/DELETE, confirmation or activation route.
- Creation requires `request_id`, `expected_latest_version`, change reason,
  agreement reference and 1-500 unique work types with positive two-decimal ILS
  installer prices. Company, approval and display labels cannot come from input.
  Names and units are copied from active catalog entries owned by the company.
- The company row lock serializes version allocation. Same request ID and same
  normalized input return the original version, even after cancellation or a
  catalog rename. A different payload with the same ID conflicts. A stale base
  version conflicts rather than overwriting a concurrent change.
- OWNER/OPERATIONS can write with rate access; FINANCE can read with rate access;
  VIEWER and INSTALLER cannot access this draft API. Another company's existing
  version cannot be read or cancelled. Factory/public access is not implemented.
- Audit and data commit together through the existing unit of work. An audit
  failure rolls back the price-list write, not only the log.
- Module structure extends the existing rates module with API/application layers,
  a repository and real/test UOW wiring. No new framework or dependency.

## Verification

The guarded disposable-database smoke passed: empty -> 0062 -> 0063 -> 0062 ->
0063; all legacy rows including a seeded completed-work entry unchanged; new
tables empty after upgrade; ORM/migration metadata agree; destructive downgrade
after a recorded draft is rejected and the draft remains.

An initial focused run had 139 passes and one failing test helper, which ordered
`sync_change_log` by a nonexistent `id`. The comparison now orders by the row's
canonical JSON. This initial run is not the final regression result.

The expanded regression then had 218 passes and one test-expectation failure in
300.97 seconds: the audit-failure test expected an uncaught exception, whereas
the application's existing middleware returns HTTP 500. The test now checks that
response and verifies the whole write/cancellation was rolled back. No production
code change was needed for either test-helper correction.

Final price-list run: **49 passed**, 76.73 seconds, exit 0. The expanded run's other
170 tests (add-ons, administrative access, batch sync, payroll lifecycle, OpenAPI,
architecture) passed against the same application code. Thus 219 distinct selected
cases have passing evidence across the two runs; this is NOT a claim of one clean
219-test invocation or the full backend release gate.

The final guarded migration smoke was repeated after adding an exclusive lock
before the downgrade's history check, preventing an insert between that check and
table removal. It passed with exit 0. Both isolated databases,
`dimax_acceptance_tests` and `dimax_acceptance`, upgraded to 0063. The ordinary
backend/database were not restarted or migrated.

Acceptance A inventory: four current door rates across two door types, with zero
types having different prices between installers; one add-on plan with a positive
installer price. This is test data, not factory approval and not evidence that
prices in every company agree. No draft or approved price was seeded into the
acceptance company.

Before/after acceptance checksums and row counts matched exactly:

| Table | Rows | MD5 of ordered JSON rows |
| --- | ---: | --- |
| completed_work | 11 | d972af6ed54536ef21a9d1abc9f1ec2c |
| installer_rates | 8 | 7ffab959007f5746bb9cc74f13fac706 |
| doors | 9 | 23ddc04087c8a06023ce96bc52cb92dc |
| project_addon_plans | 1 | 05d1630d4faf1ed8e44fb61f1ec698b0 |
| project_addon_facts | 1 | ffad0b2f2f4243935a4c215c69d175bc |

Temporary migration database removed; test containers use `--rm`, pytest cache and
Python bytecode generation disabled. No dependency install, APK, screenshot, export
or new dependency tree. Existing unrelated admin `next-env.d.ts` / `tsconfig.json`
changes preserved; mobile source unchanged. No native workflow or admin/mobile
build is claimed for this backend-only step.

Backend commit: `709ba08`, local only. No GitHub push or remote backup was made.
Factory approval, price activation and full production acceptance remain open.

Only the acceptance API was restarted. Host `/ready` returned HTTP 200 with the
database ready, Docker reports the API healthy, and the new admin price-list route
returns 401 without a token. Acceptance has zero price-list headers/lines after
upgrade. No one-off test containers remain.

## Next Step

Build the factory-representative invitation and confirmation lifecycle on these
immutable versions: bounded expiring/revocable hashed-token capabilities, exact
version preview, explicit POST confirmation, concurrency/replay protection and
recipient/decision history. Use isolated delivery only. Activation, reconciliation
of legacy differences, admin/public screens and mobile read-only sync follow.
