# Changelog

## localization readiness - March 10, 2026

- multilingual frontend cycle recorded in:
  - `LOCALIZATION_READINESS.md`

## final production maturity readiness - March 8, 2026

- final production maturity cycle recorded in:
  - `FINAL_PRODUCTION_MATURITY_READINESS.md`

## integrations hardening readiness - March 8, 2026

- integrations hardening cycle recorded in:
  - `INTEGRATIONS_HARDENING_READINESS.md`

## installer issue workflow readiness - March 8, 2026

- installer issue workflow cycle recorded in:
  - `INSTALLER_ISSUE_WORKFLOW_READINESS.md`

## reports and operations convergence readiness - March 8, 2026

- reports and operations convergence cycle recorded in:
  - `REPORTS_OPERATIONS_CONVERGENCE_READINESS.md`

## admin queue controls and batch actions readiness - March 8, 2026

- admin queue controls / batch actions cycle recorded in:
  - `ADMIN_QUEUE_CONTROLS_READINESS.md`

## admin operations visibility readiness - March 7, 2026

- admin operations visibility cycle recorded in:
  - `ADMIN_OPERATIONS_VISIBILITY_READINESS.md`

## v1.1 readiness - March 7, 2026

- installer web execution-speed cycle recorded in:
  - `V1_1_READINESS.md`

## v1.0.1 readiness - March 7, 2026

- operational/testing/governance hardening summary recorded in:
  - `V1_0_1_READINESS.md`

## Post-release baseline - March 7, 2026

Recorded after `v1.0.0` release publication and governance hardening.

### Workspace

- normalized repository boundaries for workspace, backend, frontend and mobile
- tracked workspace orchestration files:
  - `docker-compose.workspace.yml`
  - `docker-compose.workspace.test.yml`
- restored clean architecture and audit docs:
  - `ARCHITECTURE.md`
  - `V1_AUDIT.md`
- added unified governance command:
  - `.\workspace.cmd setup-governance`

### Backend

- added repository entrypoint `README.md`
- fixed branch protection scripts to work correctly for non-backend repositories
- applied GitHub branch protection on `main` with required check:
  - `Backend Tests / quality-gate`

### Frontend

- replaced placeholder template `README.md` with project documentation
- added explicit CI workflows:
  - `Frontend Quality Gate / quality-gate`
  - `Installer Quality Gate / quality-gate`
- documented frontend quality gate in `QUALITY_GATE.md`
- applied GitHub branch protection on `main` with required checks:
  - `Frontend Quality Gate / quality-gate`
  - `Installer Quality Gate / quality-gate`

### Hygiene

- removed generated caches, build output and local runtime logs
- kept local env files untouched
- verified all repositories are clean after cleanup
