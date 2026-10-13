# Accrual of separately factory confirmed work

This step connects the October 13 factory decision to an explicit administrator
accrual for one retained offline work. It does not change the company price list,
reprice existing earnings, or let an installer submit a price. Runtime rollout
and external delivery remain separate release gates.

## Implemented boundary

- The live company/user must be active. Only OWNER or OPERATIONS with rate
  permission can preview or accrue. A request supplies an idempotency key, the
  reviewed factory decision hash, a reason and explicit consent, never a rate,
  amount, installer or replacement execution time.
- The company lock serializes decisions. The service rechecks the latest
  proposal, unchanged original command, project access, installer assignment,
  door identity/version/state, catalog, quantity/unit and execution evidence.
  The factory decision must contain a valid mailbox confirmation and match the
  immutable proposal. Unconfirmed/superseded/stale work is not accrued.
- A previously valid decision survives invitation-link expiry and later contact
  replacement, consistently with recorded price-list confirmations. This does
  not authorize a pending invitation after contact revocation or link expiry.
- The existing door completion and additional-work use cases calculate and
  record the work. An internal typed price basis binds the exact company,
  project, installer, type, execution time, quantity and rate; no public installer
  schema accepts it. Client pricing and ordinary status/sync effects are retained.
- Work, earning, immutable accrual evidence, administrator audit and server queue
  acknowledgement commit in one UOW. Failure rolls all of them back. Identical
  request retries return the same receipt; different requests cannot accrue the
  same approval/work twice. The retained mobile command is never rewritten.
- Migration `0074_work_price_accruals` adds tenant-scoped foreign keys, unique
  request/approval/work/source constraints, immutable evidence, and protection
  against editing/deleting the associated earning or its reversal. A nonempty
  history blocks downgrade. Door cancellation creates the existing exact negative
  reversal, linked to the original earning and its factory evidence.
- The admin ledger exposes an additive `work_price` evidence field, including
  for reversals, and blocks arbitrary manual-rate correction. The installer
  earnings summary reads the same completed-work ledger at the original work
  date; fractional additional work retains decimal rounding.
- The mobile app already checks blocked pricing decisions without replaying
  commands. The backend lookup now includes these separate accruals as well as
  ordinary price resolutions. Only the originating company/installer receives
  the read-only ACK; unresolved/unknown work is not acknowledged.

## Administrator workflow

1. In Operations, open the retained pricing conflict and its saved proposal.
2. Open Factory confirmation and refresh its status after the representative
   confirms the exact work through the link and mailbox code.
3. Select Review accrual. Check project, installer, work reference, performed
   date, quantity/unit, factory signer/date, rate and total.
4. Enter the reason, explicitly confirm the checked terms, and confirm accrual.
   The form has no editable price or amount.
5. After a lost response, check the result. An unchanged retry uses the same
   request ID. Recorded receipts replace the submit form. Earnings evidence is
   available in the admin ledger; mobile receives the ACK and canonical summary.

The additive API is `GET/POST /api/v1/admin/sync/work-price-approvals/{id}/accrual`.
Responses use `Cache-Control: no-store`. The UI is translated in EN/RU/HE and
retains the existing accessible, scrollable review dialog and RTL layout.

## Verification

- Local frontend: 23 scoped tests passed; scoped ESLint passed. Full CI on the
  initial UI commit passed 557 tests across 60 files, TypeScript, production
  build (27 pages), and all 12 Chromium scenarios in EN/RU/HE. A final repeat
  includes the added quantity/unit row and its assertion.
- Three accrual screenshots were inspected at 1280 px EN and 390 px RU/HE.
  No horizontal overflow or overlapping fields was observed; the long dialog
  scrolls. Browser scenarios mock API responses; they are not SMTP or deployed
  end-to-end evidence.
- Mobile code is unchanged. Five existing suites passed 137 tests covering sync,
  cold resync, account isolation and earnings service/contracts; TypeScript passed.
  The first sandboxed Vitest attempt failed to rename its own temporary files;
  the same scoped command passed outside the sandbox. Local Node was 25, not the
  mobile release requirement Node 20; this is not a fresh device/release build.
- Backend adds 31 PostgreSQL scenarios for door/add-on, both retained queues,
  legacy/current timelines, duplicate and concurrent submissions, stale work,
  authority, tenant isolation, consent, rollback, immutable history, cancellation,
  downgrade refusal, installer earnings and read-only mobile ACK.
- Final backend and frontend CI results are pending below. Earlier backend runs
  exposed an incorrect helper import and test assumptions about preview hashes
  and existing 403/422 contracts; these were corrected without relaxing guards.
  The read-only mobile ACK lookup gap was found during code review and fixed
  before final acceptance. The superseded backend run was cancelled to release
  the serial CI slot; a cancelled run is not a pass.

## Backups and runtime

Backup branch in all changed repositories: `codex/work-price-accrual-20261014`.

- Backend: `159564c1157c89ce1baeb4c54cad0f5f7aefcf5f`.
- Frontend: `3903abeef79b0c8d84df6df945c5dfc6ee1ef8c4`.
- Backend final CI: https://github.com/maxsav2704-design/dimax-ops-backend/actions/runs/38479035940
- Frontend initial successful CI: https://github.com/maxsav2704-design/dimax-ops-frontend/actions/runs/38477899081
- Frontend final CI: https://github.com/maxsav2704-design/dimax-ops-frontend/actions/runs/38478853560

Unrelated AI/config/demo changes remain untouched and are excluded from the
backups. No real factory mail, phone interaction, production work completion,
payroll change or working-database migration was performed. Docker's local Linux
engine was unavailable. PostgreSQL validation uses disposable CI infrastructure.
The existing admin development server responds HTTP 200 at
http://127.0.0.1:4191/login; a duplicate startup on that port was rejected and did
not replace it. The new backend is not deployed to the local working database.

## Next release gates

1. With Docker available, back up and deploy migration, API, worker and admin
   together in an isolated environment. Accept retained mobile work, factory
   confirmation, administrator accrual, read-only ACK, visible earnings and an
   exact cancellation end to end. Do not equate mocks with this deployment gate.
2. Provision public HTTPS and SMTP, verify the factory contact organizationally,
   and test real external delivery without exposing tokens or codes to admins.
3. Complete the remaining physical-device, storage/PDF and recovery acceptance.
   The isolated restore test does not resolve shared-target restore safety.
   This step is not a claim of 100 percent production readiness.
