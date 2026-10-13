# DIMAX retained work price proposals

This step implements preparation of a separate price proposal for one retained
work whose applicable confirmed list has no rate. It does not implement factory
invitation, confirmation or earning accrual. The original work remains in its
price-conflict queue; the company-wide price list and existing earnings stay intact.

## Implemented boundary

- Two additive admin endpoints under
  `/api/v1/admin/sync/price-conflicts/{source}/{item_id}/work-price-proposals`:
  `POST /review` rechecks eligibility and returns a stale-review token and latest
  proposal; `POST` saves a versioned proposal. Existing resolve APIs are unchanged.
- Both require live OWNER or rate-authorized OPERATIONS authority. Installers,
  FINANCE and VIEWER cannot prepare or save proposed rates. Tenant ownership is
  checked in queries and enforced by composite source foreign keys.
- Server checks the retained source, active installer/project, assignment, door
  version/status/lock, catalog availability/unit, quantity, existing earning or
  addon fact, original cached-price evidence and verified missing-rate context.
  A present factory rate cannot be overridden using this exception.
- The administrator supplies a proposed rate, reason, factory request/agreement
  reference and independent execution/assignment evidence. Explicit confirmation
  of checked work/quantity/date/assignment is mandatory. No amount, approval,
  source identity or arbitrary snapshot can be supplied in the request body.
- Missing/invalid execution time uses the existing separate correction DTO and
  evidence checks. The original command/time is never rewritten.
- Company/work locks, review hashes and request idempotency protect repeated and
  concurrent submissions. Changed work or a newly saved version invalidates the
  prior review. Exact retries return the existing proposal without another audit.
- Migration `0072_work_price_proposals`, after `0071_offline_evidence`, adds only
  the proposal table, constraints and an UPDATE/DELETE rejection trigger. A
  nonempty table cannot be downgraded. No data backfill or earnings repricing.
- Each immutable version retains the original command, work context, applicable
  missing-rate evidence, execution correction, terms, actor, prior proposal ID,
  hash and server-calculated amount. Proposal and audit commit atomically.
- The EN/RU/HE admin review adds explicit proposal preparation, decimal-comma
  entry, exact half-up preview, evidence fields and an unchecked confirmation.
  Saving displays PREPARED/not factory-approved, not an earned balance. Editing
  terms clears confirmation; ambiguous network retries retain the same request ID.
- Preparation sends no email, WhatsApp message, mobile ACK or sync change. No
  factory representative is impersonated. No phone installation is needed for
  this admin-only block.

## Verification

Local Python AST validation of seven touched Python files and scoped frontend
ESLint passed. No local dependency install, image build, test database or dump
was created. Full runtime and database validation uses isolated CI.

The first backend run passed 266 existing financial regressions and all other
gates but stopped at an invalid new fixture: it attempted initial activation of
a price list missing an already assigned work type. The activation guard was
preserved. The fixture now introduces the unpriced type after a valid activation,
or uses the separately agreed first-confirmed legacy case.

The first frontend run exposed a missing ResizeObserver in the new JSDOM test
setup, required by the existing Radix checkbox. It now uses the same test stub
and cleanup as the adjacent review tests; no browser behavior was bypassed.

Final verification completed on 2026-10-13 for the exact source checkpoints below:

- Backend: all eight workflow jobs succeeded, including the required quality
  gate. The focused financial suite passed 312 tests; the full integration suite
  passed 1,159 tests with four skips. These suites overlap and are not additive.
  Migration upgrade/downgrade/upgrade, historical migration guards, isolated
  backup/restore, API, error, architecture and repository contracts also passed.
- Admin: ESLint, TypeScript and the production build passed (26 generated pages).
  All 540 Vitest tests across 58 files passed. Six Chromium scenarios passed,
  covering EN/RU/HE missing-rate proposals and execution-time correction.
- Visually inspected all six proposal form/saved screenshots: EN at 1280 px,
  RU and HE at 390 px. The visible fields and saved states remain readable;
  the long dialog scrolls vertically, with no horizontal clipping. RTL is
  preserved. Browser tests successfully checked the confirmation, submitted the
  form and closed the dialog; they assert no JavaScript errors or accrual call.
  Those UI scenarios use mocked API responses; real authorization, persistence,
  immutability and transaction behavior are covered by backend integration tests.
- Verified the screenshot ZIP SHA-256 against GitHub artifact metadata before
  inspection. Removed the entire owned temporary extraction directory afterwards:
  19 files, 3,355,097 bytes. No downloaded screenshots or ZIP remain locally.

The four existing opt-in integration skips are not counted as passes. Real
delivery/storage acceptance and the shared-target restore safety issue remain
open; a passing isolated restore smoke test does not close those release gates.

## Source checkpoints

Backup branch: `codex/work-price-proposals-20261012` in backend, frontend and
workspace repositories. No merge, pull request, force-push or deployment.

- Backend: `cdb44cc56ae8ca7f2ec416e575ee024590a1bfed`, following `f9079b3`.
- Frontend: `97a40f2b82a447d1a25474d437d3b49b405084ae`, following `12e2873`.
- Backend final verification run:
  https://github.com/maxsav2704-design/dimax-ops-backend/actions/runs/38298897192
- Frontend final verification run:
  https://github.com/maxsav2704-design/dimax-ops-frontend/actions/runs/38300175483

Foreign AI/demo/mobile changes are excluded. The working database, Docker
containers and current production-preview server were not migrated or replaced.
Apply migration 0072 to an appropriately backed-up environment before using the
new backend endpoints. Browser mocks alone are not integrated deployment proof.

## Remaining workflow

1. Issue an expiring, proposal-specific invitation only to the current
   OWNER-approved factory contact, with mailbox verification. Present the
   original work identity, execution date, quantity/unit, rate and total.
2. Store independent factory confirmation bound to the exact immutable proposal
   hash/version. Reject changed contacts, replaced/expired invitations and stale
   work. Opening a link is never confirmation. Preparation references are not
   proof of the factory representative's decision.
3. Add authorized, idempotent accrual using that separate proof, without creating
   a fictitious price-list item. Revalidate work/assignment/time under locks;
   atomically record earning, proof, decision, audit and queue acknowledgement.
   Cover reversals and reports as well as original accrual.
4. Exercise the full admin/factory/mobile path in an isolated deployment, then
   complete real delivery/device/infrastructure acceptance. The factory workflow
   and project are not declared production-ready by this preparation block.
