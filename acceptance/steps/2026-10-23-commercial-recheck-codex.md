# Commercial confirmation recheck (Codex, 2026-10-23)

Status: partial; runtime acceptance blocked by host memory pressure. This is a separate verification of the current code, not a
replacement for the parallel Claude reports or acceptance of the whole product.

## Isolation and coordination

- Backend snapshot: `55d7c7ca9a6bb2f6130e26f875d6c8c31d6b7966` (0088 work stages).
- Admin snapshot: `be6be085e9baa222ce5862f0fed9ce5806ac7fe1`, plus the focused
  `ContractTerms.test.tsx` correction described below.
- Source snapshots/builds: `.tmp/codex-commercial-20261023`; no working `.env`.
- Compose project: `dimax-approval-codex-20261023`, internal network and tmpfs DB
  `dimax_commercial_runtime_tests`. Local API 8003 / UI 4194 are reserved for this
  acceptance, not for ordinary work data. No external SMTP or WhatsApp.
- Claude's existing changes in admin config, InstallerPricingMode and the demo
  Compose file were left untouched. No application/backend business logic edits.
- Docker was initially off. The owner explicitly permitted starting Docker and
  the resulting automatic working migrations. The ordinary API and DB became
  healthy; a read-only query showed working revision `0088_work_stages`.
- A separate explicit approval allowed pausing five ordinary DIMAX workers
  (AI, import inbox, sync GC, maintenance, outbox). Their original IDs and running
  states are recorded locally for restoration. With free RAM down to 86 MB, the
  owner subsequently also approved pausing the ordinary API and MinIO; their
  IDs were recorded and both stopped. The working database remains running.

## Completed in this run

- Fresh isolated schema migration from empty DB through 0088 succeeded.
- Commercial backend command: **88 passed in 276.76 seconds**:
  `test_commercial_drafts.py`, `test_commercial_contract_terms.py`,
  `test_commercial_approvals.py`.
- An earlier command used an incorrect test filename and ran zero tests. It is
  not counted as a passing run.
- Factory contact authority and mailbox verification: **29 passed in 164.72
  seconds**, including the opt-in real SMTP/Mailpit test (no skip).
- These older tests require the exact name `dimax_acceptance_tests`; a second
  database was created inside the same disposable PostgreSQL. The initial
  single-case attempt was refused by this guard, not accepted as a pass. The
  guard was not weakened. Browser acceptance keeps its own fresh database.
- The first broad additional regression was stopped under severe memory
  pressure; no whole-suite pass is claimed for that attempt. Its diagnostic
  traceback showed FastAPI/Pydantic route-schema generation; a DB activity
  snapshot did not show a lock wait. The sequential 119-case rerun (work-price
  accruals, approvals, proposals and commercial activation) also ended nonzero
  without a pytest summary under a 900-second limit. Neither attempt counts as
  a passing suite; dots without a completed summary are not acceptance evidence.
- Admin commercial suites: **51 cases passed across completed runs**. The first
  combined run had 49 pass / 2 fail; both obsolete expectations in ContractTerms
  were corrected and all its 16 cases passed on rerun. Other suites:
  CommercialApprovalPage, ContractApprovalsPanel, FactoryAccountingPage,
  ContractAgreements.
- Four UI ratchets passed: typography, RTL utilities, locale helpers, accessible
  names of controls.
- Production admin build passed, including TypeScript and the commercial routes.
  Build was made in the snapshot for API `http://127.0.0.1:8003`. Node 25.5.0 was
  available; this does not close the declared Node 20 release gate.

## Focused changes

- ContractTerms test now expects the current "Contracts & billing" name and
  verifies ArrowRight, End to the new Periods tab, Home, and keyboard focus.
- Runtime schema guard checks the Alembic head of the frozen source instead of
  hard-coding obsolete 0087; tenant/test database and APP_ENV guards remain.
- Browser harness requires an explicit isolated project, blocks nonlocal
  network origins, separates OWNER and unauthenticated factory contexts,
  checks explicit consent, wrong code, replay/tampering, RU390/HE768 and receipt.
- Optional `commercial-approval-mailpit.compose.yml` adds local SMTP on the
  internal network only. The guarded runtime can execute the actual outbox worker
  and read the delivered link/code from Mailpit, without secrets in admin API.
- Receipt verification logs in with real JWTs for OWNER, OPERATIONS, FINANCE,
  VIEWER, INSTALLER and a foreign tenant; compares installer financial row
  digests and checks that confirmation did not activate an agreement.

## Runtime attempt and remaining gates

- The fresh browser DB migrated through 0088. The temporary built admin started
  on 4194. However, the test API remained unready for more than ten minutes;
  gateway health returned 502. At that point Windows had only 63 MB free RAM,
  despite the approved service pauses. The API cgroup reported no OOM kills;
  this does not rule out host paging/resource contention or application issues.
- Fixture preparation did not finish. The enhanced browser harness was NOT run;
  no new browser screenshots, SMTP approval-chain pass, restart-persistence pass,
  or downgrade-refusal pass is claimed for this attempt.
- Rerun the 119-case additional regression and the full browser chain on a host
  with sufficient memory. Inspect RU390/HE768 screenshots, verify the receipt
  after API restart and the protected downgrade. Keep the same isolated guards.
- Service restoration and temporary artifact cleanup are recorded below.

## Cleanup and recovery

- Stopped our temporary admin using its recorded PID and process start time.
- Removed the admin snapshot/build only after unlinking its `node_modules`
  junction non-recursively; the real admin dependencies were checked and kept.
- Removed our backend snapshot and source archives. No other agent's files,
  existing environments, volumes, or historical acceptance containers were deleted.
- Docker initially returned 500 and missing-exit-event errors while removing
  our disposable containers. They eventually exited; all four containers and
  both networks of `dimax-approval-codex-20261023` were removed.
- The seven paused ordinary services were started using their recorded IDs.
  The ordinary API still failed readiness, so the user explicitly permitted a
  normal Docker Desktop restart, including a brief working DB interruption.
  `docker desktop restart --timeout 180` completed successfully.
- After restart: working API and PostgreSQL healthy, MinIO and all five workers
  running. Both `http://127.0.0.1:8000/health` and `/ready` returned HTTP 200.
  Ordinary backend HEAD remained 55d7c7c. The normal `alembic upgrade head`
  startup phase completed; no new application migrations were introduced here.
- Removed the remaining run-local metadata/log directory after restoration.
  The full `.tmp/codex-commercial-20261023` directory is gone; this acceptance
  leaves no snapshot, build archive, private fixture, container, or network behind.
- No browser acceptance credentials or screenshots were generated in this
  attempt. `git diff --check` (root/admin) and JS syntax check completed successfully.

No push or production acceptance is claimed. Real domain/HTTPS and external
factory email delivery remain separate deployment checks.
