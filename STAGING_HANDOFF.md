# Staging Handoff

This is the shortest safe handoff path for review, PR, and demo deployment.

## 1. Open local preview

From workspace root:

```powershell
.\workspace.cmd preview-web
```

Review URLs:

- `http://localhost:5174/login`
- `http://localhost:5174/`
- `http://localhost:5174/operations`
- `http://localhost:5174/reports`
- `http://localhost:5174/installer`
- `http://localhost:5174/installer/calendar`

Seeded demo users:

- admin: `company_id=1f16d537-5617-4c4b-a944-dafba2bcead9`, `admin@dimax.dev / admin12345`
- installer: `company_id=1f16d537-5617-4c4b-a944-dafba2bcead9`, `installer1@dimax.dev / installer12345`

## 2. Print PR compare links

```powershell
.\workspace.cmd staging-handoff
```

This prints:

- current feature-branch compare links for `workspace`, `backend`, `frontend`
- current clean/dirty repo status
- local preview/API reachability
- demo deploy commands

## 3. Open PRs

Use the compare links from `.\workspace.cmd staging-handoff` or `.\workspace.cmd pr-links`.

Required repos:

- `dimax-ops-workspace`
- `dimax-ops-backend`
- `dimax-ops-frontend`

Use the repo PR templates already committed in each repository.

## 4. Demo deploy

Prepare `.env.demo` from `.env.demo.example`, then run:

```powershell
docker compose --env-file .env.demo -f docker-compose.demo.yml up -d --build
docker compose --env-file .env.demo -f docker-compose.demo.yml exec -T api python -m app.scripts.seed_dev
```

Full details:

- `DEMO_DEPLOY.md`

## 5. Smoke after deploy

Minimum smoke:

1. `GET /health` returns `200`
2. admin login works
3. installer login works
4. `/operations` opens
5. `/reports` opens
6. `/installer` opens
7. one installer project page opens

Record results in:

- `POST_DEPLOY_SMOKE.md`
