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
- Fresh source checks are recorded below; historical reports remain separate.
- Production environment, Android release signing, and current device QA need
  fresh verification. Previous reports are not proof of current readiness.

## Completed Changes

| Commit | Repository | Change |
| --- | --- | --- |
| a35eb99 | Workspace | Preserve existing Compose launch fixes and record the baseline. |
| b4c753c | Backend | Start PostgreSQL, wait for readiness, migrate, and always clean up in the error-contract CI job; add a regression test. |
| b206ffd | Backend | Align both environment examples with the existing 15-minute JWT access-token default; test both examples and include them in CI triggers. |
| f0437cc | Admin | Update four stale project UI test expectations without removing assertions; enable release-branch CI. |
| 9ceed60 | Admin | Pin installer E2E to backend b206ffd instead of unrelated main; correct test public API URL; enable release-branch E2E. |
| fb990f5 | Mobile | Enable release-branch CI. |
| c17810e | Mobile | Update only fast-uri 3.1.5 to 3.1.6, preserve lockfile integrity, add two URL-parsing security regressions to the quality gate. |

Each commit above was pushed to its existing GitHub origin on the work branch.
No application feature was removed. No schema change was needed for these fixes.

## Fresh Release Evidence

| Gate | Revision | Result | Evidence |
| --- | --- | --- | --- |
| Backend | b206ffd | PASS: 335 integration tests, 38 architecture/security tests, OpenAPI and error contracts | [GitHub run](https://github.com/maxsav2704-design/dimax-ops-backend/actions/runs/34187092551) |
| Migrations and restore | b206ffd | PASS: base to 0060, downgrade to base, upgrade again, legacy migration smoke, restore of 43 tables | Same backend run |
| Admin | 9ceed60 | PASS: 220 Vitest tests, 6 environment tests, lint, discovery, Next.js production build | [GitHub run](https://github.com/maxsav2704-design/dimax-ops-frontend/actions/runs/34187321110) |
| Installer browser flows | Admin 9ceed60 / backend b206ffd | PASS: unit gate and 4 Playwright E2E scenarios, no skipped E2E tests | [GitHub run](https://github.com/maxsav2704-design/dimax-ops-frontend/actions/runs/34187321121) |
| Mobile | c17810e | PASS: 176 Vitest tests, 2 new security regressions, existing image-size patch verification, production-config contract, TypeScript and Expo Doctor | [GitHub run](https://github.com/maxsav2704-design/dimax-ops-mobile/actions/runs/34187797235) |

Local backend migrations, restore, and 27 architecture checks passed before the
redundant local run was explicitly stopped in favor of complete GitHub checks.
The local admin run hit a Vitest worker-start timeout under memory pressure;
that run is NOT a pass. Both were superseded by successful clean CI runs above.
The temporary test database/volumes were removed. Working database/volumes were
preserved, and the four background workers and admin dev server were restarted.

## Open Release Blockers

- Critical: all three real production environment files are missing. The
  `workspace.cmd production-env-report` command reports BLOCKED for each app.
- High: none of the four `DIMAX_ANDROID_*` signing variables is configured.
  A current owner-signed native release and physical-device acceptance are not
  verified. An Expo/config/typecheck pass does not replace them.
- High: deployment acceptance still requires real HTTPS/API/storage/email
  settings and a complete installation-to-journal-to-signed-PDF delivery flow.
  Do not send test messages to real recipients or claim successful delivery
  based only on mocked service tests.
- Dependency acceptance is conditional on retaining the tested image-size
  patch. Six upstream High package-chain findings remain visible. Replace the
  compatibility patch through a separately tested toolchain upgrade later;
  do not suppress audit output or force incompatible dependency majors.

## Final Dependency and Runtime Checks

`workspace.cmd dependency-audit` passed at 2026-09-08T04:48:24Z:

- Backend: zero known vulnerabilities across 68 packages.
- Admin: zero Critical/High, three Moderate findings.
- Mobile: zero Critical, six High package-chain findings covered by the existing
  verified image-size patch, zero unmitigated Critical/High, 24 Moderate findings.
- The new fast-uri High findings were removed by the 3.1.6 patch update.
  [Upstream advisory](https://github.com/advisories/GHSA-f65p-4m7j-42xc).
- The image-size runtime checks passed for ICNS, JXL/HEIF, and valid PNG inputs.

`workspace.cmd source-readiness` passed the changed-file secret/path scan.
Local API `/health` and admin `/login` returned HTTP 200 after restoring services.
Admin URL: `http://localhost:5173/login`.

These are code/check results, not approval to deploy with missing production
configuration, signing, or device acceptance. Overall production decision stays
NOT READY; the goal is not marked complete.

## Next Acceptance Step

Provision the agreed staging/production configuration without committing its
secrets; configure owner-controlled Android signing; then verify a signed build
against that environment. Cover installer isolation, offline completion and
retry without duplicate payroll, project-specific journals, signing, and PDF
delivery to the developer and administrator. GitHub source backups are not a
replacement for encrypted database/storage backups and restore verification.
