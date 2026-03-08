# Installer Issue Workflow Readiness

Date: March 8, 2026

## Scope Closed

- improved issue workflow inside installer `ProjectPage` with:
  - issue search
  - issue status filter
  - issue reset flow
  - visible issue counters
- added issue triage shortcuts:
  - `Show issue doors`
  - `Only this door`
  - `Open door`
- added issue summary and prioritization:
  - status chips with counts
  - blocked-first ordering
- added continuity from `Workspace`, `Schedule`, and `ProjectPage` through URL state:
  - `door_filter`
  - `issue_status`
  - `issue_search`
- added issue presets for cross-page navigation:
  - problem projects open with `BLOCKED`
  - service-driven links preserve exact search context from event title

## Validation

- installer frontend suite passed:
  - `43 passed`
- installer strict local e2e passed:
  - `3 passed`
- targeted continuity coverage added for:
  - `InstallerWorkspacePage`
  - `InstallerSchedulePage`
  - `InstallerProjectPage`

## Result

- installer can move from workspace/schedule into a narrowed issue context instead of reopening a generic project page
- issue triage now preserves operational intent across screens
- the project issue section is materially faster to use under active field conditions

## Residual Risks

- issue targeting is still frontend-context driven; there is no dedicated backend issue detail endpoint or issue-specific route
- `issue_search` presets currently depend on event titles and project naming quality
- workflow discipline is still weaker than intended because direct admin push to `main` remains technically possible via bypass

## Recommended Next Cycle

- move to `integrations hardening`
- priority focus:
  - external delivery robustness
  - retry/audit depth
  - stronger operator visibility around integration failures
