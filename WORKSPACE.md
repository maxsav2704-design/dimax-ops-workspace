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
.\scripts\workspace.ps1 test-release-gate
.\scripts\workspace.ps1 test-all
.\scripts\workspace.ps1 down
```

Equivalent via wrapper:

```bat
workspace.cmd up
workspace.cmd smoke
workspace.cmd test-release-gate
workspace.cmd test-all
workspace.cmd down
```

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
.\workspace.cmd smoke-mobile
```

Notes:

- `test-mobile-gate` runs `vitest + expo config + tsc`.
- `preflight-mobile-device` verifies Android SDK, `adb`, `emulator`, `java`.
- `smoke-mobile` verifies Expo/Metro startup only.
- Full device/emulator smoke still depends on a bootable Android image and enough free host RAM.

## Governance

Branch protection should be enforced on `main` for:

- backend: `Backend Tests / quality-gate`
- frontend: `Frontend Quality Gate / quality-gate`
- frontend: `Installer Quality Gate / quality-gate`

Workspace helper:

```powershell
$env:GH_TOKEN="<github_token_with_repo_admin_rights>"
.\workspace.cmd setup-governance
```

This applies the branch rules for both backend and frontend from one command by reusing the backend GitHub API script.

Working rule:

- protection must exist on GitHub
- normal changes go through PR only
- admin bypass is for emergency recovery/setup only
- use `PR_MERGE_CHECKLIST.md` before merge

## Production env validation

Validate backend `.env` and frontend production env in one command:

```powershell
.\workspace.cmd check-production-env
```

Expected files:

- `backend/.env`
- `dimax-operations-suite-main/.env.production.local` or `dimax-operations-suite-main/.env.production`

## Release process

Core commands:

```powershell
.\workspace.cmd check-production-env
.\workspace.cmd test-release-gate
```

Release docs:

- `RELEASE_TEMPLATE.md`
- `POST_DEPLOY_SMOKE.md`
- `PR_MERGE_CHECKLIST.md`
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

## Repositories

- Backend: https://github.com/maxsav2704-design/dimax-ops-backend
- Frontend: https://github.com/maxsav2704-design/dimax-ops-frontend
- Mobile: https://github.com/maxsav2704-design/dimax-ops-mobile
- Workspace: https://github.com/maxsav2704-design/dimax-ops-workspace
