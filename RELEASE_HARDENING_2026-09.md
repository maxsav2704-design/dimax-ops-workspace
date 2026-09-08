# Release Hardening: September 2026

## Release Decision

NOT READY. Historical release reports are not evidence for the current source.
Production readiness requires fresh checks bound to source revisions, production
configuration, signed mobile artifacts, and deployment/device verification.

## Baseline (2026-09-08)

| Repository | Baseline revision | GitHub repository |
| --- | --- | --- |
| Workspace | c9e819c | maxsav2704-design/dimax-ops-workspace |
| Backend | 8bab128 | maxsav2704-design/dimax-ops-backend |
| Admin | a33a4aa | maxsav2704-design/dimax-ops-frontend |
| Mobile | eb00afd | maxsav2704-design/dimax-ops-mobile |

The four revisions were verified against remote feature branches. Existing
workspace Compose changes use the admin package's dev command and the IPv4 API
loopback address; retain them in the baseline backup. No application data,
environment files, signing keys, or generated artifacts belong in Git backups.

Work branch in every repository: `codex/release-hardening-20260908`.
Push each completed, tested change to the existing GitHub origin, without force
pushes or direct changes to main. Git backups protect source, not database data.

## Sequence

1. Preserve baseline and verify release tooling/test isolation.
2. Run backend migrations, backup/restore, access-control, import, payroll,
   journal, and sync tests. Fix confirmed Critical/High defects with regressions.
3. Run admin and mobile quality gates; fix failures without removing behavior.
4. Verify dependency security, production images, cross-repository CI, and source
   synchronization against the exact release revisions.
5. Verify production settings, signing, deployment, and physical-device flows.
   Missing external prerequisites remain explicit blockers, never simulated GO.

## Evidence and Constraints

- Docker is available; the normal workspace API/database are running.
- Backend tests must use `dimaxoperationssuite_test`, never the working database.
- Free host space at baseline: approximately 4 GB on C, 0.9 GB on D.
  Run large checks sequentially and preserve user files and existing volumes.
- Current source tests have not yet been rerun for this hardening cycle.
- Production environment, Android release signing, and current device QA need
  fresh verification. Previous reports are not proof of current readiness.
