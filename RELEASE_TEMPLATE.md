# Release Template

Use this template for every planned release after `v1.0.0`.

## Header

- Release version:
- Release date:
- Release owner:
- Target environment:

## Scope

- Backend commit/tag:
- Frontend commit/tag:
- Mobile commit/tag:
- Workspace commit/tag:

## Included Changes

- Product changes:
- Operational changes:
- Documentation/runbook changes:

## Migrations

- New Alembic migrations:
- Migration order:
- Reversible rollback confirmed: `yes/no`
- Special notes:

## Environment Changes

- Backend env changes:
- Frontend env changes:
- Secret rotation required:

## Quality Gates

- Backend gate:
- Frontend gate:
- Mobile gate:
- Release gate:
- Additional focused tests:

## Deployment Plan

1. Pull target tags/commits.
2. Validate production env.
3. Build/start required services.
4. Run migrations.
5. Deploy backend.
6. Deploy frontend.
7. Run post-deploy smoke.

## Post-Deploy Smoke

- API `/health`:
- Admin login:
- Installer login:
- Installer workspace:
- Installer schedule:
- Installer project details:
- Public/file route:

## Rollback Plan

- Previous stable backend tag:
- Previous stable frontend tag:
- DB rollback strategy:
- Roll-forward owner:

## Sign-Off

- Engineering:
- Product/Operations:
- Final release status:
