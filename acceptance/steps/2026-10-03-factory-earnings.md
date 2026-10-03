# Factory-confirmed earnings, October 3, 2026

## Scope

This step connects the internal effective-price timeline to actual earnings.
It is not permission to activate factory pricing in the current acceptance
company, a full release certificate, or a claim of native-device verification.
The admin activation action remains unavailable until mobile supports versioned
read-only prices, execution-time evidence and explicit unresolved-price states.

## Implemented

- Door completion now resolves the price in one existing completion helper.
  Install, status, admin override and both offline protocols use this path.
  In factory mode, a saved individual rate cannot override the confirmed price.
- Additional work uses the confirmed rate and decimal quantity, even without
  a project plan. Legacy project-plan rates cannot override it. Editing a plan
  cannot retroactively accrue already uploaded unpaid facts after cutover.
- Migration 0066 adds `factory_earning_prices`: a one-to-one evidence record
  linked to the earning, list item, factory receipt and effective activation.
  It retains version, unit, currency, confirmed rate, execution/effective times,
  selection reason and snapshot hash. Composite foreign keys enforce tenant
  and list consistency. Existing financial records are not backfilled.
- Cancellation copies the original evidence and exactly offsets its amount.
  Replays do not select a new price. Arbitrary manual-rate corrections are
  rejected for companies in factory mode and for evidenced earnings.
  Legacy-company correction behavior remains available.
- The admin ledger exposes optional `factory_price` evidence and disables
  manual correction in factory mode. Existing CSV columns remain unchanged.
- Old queued work is explicitly classified only at offline ingress. It uses
  the first confirmed company list, not necessarily the first activated list.
  Direct backdating and already uploaded facts cannot claim this exception.
- Missing factory prices retain failed events/queue entries with no false
  completion or earning. Offline completion without an execution timestamp
  also remains unresolved instead of being priced at upload time.
- Batch queue execution timestamps are now persisted and returned to the
  installer/admin queue views. Old rows retain NULL; no time is invented.
- Completion, plan reconciliation, manual corrections and activation share a
  company-level lock before project/door/ledger mutations. PostgreSQL NO KEY
  UPDATE permits unrelated foreign-key KEY SHARE locks while serializing
  price decisions. This favors correctness; company-level write throughput
  still needs production-sized load testing.
- Transactions retain the existing UOW commit/rollback boundaries. Evidence
  and earnings are flushed together before a successful acknowledgement.

## Verification

Initial focused run: 29 PASS. An earlier run stopped after 2 PASS because the
new test expected a batch-style `status` in the v2 ACK; the test was corrected
to use the actual `ok` contract, without changing the public API.

Expanded PostgreSQL regression: **444 PASS**, 1239.26 seconds. It includes all
35 new earning cases, the price timeline/approval/draft/reconciliation checks,
additional work, earning corrections, both sync paths and tenant snapshots,
queue administration, door assignment atomicity and architecture tests.
Supplemental PostgreSQL regression: **72 PASS**, exit 0, 199.93 seconds: payroll
lifecycle, installer phase 2, core E2E, financial DB constraints, cross-company
isolation and OpenAPI. The two cancellation/correction concurrency tests now
coordinate before the company lock, retaining their original zero-net-payroll
assertions for both operation orders.

Together the final runs cover **516 unique passing tests**, without counting
the repeated initial focused cases again. This is selected backend regression,
not the complete backend/admin/mobile release suite.

The guarded disposable-DB smoke passes from an empty database through 0066,
including 0063/0064/0065 round trips, 0066 rollback/re-upgrade, metadata matching,
unchanged legacy row snapshots, real new 300 ILS completion with evidence and
unchanged old 250 ILS completion without evidence. Both 0066 downgrade guards
were independently exercised: persisted queue time, then persisted earning
evidence. Each refusal preserves rows and the Alembic revision.

The command uses `scripts.db_factory_earnings_migration_smoke`, exact isolated
database `dimax_factory_price_migrations`, `APP_ENV=test`, and explicit flags
`DIMAX_PRICE_LIST_MIGRATION=1`, `DIMAX_PRICE_APPROVAL_MIGRATION=1`,
`DIMAX_PRICE_TIMELINE_MIGRATION=1`, `DIMAX_FACTORY_EARNINGS_MIGRATION=1`.
The database was confirmed absent before this turn created it.

Both acceptance and test schemas are at `0066_factory_earning_prices`.
The current acceptance company still has zero factory lists, approvals,
activations and earning evidence; the test database has zero remaining
activations/evidence. Before/after business checksums match:

| Table | Rows | Checksum |
| --- | ---: | --- |
| completed_work | 11 | d972af6ed54536ef21a9d1abc9f1ec2c |
| installer_rates | 8 | 7ffab959007f5746bb9cc74f13fac706 |
| doors | 9 | 23ddc04087c8a06023ce96bc52cb92dc |
| project_addon_plans | 1 | 05d1630d4faf1ed8e44fb61f1ec698b0 |
| project_addon_facts | 1 | ffad0b2f2f4243935a4c215c69d175bc |

Only acceptance API 8001 was restarted. Final strict checks PASS:
`/ready` has `status=ok`, `checks.database=ready`; `/health` is OK; OpenAPI
contains the new earning evidence schema and no activation route; unauthenticated
price-list/earning-ledger requests return 401; admin preview 4173 returns HTML/200.
The API container is healthy. Normal API/database 8000 were not restarted or
migrated. No real factory decision or external message was sent.

The owned disposable migration database was dropped and its absence verified.
One-off containers used `--rm`, and test bytecode/pytest-cache writes were
disabled. No new APK, archive or dependency installation was produced.
Admin/mobile source is unchanged. The admin's pre-existing `next-env.d.ts` and
`tsconfig.json` edits are preserved and excluded. Frontend/mobile builds, browser
interaction and native tests were not rerun for this server-only step. The test
image uses Python 3.12; Python 3.11 is not separately certified here.

## Remaining Rollout

1. Mobile read-only effective/historical price cache, SQLite migration, outbox
   execution-version evidence, cold resync and visible price-conflict handling.
2. Admin reviewed activation with accurate active-version state, including
   catalog/work-plan writer consistency checks at rollout.
3. Full admin/backend/mobile release gates, physical-phone offline scenarios,
   controlled HTTPS factory confirmation/delivery and deployment acceptance.

No factory-approved historical correction workflow is invented here: arbitrary
manual rates are rejected. Such a workflow needs separately defined authorized
business rules. Missing first-list prices must not be resolved by silently
switching to a later list. Existing legacy financial history stays unchanged.

No new dependencies, APK, archive or build cache are required. Remote backups
remain blocked by the existing public-repository publication restriction;
this step must be checkpointed locally without claiming a GitHub backup.

Local backend implementation/migration/tests/checklist commit: `cd9d611`.
Admin remains at `f38d109` with its existing config edits; mobile at `f5eaeae`.
