# DIMAX Workspace (Safe Integration)

This workspace keeps backend and admin separated, but run together safely:

- `backend/` is the API and database migrations
- `dimax-operations-suite-main/` is the admin UI (Next.js App Router)
- `mobile/` is the Expo installer app foundation for offline-first sync

## Why this is safe

- No folder moves, no history rewrites.
- Existing `backend/docker-compose.yml` stays untouched.
- New root orchestrator file is isolated: `docker-compose.workspace.yml`.
- Uses dedicated ports to avoid collisions with backend standalone stack.

## Start full stack

From workspace root:

```bash
docker compose -f docker-compose.workspace.yml up --build
```

Windows one-command runner:

```powershell
.\scripts\workspace.ps1 up
```

Or simple wrapper:

```bat
workspace.cmd up
```

Endpoints:

- API: `http://localhost:8000`
- Admin: `http://localhost:5173`
- Postgres host port: `5434`
- MinIO API/UI: `9010` / `9011`
- Local email inbox: `http://localhost:8025`

Development email is delivered to Mailpit through SMTP on the internal Compose
network. It never relays messages to external recipients. Production continues
to require real SMTP credentials validated by `check-production-env`.

Signed journal email smoke:

```powershell
docker compose -f docker-compose.workspace.yml stop outbox-worker
docker compose -f docker-compose.workspace.yml run --rm outbox-worker python -m app.scripts.smoke_journal_email_delivery
docker compose -f docker-compose.workspace.yml up -d --no-build outbox-worker
```

The workspace admin uses the Next.js Turbopack development server for a
responsive local feedback loop. Production Webpack compilation and browser
validation remain mandatory through `workspace.cmd test-frontend-gate` and
`workspace.cmd browser-release-smoke`.

## Conflict check commands

```bash
docker compose -f docker-compose.workspace.yml config -q
cd backend && docker compose exec api pytest -q tests/integration/test_openapi_contract.py tests/integration/test_project_file_import_api.py tests/integration/test_cors_api.py
cd ../dimax-operations-suite-main && npm test && npm run build
```

## Unified commands (Windows)

```powershell
.\scripts\workspace.ps1 up
.\scripts\workspace.ps1 ps
.\scripts\workspace.ps1 smoke
.\scripts\workspace.ps1 business-smoke
.\scripts\workspace.ps1 test-release-gate
.\scripts\workspace.ps1 test-backend-gate
.\scripts\workspace.ps1 test-all
.\scripts\workspace.ps1 down
```

Equivalent via wrapper:

```bat
workspace.cmd up
workspace.cmd smoke
workspace.cmd business-smoke
workspace.cmd test-release-gate
workspace.cmd test-backend-gate
workspace.cmd test-all
workspace.cmd down
```

Backend gate is intentionally grouped instead of one silent full `pytest` run.
It resets only the dedicated test compose stack, applies Alembic from a fresh
database, compiles Python sources, then runs architecture and integration tests
by domain so failures point to the broken subsystem quickly.

Installer bootstrap:

```bat
workspace.cmd installer-gate
```

This refreshes seeded backend users/installers and auto-generates frontend `.env.e2e.local`.

## Mobile verification

Installer mobile commands:

```powershell
.\workspace.cmd test-mobile-gate
.\workspace.cmd preflight-mobile-device
.\workspace.cmd preflight-mobile-native-build
.\workspace.cmd test-mobile-native-build
.\workspace.cmd smoke-mobile
```

Notes:

- `test-mobile-gate` runs `vitest + expo config + tsc`.
- `preflight-mobile-device` verifies Android SDK, `adb`, `emulator`, `java`.
- `preflight-mobile-native-build` verifies `JAVA_HOME` resolution and cached Gradle `8.10.2` before the first native Android build.
- `test-mobile-native-build` compiles the real Android debug application, verifies the package, SDK levels, APK signature and SHA-256, saves the ignored device-QA artifact, then removes Gradle build output.
- `smoke-mobile` runs Metro with Node `>=20.18 <21` and verifies a real Android JavaScript bundle response.
- A historical physical-device baseline confirmed:
  - APK install
  - app launch
  - installer login
  - workspace route
  - calendar route
  - earnings route
  - sync queue route
  - real assigned project detail route
- The current release still requires a fresh device regression proof no older than seven days. Remaining Android production checks include:
  - Waze handoff from the project button is confirmed on the physical device.
  - WhatsApp handoff reaches the Android chooser with normal WhatsApp selected first.
  - WhatsApp composer/prefill proof is still blocked by MIUI App Lock on the connected phone.

## Governance

Branch protection should be enforced on `main` for:

- workspace: `Workspace Quality Gate / quality-gate`
- backend: `Backend Tests / quality-gate`
- frontend: `Frontend Quality Gate / quality-gate`
- frontend: `Installer Quality Gate / quality-gate`
- mobile: `Mobile Quality Gate / quality-gate`

Workspace helper:

```powershell
$env:GH_TOKEN="<github_token_with_repo_admin_rights>"
.\workspace.cmd setup-governance
```

This applies branch rules for workspace, backend, frontend, and mobile from one
command by reusing the backend GitHub API script.

Working rule:

- protection must exist on GitHub
- normal changes go through PR only
- admin bypass is for emergency recovery/setup only
- use `PR_MERGE_CHECKLIST.md` before merge

Local guard:

```powershell
.\workspace.cmd assert-pr-branch
.\workspace.cmd assert-pr-branch report
```

This fails if `workspace`, `backend`, or `frontend` are still on `main` or in detached `HEAD`.

Feature branch bootstrap:

```powershell
.\workspace.cmd start-feature-branch feature/<short-name>
```

This creates or checks out the same feature branch in `workspace`, `backend`,
`frontend`, and `mobile`, and refuses to switch if any repo is dirty.

Push guard:

```powershell
.\workspace.cmd install-push-guard
.\workspace.cmd install-push-guard report
```

This installs a shared `pre-push` hook into `workspace`, `backend`, and `frontend` via `core.hooksPath` and blocks local pushes from or to `main`.

PR links:

```powershell
.\workspace.cmd pr-links
```

This prints ready-to-open compare URLs for `workspace`, `backend`, and `frontend` feature branches against `main`.

Staging handoff:

```powershell
.\workspace.cmd staging-handoff
```

This prints the PR compare links, local preview reachability, demo deploy commands, and seeded review logins in one place.

Web preview:

```powershell
.\workspace.cmd preview-web
.\workspace.cmd preview-web status
.\workspace.cmd preview-web smoke
.\workspace.cmd preview-web stop
```

This starts API + seeded demo users and runs the web UI locally on `http://localhost:5174/login` for fast admin/installer review without relying on the dev container frontend service.

Visual brand smoke:

```powershell
.\workspace.cmd visual-brand-smoke
```

This verifies the DIMAX login, admin and installer shells against the current
brand system, writes screenshots to `artifacts/visual-brand`, and cleans
temporary frontend build/test artifacts after a successful run.

Business smoke:

```powershell
.\workspace.cmd business-smoke
```

This uses the generated preview seed and verifies the real DIMAX flow: import
doors, create installer rate, bulk-assign doors, installer sync, installed
status, earnings ledger, installer earnings, and project plan/fact. Each run
writes release evidence to `artifacts/release/business-smoke-*.json` and
`artifacts/release/business-smoke-*.md`; latest copies are kept as
`business-smoke-latest.json` and `business-smoke-latest.md`.

Safe Docker cleanup:

```powershell
.\workspace.cmd docker-clean dry-run
.\workspace.cmd docker-clean
```

This removes only stopped containers from DIMAX compose projects. It does not
remove volumes, images, running containers, or database data.

Go/no-go automation:

```powershell
.\workspace.cmd go-no-go quick
.\workspace.cmd go-no-go full
```

`quick` checks compose config, backend health, focused backend sync/openapi
tests, admin build, mobile quality gate, and reports external production env,
mobile API URL, Android signing, and device-proof blockers. `full` runs the
heavier release path.

Android QA proof report:

```powershell
.\workspace.cmd android-qa-report
.\workspace.cmd android-qa-report report
.\workspace.cmd android-qa-report self-test
```

This reads `ANDROID_QA_RESULTS.md`, checks the required Android device proof
fields, counts evidence files under `artifacts/screens` and `artifacts/device`,
and writes `artifacts/release/android-qa-report-latest.md`.

Repository hygiene check:

```powershell
.\workspace.cmd hygiene-check
.\workspace.cmd hygiene-check report
.\workspace.cmd clean-runtime-artifacts
```

This fails when generated build/test artifacts are present in the workspace,
backend, admin, or mobile repositories. It is intentionally read-only.
`clean-runtime-artifacts` removes only the known backend/admin runtime outputs
through workspace-bounded paths and then reruns the read-only check.

Change grouping report:

```powershell
.\workspace.cmd change-report
.\workspace.cmd change-report report
```

This prints the current changed paths in all four git repositories and groups
them by recommended commit intent. The default command also writes
`artifacts/release/change-report-latest.md`.

Release status report:

```powershell
.\workspace.cmd release-status
.\workspace.cmd release-status report
.\workspace.cmd release-status self-test
```

This writes `artifacts/release/release-status-latest.md` with the current
backend health, Docker, hygiene, production env, Android QA, and latest evidence
status. It is the authoritative dynamic release decision before a handoff.
`FINAL_GO_NO_GO_PACKAGE.md` is a stable index to this report and intentionally
does not duplicate readiness percentages or test counts.
`release-status self-test` verifies that the index accepts the current contract
and rejects missing or stale percentage-bearing copies.

Release handoff bundle:

```powershell
.\workspace.cmd release-handoff
.\workspace.cmd release-handoff report
.\workspace.cmd release-handoff self-test
```

This refreshes the read-only handoff artifacts: hygiene, production env report,
change report, Android QA report, and release status. The default command writes
`artifacts/release/release-handoff-latest.md`.
The self-test verifies that external blockers are derived from release-status
without dropping mobile env or Android signing requirements.

## Production env validation

Validate backend, admin, and mobile production env files in one command:

```powershell
.\workspace.cmd production-env-report
.\workspace.cmd check-production-env
```

Expected files:

- `backend/.env.production.local` or `backend/.env.production`
- `dimax-operations-suite-main/.env.production.local` or `dimax-operations-suite-main/.env.production`
- `mobile/.env.production.local` or `mobile/.env.production`

Use `production-env-report` when the real env files are not ready yet. It is
read-only and prints which env files are missing or failing validation without
printing secret values.

## Release process

Core commands:

```powershell
.\workspace.cmd check-production-env
.\workspace.cmd business-smoke
.\workspace.cmd test-release-gate
```

Release docs:

- `FINAL_GO_NO_GO_PACKAGE.md`
- `RELEASE_TEMPLATE.md`
- `POST_DEPLOY_SMOKE.md`
- `PR_MERGE_CHECKLIST.md`
- `STAGING_HANDOFF.md`
- `DEMO_SERVER_CHECKLIST.md`
- `backend/RELEASE.md`

Observability docs:

- `backend/OBSERVABILITY.md`
- `backend/OBSERVABILITY_CHEATSHEET.md`

Rule:

- every release gets a filled template
- every deploy gets a recorded smoke pass
- rollback notes must be written before deploy, not after failure

## Releases

- Backend v1.0.0: https://github.com/maxsav2704-design/dimax-ops-backend/releases/tag/v1.0.0
- Frontend v1.0.0: https://github.com/maxsav2704-design/dimax-ops-frontend/releases/tag/v1.0.0

Post-release record:

- `CHANGELOG.md`
- `V1_0_1_READINESS.md`
- `V1_1_BACKLOG.md`
- `V1_1_READINESS.md`
- `ADMIN_OPERATIONS_VISIBILITY_READINESS.md`
- `ADMIN_QUEUE_CONTROLS_READINESS.md`
- `REPORTS_OPERATIONS_CONVERGENCE_READINESS.md`
- `INSTALLER_ISSUE_WORKFLOW_READINESS.md`
- `INTEGRATIONS_HARDENING_READINESS.md`
- `FINAL_PRODUCTION_MATURITY_READINESS.md`
- `LOCALIZATION_READINESS.md`
- `PUBLIC_LANDING_READINESS.md`
- `PUBLIC_DEMO_FLOW_READINESS.md`
- `STAGING_DEMO_POLISH_READINESS.md`
- `VISUAL_QA_READINESS.md`
- `FINAL_PR_SUMMARY.md`

## Repositories

- Backend: https://github.com/maxsav2704-design/dimax-ops-backend
- Frontend: https://github.com/maxsav2704-design/dimax-ops-frontend
- Mobile: https://github.com/maxsav2704-design/dimax-ops-mobile
- Workspace: https://github.com/maxsav2704-design/dimax-ops-workspace
