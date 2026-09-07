# Post-Deploy Smoke

Run this after every production deploy.

## 1. Backend

```bash
curl -fsS https://<api-host>/health
curl -fsS https://<api-host>/ready
```

Expected:

- HTTP `200`
- `/ready` reports `{"status":"ok","checks":{"database":"ready"}}`
- no restart loop in API container/process logs

## 2. Auth

Check manually:

- admin login succeeds
- installer login succeeds
- refresh/logout flow works once

## 3. Installer Web

Check manually in `dimax-ops-frontend`:

1. Open installer workspace.
2. Verify projects list loads.
3. Verify schedule page loads.
4. Open one assigned project.
5. Verify doors/issues/add-ons render.

## 4. Admin Web/API

Check manually:

1. Open admin dashboard.
2. Open projects list.
3. Open one reports or catalogs page.

## 5. DIMAX Business Flow

Check one real door-installation path end to end:

1. Admin creates or opens a project/object.
2. Admin imports a small Excel/CSV door list for that project.
3. Admin selects imported doors and bulk-assigns them to one installer.
4. Installer account sees only the assigned project and assigned doors.
5. Installer changes one assigned door to `in_progress`, then `installed`.
6. Admin reports show project plan/fact progress.
7. Installer earnings and admin payroll ledger include the completed door.
8. Sync/admin health page has no new blocking errors after the flow.

Local/staging automation:

```powershell
.\scripts\workspace.ps1 business-smoke
```

This uses the generated preview seed by default and writes a small smoke
project, smoke door type, installer rate, two doors, and one completed work row.
It also writes JSON and Markdown evidence under `artifacts/release/`.
For remote staging/demo, run `scripts/dimax_business_smoke.py` directly with
explicit credentials and `--allow-remote-write`.

Release is blocked if:

- installer can see another installer's doors;
- imported doors are missing from sync after assignment;
- completed work does not affect reports/earnings;
- a partial failed bulk assignment leaves some doors modified.

## 6. Public/External Flows

Check at least one of:

- public file route
- journal/public communication route
- webhook/outbox health endpoint if applicable

## 7. Evidence To Record

- API `/health` and `/ready` statuses and timestamp.
- Admin and installer test users used for smoke.
- Project/object name used for the business flow.
- Imported file name or source.
- One completed door identifier.
- Report/earnings values observed after completion.
- `artifacts/release/business-smoke-latest.json` or the timestamped evidence file.

## 8. Release Decision

Mark release complete only if:

- no blocking UI/API error is visible
- smoke is clean
- no immediate error spike is visible in logs/monitoring

If any step fails, stop and switch to `backend/RELEASE.md` rollback section or `backend/INCIDENT_RUNBOOKS.md`.
