# Testing Guide

## Unit / integration tests (Vitest)

Run all tests:

```bash
npm run test
```

Run installer-focused tests only:

```bash
npm run test -- src/lib/admin-access.test.ts src/test/RequireAuth.test.tsx src/test/InstallerWorkspacePage.test.tsx src/test/InstallerProjectPage.test.tsx
```

Or use the dedicated script:

```bash
npm run test:installer
```

## E2E (Playwright)

Single-command bootstrap + strict installer gate:

```bash
cd ..
.\workspace.cmd installer-gate
```

Local bootstrap (no manual SQL required):

```bash
cd ..\backend
docker compose up -d
docker compose exec -e APP_ENV=dev api python -m app.scripts.seed_dev

cd ..\dimax-operations-suite-main
copy .env.e2e.example .env.e2e.local
# fill E2E_COMPANY_ID / E2E_INSTALLER_EMAIL / E2E_INSTALLER_PASSWORD
npm run test:e2e:installer:strict:local
```

`seed_dev` now creates/repairs installer links and sync state automatically.
Do not use manual SQL inserts for `installers` in the normal local flow.

Installer smoke test file:

```bash
node ./node_modules/@playwright/test/cli.js test e2e/installer.spec.ts
```

Or use the dedicated script:

```bash
npm run test:e2e:installer
```

Strict mode (fails if required env vars are missing):

```bash
npm run test:e2e:installer:strict
```

Strict mode with local env file:

```bash
npm run test:e2e:installer:strict:local
```

Or explicitly:

```bash
npm run test:e2e:installer:strict -- --env-path .env.e2e.local
```

Local strict run with env file support:

```bash
copy .env.e2e.example .env.e2e.local
npm run quality-gate:installer:local
```

Check env only:

```bash
npm run check:e2e:installer-env
```

Check installer credentials against API only:

```bash
npm run check:e2e:installer-auth
```

Required environment variables for installer login:

- `E2E_COMPANY_ID`
- `E2E_INSTALLER_EMAIL`
- `E2E_INSTALLER_PASSWORD`
- `NEXT_PUBLIC_API_BASE_URL`

If installer credentials are missing, installer smoke is skipped by design.
In CI (`CI=true`) missing installer credentials fail the installer smoke job.

## Installer quality gate

```bash
npm run quality-gate:installer
```

Strict installer quality gate:

```bash
npm run quality-gate:installer:strict
```

## CI workflow

Installer quality gate workflow:

- `.github/workflows/installer-quality-gate.yml`
- Includes concurrency guard (cancels older in-progress runs on same ref).
- Uploads Playwright artifacts on every e2e run (`playwright-report`, `test-results`).

Required CI secrets:

- `E2E_COMPANY_ID`
- `E2E_INSTALLER_EMAIL`
- `E2E_INSTALLER_PASSWORD`
- `E2E_API_BASE_URL`

## Build note

On low-memory machines, `npm run build` may require a bigger Node heap:

```bash
$env:NODE_OPTIONS='--max-old-space-size=8192'; npm run build
```
