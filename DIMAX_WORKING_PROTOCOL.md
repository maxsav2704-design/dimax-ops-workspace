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

## Price Authority
- The factory supplies the work prices. Only an authorized administrator enters
  or proposes changes to them; an installer never sets a price or earned amount.
- Use one company price list across all projects, including installation and
  additional work. Project-specific plans must not become an unapproved override.
- The factory representative confirms a specific price-list version through a
  personal link. An administrator recording a verbal approval is not a substitute.
- A requested/agreed change creates a new version requiring factory confirmation.
  Until then the previous confirmed version remains active. Never silently edit
  a confirmed price list or treat opening the link as confirmation.
- Keep the change request/reason, agreement reference and decision history with
  the version: who entered it, which representative confirmed it, and when.
- Mobile shows the confirmed installer rate as read-only. Installers submit the
  performed work and quantity; the server calculates earnings from confirmed
  terms and records their version/rate in immutable earning snapshots.
- Previously earned amounts are not recalculated when the price list changes.
  Corrections need a separate authorized, traceable business operation.
- Offline work uses the confirmed price effective at execution time, not the
  price current when the device uploads it. Preserve the version and rate in
  the earning record; an installer-supplied amount is never authoritative.
- First-rollout exception, explicitly agreed on October 3: old queued offline
  work without a confirmed price version uses the first confirmed company price
  list, not a later amendment. This does not reprice already recorded earnings
  and does not bypass assignment, duplicate or quantity checks. If the work type
  has no price in that first list, keep the work for an authorized resolution;
  do not invent a price or silently select a later version.
- Existing prices must not be labelled factory-confirmed without real evidence.
  A factory representative and a construction-site/customer signer are distinct
  roles. Factory price confirmation is separate from journal signatures.

Implementation status and the ordered rollout are tracked in
`acceptance/steps/2026-10-02-price-authority.md` and the subsequent
`acceptance/steps/2026-10-02-factory-price-list-drafts.md` and
`acceptance/steps/2026-10-02-factory-price-approval.md` and
`acceptance/steps/2026-10-02-factory-price-management.md` and
`acceptance/steps/2026-10-03-price-reconciliation.md` and
`acceptance/steps/2026-10-03-price-application-check.md` and
`acceptance/steps/2026-10-03-price-timeline.md` and
`acceptance/steps/2026-10-03-factory-earnings.md` and
`acceptance/steps/2026-10-03-mobile-price-sync.md`; this section defines the
agreed business rule, not a claim that the full confirmation workflow exists.

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
