# DIMAX Operations Suite Architecture

## Workspace layout

This workspace is intentionally split into separate repositories:

- `backend/`: FastAPI application, Alembic migrations, integration tests
- `dimax-operations-suite-main/`: Next.js admin and installer web UI
- `mobile/`: Expo installer mobile client
- workspace root: orchestration scripts, shared release/run documentation

This separation keeps deployment boundaries and git history clean while preserving a single local development workspace.

## Backend structure

The backend follows a module-oriented layout with a strong domain boundary per menu/business area.

Menu-to-module mapping:

| Product area | Backend module |
| --- | --- |
| Dashboard | `app/modules/dashboard` |
| Projects | `app/modules/projects` |
| Installers | `app/modules/installers` |
| Calendar | `app/modules/calendar` |
| Journal | `app/modules/journal` |
| Door Types | `app/modules/door_types` |
| Reasons | `app/modules/reasons` |
| Reports | `app/modules/reports` |
| Settings | `app/modules/settings` |
| Companies / platform limits | `app/modules/companies` |

Typical internal layering:

- `api/`: HTTP endpoints and transport schemas
- `application/`: use cases and orchestration logic
- `domain/`: domain rules and domain-specific errors
- `infrastructure/`: ORM models, repositories, integration adapters

Shared concerns live under:

- `app/shared/`
- `app/api/v1/`
- `alembic/`

## Domain notes

`door_types` and `reasons` are separate modules on purpose.

- `door_types` affect installer rates and door-related business rules.
- `reasons` affect not-installed workflow, reporting, and statistics.

They should not be folded into generic lookup tables without reworking domain behavior.

## Frontend structure

The web client is split by route groups and access scope:

- `app/(admin)/...`: admin-facing pages
- `app/(installer)/installer/...`: installer-facing web workspace
- `src/views/`: page-level UI composition
- `src/components/`: reusable UI and page widgets
- `src/lib/`: auth/api helpers and permission utilities
- `src/test/`: Vitest coverage for admin and installer flows
- `e2e/`: Playwright smoke and installer E2E checks

The frontend enforces role-aware navigation and route protection through shared auth helpers and `RequireAuth`.

## Mobile structure

The mobile app is an offline-first installer client.

Core areas:

- `app/`: Expo Router screens
- `src/lib/`: API client, config, SQLite access
- `src/modules/auth/`: session handling
- `src/modules/projects/`: local project read model
- `src/modules/doors/`: installer actions
- `src/modules/sync/`: sync policy, queue state, retry behavior

The current mobile scope is a solid foundation layer, not yet the main production client.

## Delivery model

Operational flow is standardized through workspace scripts:

- `workspace.cmd up`
- `workspace.cmd smoke`
- `workspace.cmd installer-gate`
- `workspace.cmd test-backend-gate`
- `workspace.cmd test-release-gate`

This gives one repeatable path for local bootstrap, quality verification, and release gating.

## Release posture

Current release baseline is `v1.0.0`.

The strongest production-ready path today is:

- backend
- admin web
- installer web

Mobile is integrated, tested, and versioned, but still best treated as an expanding companion client rather than the primary field runtime.
