# DIMAX offline execution evidence

Source checkpoint, not release acceptance. The automatic historical-price
guard and explicit administrator evidence decision are implemented in source.
Backend integration and migration verification remain blocked by the local
Docker and WSL failure. Audit findings 1 and 2 are not yet marked verified closed.

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
  Full-project TypeScript checking and the production build were not run.
- Admin dialog Vitest: **20 passed**, one file, one threads worker, 384 MB heap.
- Targeted ESLint: both changed TSX files passed.
- Tracked-change whitespace checks passed.

An initial Vitest invocation used an unsupported `minWorkers` option; the corrected
sandboxed attempt timed out starting its worker. Only the later successful
unsandboxed 20-test run is counted. No browser or physical-device acceptance was run.

## Backend verification still required

New integration cases cover valid current prices, retained historical claims,
first-receipt legacy proof, explicit decisions/replay, invalid clocks, assignment
cycles, protected assignment dates, direct-upload bypass and spoofed review flags.
Earlier tests expecting automatic backdated earnings were changed to the approved
hold-for-review behavior. These tests have NOT passed an integration run yet.

The temporary database `dimax_offline_20261012_82a7_tests` was created exclusively
for this step. A fresh migration run produced no successful completion and was
stopped under severe memory pressure. Windows reported 5,236 KB free physical RAM
out of 3,978,360 KB; Docker returned an engine error and WSL timed out with
`0x8007274c`. After the owned container exited, free RAM recovered to approximately
409 MB. A database read still hung, so its own CLI client was terminated.

The owned migration container `dimax-offline-migrate-82a7` was subsequently absent
from `docker ps -a`. Database contents and deletion could not be verified. After
Docker recovery, inspect and remove ONLY that uniquely named disposable database
before creating a new isolated test database. No working database was migrated,
no other project container was deliberately stopped, and no large build, dump or
downloaded dependency artifact was created.

## Required next checks

1. Restore Docker responsiveness and complete the owned test-database cleanup.
2. Run fresh migrations through 0071; test upgrade with historical assignments
   and queued commands, and refusal to downgrade after evidence is recorded.
3. Run `test_offline_execution_authority.py`, `test_factory_earnings.py`,
   `test_factory_price_sync.py`, `test_factory_price_review.py` and
   `test_price_conflict_resolution.py`, then the wider sync/addon/earnings suite.
4. Verify mobile queue retention and resolution acknowledgement against the API,
   plus the admin browser dialog, full typecheck and production build.
5. Add the separate evidence-correction workflow for absent/invalid execution
   dates (including unknown original timezone) and the missing-price workflow.
   These cases currently remain retained and non-accruing, not one-click resolvable.

## Deployment and remaining risks

Do not deploy this source checkpoint before backend tests and migration checks.
Before any real rollout, prove backup/restore, apply 0070 and 0071 in order, and
deploy the matching API/worker/admin. Existing assignment/clock history will be
unknown; prepare administrators for retained work rather than filling dates with
guesses. No changes were applied to the running acceptance data in this step.

Database-level financial immutability, legacy-mode transition enforcement,
missing-price resolution, safe restore tooling and full release acceptance remain
open. Foreign AI and mobile work was not changed or staged.

## Git checkpoints

- Backend: `f05fce5`, explicitly marked WIP pending database checks.
- Admin: `6074abc`, dialog and its 20 passing tests.
- Both commits were backed up to their existing GitHub origin repositories in
  `codex/offline-evidence-checkpoint-20261012`; remote SHA readback matched.
- The workspace checkpoint contains this report and the agreed business rule.
  No merge, force push, pull request or deployment was performed.
- The backend repository automatically starts CI on a source push. A backup
  branch is not proof of a successful CI run or release readiness.
