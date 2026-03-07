# Post-Deploy Smoke

Run this after every production deploy.

## 1. Backend

```bash
curl -fsS https://<api-host>/health
```

Expected:

- HTTP `200`
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

## 5. Public/External Flows

Check at least one of:

- public file route
- journal/public communication route
- webhook/outbox health endpoint if applicable

## 6. Release Decision

Mark release complete only if:

- no blocking UI/API error is visible
- smoke is clean
- no immediate error spike is visible in logs/monitoring

If any step fails, stop and switch to `backend/RELEASE.md` rollback section or `backend/INCIDENT_RUNBOOKS.md`.
