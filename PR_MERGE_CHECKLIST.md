# PR Merge Checklist

Use this before merging into `main`.

## Branch rule

- do not push directly to `main`
- do not use admin bypass for normal work
- merge only through PR after required checks are green

## Required checks

Backend PR:

- `Backend Tests / quality-gate`

Frontend PR:

- `Frontend Quality Gate / quality-gate`
- `Installer Quality Gate / quality-gate`

## Author checklist

1. Scope is small and intentional.
2. Business logic changes are explicit.
3. Migrations are documented if present.
4. Env changes are documented if present.
5. Release/ops impact is noted if present.
6. Local focused tests were run.

## Reviewer checklist

1. Contract changes are intentional.
2. Tests cover the changed path.
3. Docs/runbooks are updated when operational behavior changed.
4. No unrelated files are mixed into the PR.
5. Rollback risk is understood.

## Merge checklist

1. Required checks are green.
2. Branch is up to date with `main`.
3. PR title is release-note friendly.
4. If deploy-affecting, release template is prepared.
5. If incident-sensitive, smoke/rollback steps are known before merge.
