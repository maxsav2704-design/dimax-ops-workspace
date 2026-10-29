# Outbox recovery (0089) applied and the mail worker restarted (2026-10-29)

Owner's decisions (chat, 2026-10-29): push everything to GitHub (done, all four repositories),
then variant 1 for the mail queue: apply migration 0089 and start the outbox worker.

## State found

- Working database: already at `0089_outbox_recovery`; the three recovery tables, the unique
  constraints `uq_outbox_message_tenant`, `uq_outbox_recovery_epoch`, `uq_outbox_recovery_request`
  and the append-only trigger exist; `outbox_messages` and `outbox_recoveries` are empty.
- The whole demo stack had been stopped for three days; the outbox worker had been paused since
  2026-10-24 because its code expected the recovery tables (`UndefinedTable: outbox_recoveries`).
- The other agent's recovery work was committed and pushed on `codex/outbox-recovery-gate-20261024`
  (backend; it contains every other `codex/*` branch of that work) and
  `codex/outbox-recovery-ui-20261024` (admin). The dirty working trees on the release branch were
  byte-identical to those branches (migration SHA256 `d8baee26…bd34b` matches the branch and the
  other agent's plan note).

## Done

1. Database and MinIO started; revision and schema verified before anything else.
2. Backend release branch fast-forwarded to `ee10b44` (18 commits), admin to `a2ace1a` (4 commits),
   through a stash of the working tree and `merge --ff-only`; safety stashes kept in both
   repositories. Both branches pushed to GitHub.
3. API and all five workers started (demo override: mock AI, work stages flag). API healthy,
   outbox worker running with zero restarts and no errors against the 0089 schema. Nothing was sent:
   the queue is empty; the demo stack delivers mail to Mailpit only.

## Not done / still local

- Workspace root: the other agent's CI workflows, acceptance script changes
  (`commercial-approval-browser.mjs`, `commercial-approval-runtime.py`, `commercial-runtime.py`),
  recovery acceptance folders and `docker-compose.demo.yml` AI environment lines remain
  uncommitted. They were not committed on their behalf.
- Admin: the four service files of the other agent (`tsconfig.json`, `next-env.d.ts`, `.gitignore`,
  `InstallerPricingMode.test.tsx`) plus `ContractTerms.test.tsx` remain modified, as before.
- The recovery feature itself was not re-tested here; its own records are
  `backend/tests/OUTBOX_*_ACCEPTANCE.md` and `2026-10-24-outbox-migration-plan.txt`.
