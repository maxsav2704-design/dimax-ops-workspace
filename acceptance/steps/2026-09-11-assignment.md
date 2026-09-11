# Assignment and completion acceptance, September 11, 2026

## Scope

Continue from the nine imported synthetic doors in `QA-IMPORT-20260910`.
UI data remains in `dimax_acceptance`; regression tests run exclusively on
`dimax_acceptance_tests`. No customer data, external delivery, signatures or
physical-device work is part of this checkpoint.

## P1: Assignment/Completion Ownership Race

Backend `c7b6e56` read doors without a row lock. SQLAlchemy's identity map could
also retain a door read before another transaction committed a status/assignment
change. The legacy install/not-installed routes checked ownership in an earlier
dependency transaction but did not recheck it during the actual write.

After correcting an incomplete test fixture (missing required project address),
all five reproductions failed in 24.92 seconds:
- Single assignment accepted a cached door that another transaction had completed.
- Bulk assignment accepted the same stale unlocked state.
- Completion accepted the old installer after another transaction reassigned it.
- Both legacy installer actions returned 200 instead of 403 after reassignment
  when the earlier ownership guard result was retained.

The fixture setup errors are not counted as evidence of a production defect.
The stale-read tests use real interleaved PostgreSQL transactions. Two legacy-route
tests explicitly override the earlier guard result to reproduce its timing window;
they keep real JWT authentication, but are not an untouched-browser race test.

## Correction

Backend commit `db007e8`:
- `DoorRepository.get` accepts an opt-in `for_update` flag. Mutating use cases
  acquire a tenant-filtered row lock and refresh the ORM instance before checking
  ownership/status. Normal read queries remain unlocked.
- Single/bulk assignment, installer status, legacy actions, admin override and
  sync status mutation use the locking read. Bulk lock acquisition follows sorted
  IDs while preserving the original response order.
- Internal commands carry the expected installer for legacy/sync installer actions.
  The write transaction rechecks ownership, not just the earlier HTTP guard.
- No Alembic migration is needed. External request/response fields, status rules,
  rate calculations, completion accounting, photo/signature requirements and
  transaction ownership remain unchanged.

## Focused Evidence

Eight tests passed in 35.58 seconds on the isolated test database:
- The five reproductions above now reject stale/unauthorized writes.
- PostgreSQL NOWAIT proves another writer cannot lock the row until transaction end.
- Two simultaneous completions create one accrual of 250.00, one history entry
  and door version 1; the competing transition is rejected.
- A real-JWT owner and two installers exercise assignment, separate door visibility,
  denial of the other installer's write, completion/repeat, and earnings/report
  reconciliation: 250.00 + 400.00 = 650.00 payroll; client revenue 2200.00;
  actual profit 1550.00. There are exactly two completed-work rows.

Expanded local verification on the same isolated test database:
- 109 PASS, 331.88 seconds: assignment atomicity, project admin API, installer
  phase 2, installer snapshot, sync batch and multi-tenant isolation. This count
  includes the eight focused tests above; they are not added twice.
- 39 PASS, 38.38 seconds: architecture, security hashes and OpenAPI contract.
- Mobile: 77 PASS in five API/sync/projects/action-state/earnings test files,
  6.87 seconds, single fork. This is source compatibility, not native acceptance.
- Backend `git diff --check`: PASS.

These are expanded targeted checks, not the full backend release gate at this
revision. The earlier full backend CI result does not cover `db007e8`.

## Live UI Evidence

Acceptance API was restarted with `db007e8`; host `/ready` returned 200 with the
database ready. Actions below used the actual production-mode frontend `52b59fe`
at port 4173, real login/logout, and synthetic company A only. No browser auth
injection, SQL writes or mocked APIs were used for this workflow.

1. Owner selected the four visible building-A doors and assigned A-1. Selection
   cleared to zero. Owner then selected the five building-B doors and assigned
   A-2. Read-only SQL confirmed the exact 4/5 allocation.
2. A-1 saw exactly four A doors, completed entrance and fire doors at A/1/101,
   and saw 500 ILS for day/month and project: two separate 250 ILS entries.
3. After logout/login, A-2 saw zero earnings and exactly five B doors, not A's
   completed doors. Completing only `B-2-202-technical-FR-202/1` produced 250 ILS.
   The distinct `/2` door remained NOT_INSTALLED with version 0.
4. Owner's project plan/fact report showed 3/9 installed, six remaining, actual
   revenue 3400, payroll 750 and profit 2650. Plan remained 9800/2250/7550.
   SQL confirmed three installed doors, each locked with version 1 and a 250
   rate snapshot, and exactly three completed-work rows split 500/250.

The normal workspace API on port 8000 was also restarted with this source.
An early probe failed during startup; subsequent `/ready` returned 200 and
database ready. No migration was added; startup ran the existing Alembic check.
Delivery/maintenance/sync workers remained stopped. No volumes were removed.

During this reconciliation, the dashboard's rolling report window was found to
remain fixed at JavaScript module load. It showed zero new work until a full
browser reload, while plan/fact and installer earnings were correct. The separate
[frontend correction](2026-09-11-dashboard-window.md) records its fix, regression
tests and fresh live check. That subsequent check completed A-102 as a fourth
door, so the final fixture now has four installations and total payroll 1000.

## GitHub

After the user's further permission, earlier workspace changes through `afbe415`
and frontend changes through `52b59fe` were pushed to their existing release branch.
The frontend quality and installer gates both passed for `52b59fe`:
- https://github.com/maxsav2704-design/dimax-ops-frontend/actions/runs/34567190437
- https://github.com/maxsav2704-design/dimax-ops-frontend/actions/runs/34567190444

The installer CI still uses its previously pinned backend revision; it does not
verify `db007e8`. Publication of backend commits `c7b6e56` and `db007e8` was separately
rejected by the permission reviewer for the public backend destination. Explicit
permission naming that repository and those commits was requested. No alternate
upload route was attempted. Those backend commits remain local only.

## Remaining

Fresh native/offline acceptance, corrections/reversals/add-ons, calendar actions,
journal/PDF/signing/delivery and the full current-revision backend gate remain.
Observed web-client locale issues include English priority status text in RU and
"locked" completion being described like a work blocker. These were not changed
as part of the transaction fix. Whole-release criteria/percentages remain unadvanced.
