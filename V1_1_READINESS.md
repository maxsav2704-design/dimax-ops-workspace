# v1.1 Readiness

Status date: March 7, 2026

## Scope completed

`v1.1` in this cycle was focused on installer web execution speed, not on backend business-rule changes.

Delivered in frontend:

- project quick search in installer project details
- quick status filters for doors
- sticky door summary bar
- floor jump links and issue-door jump links
- priority door shortcuts
- inline `Only this` quick action for priority doors
- workspace `Today priorities` board
- workspace project quick filters
- workspace filter deep-link sync via URL
- workspace project quick actions:
  - `Today on project`
  - `Priority doors`
  - `Open issues`
  - `Open Waze`
- schedule cards now show compact project context with direct links to:
  - project
  - priority doors
  - issues

## Validation

Verified during the cycle:

- installer frontend suite: `36 passed`
- installer strict local e2e: `3 passed`
- workspace deep-link e2e covered
- workspace quick actions e2e covered

## Engineering result

What improved materially:

- fewer clicks from workspace to the next operational action
- faster narrowing to the exact door inside a project
- shareable/savable workspace views through URL state
- tighter browser-level coverage for installer flow regressions

What did not change:

- backend business logic
- authorization model
- rate logic
- migration state
- core domain rules

## Residual risks

- branch protection is configured, but recent changes were still pushed through admin bypass; normal work must return to PR-only flow
- Playwright strict flow depends on healthy seeded local/dev data and valid installer credentials
- schedule project context currently shows project id, not richer project metadata

## Recommendation

`v1.1` can be considered functionally complete for the installer web execution-speed objective.

The next cycle should move to one of:

1. richer schedule agenda / daily execution UX
2. admin operational queue visibility
3. installer issue workflow polish
