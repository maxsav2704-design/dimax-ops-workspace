# DIMAX historical offline evidence migration acceptance

This step adds repeatable verification of migration `0071_offline_evidence`
against populated revision `0070_factory_contact`. It does not deploy the
release, change prices, apply migrations to working databases or alter mobile UI.
The populated migration, architecture checks and full backend quality gate
passed in CI. This closes the planned historical-fixture migration check;
fixture acceptance alone is not production acceptance.

## Changes

- `backend/scripts/db_offline_evidence_migration_smoke.py`: guarded, standalone
  PostgreSQL migration check using reflection of the old schema. It does not
  load new ORM columns into an old database or invent historical evidence.
- `backend/tests/architecture/test_offline_migration_safety.py`: rejects unsafe
  configuration, another target and existing database objects; exercises the
  fixture generator without a database.
- `backend/tests/architecture/test_ci_database_contract.py`: verifies isolated
  database creation precedes the check and cleanup requires successful creation.
- `backend/.github/workflows/backend-tests.yml`: the existing required migration
  job now creates, verifies and removes its own offline-evidence fixture database.
- `backend/PRODUCTION_CHECKLIST.md`: populated upgrade gate, preservation of
  unknown history and pending work, coordinated deployment and rollback limits.

The application API, pricing rules, migration 0071 itself and database constraints
were not weakened or rewritten. Existing AI, mobile and demo changes were preserved.

## Migration coverage

1. Build revision 0070 in an initially empty disposable database and seed two
   companies, linked installers, projects, assigned/unassigned/installed doors,
   existing earnings and client-price snapshots. Both sync protocols contain
   pending, retained and applied records, including absent execution timestamps.
2. Snapshot all pre-migration business tables and columns, including command
   payloads, original server receipt times and amounts. Verify exact equality
   through two 0070/0071 upgrade/downgrade cycles and the final upgrade.
3. Verify all new fields remain NULL for old rows, with correct nullable database
   types and an enabled assignment trigger. No dates, timezone evidence, prices
   or earnings may be backfilled by migration.
4. Exercise assignment, reassignment, unassignment, project/company changes and
   inserts. Server time wins over a forged date; unrelated updates retain the
   boundary. Probe transactions roll back without changing the legacy fixture.
5. Independently test five downgrade refusals: each sync protocol with timezone
   evidence true and false, and a new server-owned assignment. Every refused
   downgrade must preserve all rows, the revision, columns and trigger atomically.

The smoke tool accepts only `APP_ENV=test`, explicit
`DIMAX_OFFLINE_EVIDENCE_MIGRATION=1`, psycopg2, host `db`, port 5432 and exact database
`dimax_offline_evidence_migration_tests`, without URL query overrides. It checks the
actual database and refuses existing objects before migration. Alembic settings
must match the checked URL. It never clears an existing database to make a test fit.

## Verification

- Local AST parsing: all three changed Python files passed.
- CI YAML parsing and step placement: passed using the existing YAML dependency.
- Whitespace checks: passed.
- First CI attempt found a test-helper argument/name-column collision. The helper
  now uses a positional-only table name and has a generator regression test.
- Second attempt preserved populated data across migration cycles, then rejected
  a duplicate door position in a trigger probe. The probe now uses a distinct
  position; the uniqueness constraint remains unchanged.
- Final migration job on `f670cc0`: passed, including the five independent
  downgrade refusals, schema checks, complete old-column snapshots, the existing
  empty migration chain and legacy product-library smoke. Owned fixture database
  removal also completed successfully.
- Architecture and security contract job: **176 passed**, including 15 smoke-tool
  safety/generator cases and one new CI database ownership contract.
- API/error contracts and the isolated existing backup/restore smoke passed.
  That restore smoke still does not establish safe restore onto a shared target.
- Full backend integration rerun: **1053 passed, 4 skipped**. The four skips are
  the existing opt-in real Mailpit/MinIO delivery checks, not executed here.
  **152 focused financial tests passed** as well; these are repeated in the full
  suite and must not be counted as additional unique tests. The full suite
  reported 300 warnings, including fixture JWT key warnings. CI used Python 3.12.
- Final required quality gate on `f670cc0`: **success**. Admin/mobile source was
  not changed and their build/device gates were not rerun in this step.
- CI: https://github.com/maxsav2704-design/dimax-ops-backend/actions/runs/38267446774

## Cleanup and deployment boundary

Local Docker responded again. The old owned database
`dimax_offline_20261012_82a7_tests` was removed without force; a subsequent
`pg_database` query returned zero matching databases. This closes the pending
cleanup from `2026-10-12-offline-execution-evidence.md`.
Local API at `127.0.0.1:8001` still returned HTTP 200 for both `/health` and
`/ready`, with the database reported ready. This checks the existing runtime,
not deployment of this source checkpoint.

No local fixture database, image build, dependency download or dump was created
in this step. CI fixture cleanup runs only after its successful `createdb` and
never targets the shared local acceptance stack. A successful fixture test is not
a restore drill for real business data or proof of production performance.

Still required: verified backup/restore on an owned target, handling of retained
work with invalid/unknown time or missing prices, actual API/admin/mobile rollout,
device offline acceptance and real Mailpit/MinIO delivery checks. Production
readiness is not 100%; no percentage was re-scored in this step.

## Checkpoints

Backend commits `4591f35`, `c67eaa7`, `f670cc0` are backed up in
`codex/offline-migration-check-20261012`. No merge, force push, PR or production
deployment was requested or performed. The workspace report is a separate
checkpoint on the same named backup branch in the workspace repository.
Backend remote readback matched `f670cc0ea274c54abff37d689b7b2b65bd1c76e2`.
