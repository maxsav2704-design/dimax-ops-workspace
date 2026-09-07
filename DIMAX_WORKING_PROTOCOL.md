# DIMAX Working Protocol

## Core Principle
- Preserve what is good.
- Improve what is weak.
- Add only what is missing.
- Do not rebuild for the sake of rebuilding.

## Before Any Change
1. Understand the current implementation.
2. Identify what already works well.
3. Find the real gap.
4. Check whether code is actually needed, or whether polish / normalization is enough.

## What We Must Not Do
- Do not rewrite the whole project.
- Do not break working logic without a strong reason.
- Do not expand scope carelessly.
- Do not bring in logistics, warehouse, inventory, purchase orders, or routing.
- Do not introduce abstractions without clear value.
- Do not change APIs broadly without need.

## What We Check In Every Module
- Architecture: boundaries, naming, duplication, dead code.
- Product logic: whether the workflow is complete end-to-end.
- UI: tables, statuses, filters, forms, quick actions.
- Consistency: reuse, tokens, shared patterns, behavior.

## Allowed Block Statuses
- Implemented well
- Implemented but weak
- Partially implemented
- Missing
- Misaligned with scope

## Priority Order
1. Core operations
- Projects
- Structure
- Installation items
- Assignments
- Calendar

2. Execution control
- Journal
- Checklists
- Sign-off
- Attachments / files

3. Management layer
- Payroll
- Reports
- Notifications
- Audit / activity

4. UI maturity
- Saved views
- Filters
- Drawers
- Quick actions
- Design consistency

## UI Standard
The interface should be:
- Dense
- Professional
- Fast to scan
- Low-noise
- Useful, not decorative

## Preferred UI Primitives
- DataTable
- StatusBadge
- FilterBar
- QuickActions
- DetailDrawer
- PageHeader
- EmptyState
- SectionCard

## Status Model Guidance
Prefer a compact status model:
- draft
- unassigned
- assigned
- in_progress
- review
- completed
- completed_with_issue
- paused
- blocked
- archived

## Backend Standard
- Modules should reflect the domain.
- Statuses should be centralized.
- Change history should be understandable.
- APIs should be consistent.
- Avoid unnecessary DDD theater.

## Required Change Format
### Before changes
- Current architecture summary
- Existing strengths
- Gaps
- Priority actions

### During changes
- Why the change is needed
- What existing code was reused
- What was added
- What was intentionally not changed

### After changes
- Implemented improvements
- Optional remaining improvements
- Risks / follow-up items

## Quality Bar
After our work, the project should be:
- More coherent
- More maintainable
- More useful for day-to-day operations
- Visually stronger
- Still the same product, not a rewritten replacement
