# Production preflight and non-destructive infrastructure checks

## Scope

Started 2026-10-10; completed 2026-10-12. The owner confirmed that no public
domain or SMTP service has been provisioned: prepare locally only. This step
does not provision infrastructure, send real mail, deploy production, migrate
the acceptance database or change project/door/price/earning records.

## Findings and changes

- `scripts/production-infra-contract.ps1` used to remove `.next` and fixed-name
  Docker resources from `finally`, including a config-only check. Config-only
  now performs no cleanup. Full checks refuse to overwrite an existing `.next`,
  use unique labelled Docker resources, and only delete owned output after path
  and reparse-point checks. Caller environment is restored, including
  `NEXT_DIST_DIR`. Caddy syntax validation runs offline with a cached image.
- `infra/production/deploy.sh` used to source deployment env as shell code and
  only validate Compose syntax before migrations. It now reads Compose-rendered
  JSON through `preflight.py`, rejects unknown arguments and stops on invalid
  settings before pull/migrations. No rendered secrets are printed or saved.
- `preflight.py` reuses the backend production environment validator; it checks
  service presence, deployment project identity, HTTPS origins/CORS, consistent
  backend images/DB/keys/mail/storage, non-public backend ports and the outbox
  health probe. Bootstrap credentials are required only for explicit bootstrap.
- Actual deploy also verifies the pulled admin image's recorded API origin and
  non-root user before migrations. This is metadata validation, not attestation
  of the JavaScript bundle. Deployment waits for service health and no longer
  deletes orphan containers.
- Admin `Dockerfile.artifact` now launches `server.cjs`, matching the main
  Dockerfile, so the CommonJS standalone server does not inherit ESM semantics
  from `package.json`. The infrastructure contract expects that entrypoint.
- `.env.local` deployment coordinates are ignored by Git; backend secrets remain
  outside the repository. The README distinguishes syntax, semantic and external
  acceptance gates and documents Python 3.11+ as a deployment prerequisite.

## Verification

- Windows regression suite: **4/4 passed**, final run 35.15 seconds. Verified
  config success/failure preservation, refusal to overwrite an existing build,
  failed-build cleanup restricted to owned output/container, and restoration of
  the original output-directory environment. Tests use a fake Docker command.
- Linux stdlib suite: **18/18 passed**, final run 22.12 seconds. Includes six
  deployment-shell scenarios: check-only has no writes; env is not executed;
  invalid config/flags stop; stale admin image stops before migrations; correct
  pull/inspect/migrate/start ordering; failed migration prevents service start.
  Executed in a disposable container without network or Docker socket, workspace
  mounted read-only and Python bytecode writes disabled.
- Real Compose/Caddy `-ConfigOnly`: **PASS**. Caddy runs with `--network none`.
- Real rendered Compose including tools: example settings rejected (97 field
  findings); the same service structure accepts synthetic valid coordinates.
  No service start, network connection or migration is involved in this probe.
- Latest runtime readback: API `8001/health` and `8001/ready`, admin `4190/login`
  all HTTP 200. Acceptance API, outbox worker, DB and Mailpit report healthy.
- `git diff --check`: passed. No source tree caches or test artifacts were added;
  test fixtures use disposable directories/containers, not working data volumes.

Test-harness failures were corrected before accepting results: executable fake
Docker requires an executable Linux temp mount; Windows fake Docker needed a
global labels dictionary when called from the separate contract script. Neither
failure was treated as a successful test or hidden by relaxing assertions.

## Checkpoints and limits

- Admin local commit: `126489b` (artifact CommonJS entrypoint only).
- Root local commit containing this report records the guard, preflight and tests.
- Unrelated AI changes remain unstaged. No GitHub push under the existing
  publication restriction; local Git checkpoints are not off-machine backups.
- No complete admin image build or backend/admin/mobile release suite was run in
  this infrastructure-only step. No physical-device or real mailbox acceptance
  is claimed. No migration was needed for these deployment-script changes.

## Next gates

1. Local backup/restore rehearsal with disposable databases and independent
   comparison of doors, assignments, confirmed prices and immutable earnings.
2. When available, configure the real domain, verified SMTP sender, private
   PostgreSQL/storage and immutable release images; run semantic preflight.
3. Public HTTPS/browser invitation and mailbox-code acceptance with the actual
   factory contact, exact-version confirmation and separate admin activation.
4. Exact-release backend/admin/mobile checks, device offline-price transition,
   journal/PDF delivery and a limited supervised business pilot.

This closes the local preflight block, not overall production readiness.
