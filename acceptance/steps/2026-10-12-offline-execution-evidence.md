# DIMAX offline execution evidence

Source checkpoint, not release acceptance. The automatic historical-price
guard and explicit administrator evidence decision are implemented in source.
Local Docker and WSL verification was blocked, so verification continued in
isolated GitHub CI. Full backend and admin quality gates passed. Automatic
historical-price and unrestricted legacy-queue paths from findings 1 and 2 now
have passing regressions. The whole financial block is not closed: correction
of invalid time, missing prices and populated-database rollout acceptance remain.

## Implemented boundaries

1. Migration `0071_offline_evidence` adds a server-owned current assignment start
   on doors. A PostgreSQL trigger records real insert/reassignment boundaries,
   clears them on unassignment and rejects caller attempts to backdate them.
   Existing assignments remain NULL: historical assignment dates are not invented.
2. Both sync protocols retain whether the original device date had a timezone.
   This flag and the first server receipt are preserved across retries. Existing
   commands remain unknown rather than becoming trusted after database timezone
   normalization.
3. The shared execution check rejects missing, timezone-less, future and
   pre-creation dates. Unknown assignment history, work predating the current
   assignment and first uploads after a price transition require review.
   The current assignment boundary is only a lower bound, not proof of execution.
4. A supplied date no longer automatically enables the first-confirmed-price
   exception. Automatic legacy selection requires server receipt predating the
   first activation and valid assignment/time evidence. A claimed cached version
   alone never authorizes an older price after a transition.
5. Both sync protocols retain the original command as a price conflict without
   an earning. Direct addon uploads with a supplied historic date cannot bypass
   this guard; they return a conflict, rather than creating an unpaid fact that
   hides a failed earning. Online addon submissions without a supplied date
   continue to use server time.
6. For reviewable historical cases, OWNER or rate-authorized OPERATIONS must
   explicitly attest independent execution/assignment evidence and explain the
   decision. Pricing still comes exclusively from the factory-confirmed timeline,
   including the agreed first-confirmed legacy rule, never an administrator's
   arbitrary amount. Assignment/version/status checks remain in force.
7. Resolution rechecks evidence under locks, retains the original command and
   records the attestation in the immutable decision and audit event. Existing
   ordinary-decision idempotency fingerprints remain compatible. It does not
   rewrite prior earnings or reinterpret old decisions.
8. The admin dialog explains these cases in EN/RU/HE, requires the stronger
   confirmation and resets consent on record/review-token changes. Mobile
   continues to receive the existing `CONFLICT_FACTORY_PRICE` contract.

These checks do not cryptographically prove when an offline installation happened.
The administrator must genuinely verify the external evidence, not merely tick
the checkbox. Existing price confirmation and installation photo rules are unchanged.

## Verified in this step

- Python AST syntax parsing: 47 relevant source/test files passed with local
  Python 3.14. This is not a Python 3.11/3.12 runtime or dependency test.
- TypeScript transpile syntax diagnostics: the changed dialog and its tests passed.
- Admin dialog Vitest: **20 passed**, one file, one threads worker, 384 MB heap.
- Targeted ESLint: both changed TSX files passed.
- Tracked-change whitespace checks passed.
- Admin CI on `6074abc`: full lint, 500 Vitest tests across 56 files, 6 production
  environment tests, 1 standalone-runtime test, test-discovery validation,
  TypeScript and Next.js production build passed (26 static pages).
  Run: https://github.com/maxsav2704-design/dimax-ops-frontend/actions/runs/38257747632
- Backend CI on `c22b33a`: 135 focused financial tests passed. The full suite
  stopped after 347 passes and 2 skips on an older activation test that still
  expected automatic historical-price payout. `6206d64` updates that scenario
  to exercise real authentication, installer denial, administrator evidence,
  original execution-time pricing and replay without duplicate earnings.
- Final backend CI on `6206d64`: **152 focused financial tests passed**;
  **1053 full integration tests passed, 4 skipped**, followed by a successful
  quality gate. The 152 tests are included in the full suite, not 152 additional
  unique cases. Runtime was Python 3.12, not a verified Python 3.11 run.
  Run: https://github.com/maxsav2704-design/dimax-ops-backend/actions/runs/38258241574
  The four skips are existing opt-in real Mailpit checks: one factory invitation,
  one factory mailbox verification, and two journal PDF/MinIO delivery scenarios.
  They were not executed. The suite reported 300 warnings, including short
  fixture JWT keys; this is not a zero-warning result.
- Backend migration CI on `6206d64`: fresh upgrade to 0071, empty downgrade to
  base, re-upgrade and existing legacy product-library migration smoke passed.
  Architecture, API/error contracts, repository boundary and isolated
  backup/restore smoke also passed. The latter does NOT establish safety of
  the restore script against an existing shared local database.

An initial Vitest invocation used an unsupported `minWorkers` option; the corrected
sandboxed attempt timed out starting its worker. Only the later successful
unsandboxed 20-test run is counted. No browser or physical-device acceptance was run.

## Backend verification and local limitation

New integration cases cover valid current prices, retained historical claims,
first-receipt legacy proof, explicit decisions/replay, invalid clocks, assignment
cycles, protected assignment dates, direct-upload bypass and spoofed review flags.
Earlier tests expecting automatic backdated earnings were changed to the approved
hold-for-review behavior. Both focused and full integration checks passed.

The integration CI no longer starts unnecessary real MinIO for tests that use
the existing in-memory storage fixture. It creates a fresh isolated
`dimax_acceptance_tests` database with the installed psycopg2 driver. Real storage
and mail acceptance remain opt-in, not silently reported as verified. Financial
regressions run first, followed by the full suite without fail-fast so all
remaining failures are reported. Earlier CI attempts exposed the unavailable
MinIO image, a wrong driver name in the new test command and a fixture-protected
database name; these commands were corrected without weakening the guards.

The temporary database `dimax_offline_20261012_82a7_tests` was created exclusively
for this step. A fresh migration run produced no successful completion and was
stopped under severe memory pressure. That initial command also specified
`postgresql+psycopg` instead of the installed `postgresql+psycopg2`; it is not a
successful migration check. Windows reported 5,236 KB free physical RAM
out of 3,978,360 KB; Docker returned an engine error and WSL timed out with
`0x8007274c`. After the owned container exited, free RAM recovered to approximately
409 MB. A database read still hung, so its own CLI client was terminated.
A later read-only cleanup preflight also timed out after 15 seconds; only that
owned CLI client was stopped. The temporary database was NOT verified removed.

The owned migration container `dimax-offline-migrate-82a7` was subsequently absent
from `docker ps -a`. Database contents and deletion could not be verified. After
Docker recovery, inspect and remove ONLY that uniquely named disposable database
before creating a new isolated test database. No working database was migrated,
no other project container was deliberately stopped, and no large build, dump or
downloaded dependency artifact was created.

## Required next checks

1. Restore Docker responsiveness and complete the owned test-database cleanup.
2. Test upgrade from 0070 with historical assignments and queued commands, and
   refusal to downgrade after evidence is recorded. Empty migration smoke is
   not a substitute for these populated-database cases.
3. Run the four real local Mailpit/MinIO cases and the process-level factory
   delivery flow. Then verify actual HTTPS/SMTP once infrastructure is available.
4. Verify mobile queue retention and resolution acknowledgement against the API,
   plus the admin browser dialog. The admin CI typecheck/build are already green;
   no browser or physical-device acceptance was performed in this block.
5. Add the separate evidence-correction workflow for absent/invalid execution
   dates (including unknown original timezone) and the missing-price workflow.
   These cases currently remain retained and non-accruing, not one-click resolvable.

## Deployment and remaining risks

Do not treat green CI as production acceptance; the populated upgrade and real
runtime/device checks above are still required before deployment.
Before any real rollout, prove backup/restore, apply 0070 and 0071 in order, and
deploy the matching API/worker/admin. Existing assignment/clock history will be
unknown; prepare administrators for retained work rather than filling dates with
guesses. No changes were applied to the running acceptance data in this step.

Database-level financial immutability, legacy-mode transition enforcement,
missing-price resolution, safe restore tooling and full release acceptance remain
open. Foreign AI and mobile work was not changed or staged.

## Git checkpoints

- Backend: `f05fce5` source; `b25a45f`, `fd31d32`, `c22b33a` isolated CI setup;
  `6206d64` authenticated end-to-end review regression.
- Admin: `6074abc`, dialog and its 20 passing tests.
- Backend/admin checkpoints were backed up to their existing GitHub origins in
  `codex/offline-evidence-checkpoint-20261012` without force pushing.
  Remote SHA readback matched `6206d64` and `6074abc` respectively.
- The workspace checkpoint contains this report and the agreed business rule.
  An earlier version of these two files was included in the concurrent root
  commit `3866a77`; that existing commit was preserved, not rewritten.
  No merge, force push, pull request or deployment was performed.
- The backend repository automatically starts CI on a source push. A backup
  branch is not proof of a successful CI run or release readiness.

## Follow-up verification

The subsequent October 12 migration step completed the populated 0070/0071
fixture checks and the evidence downgrade guards, with a green backend quality
gate. The old local temporary database was removed and its absence verified.
See `2026-10-12-offline-evidence-migration-acceptance.md` for the results. Actual
business-data restore, retained-work correction and deployment gates remain open.
