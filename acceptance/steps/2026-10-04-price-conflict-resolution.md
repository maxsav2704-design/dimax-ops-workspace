# Audited resolution of factory price conflicts

This step extends the read-only price review with an explicit administrator
decision for a retained command whose cached confirmed version differs from
the confirmed price effective at execution. It does not activate price lists,
create factory approval, authorize arbitrary rates, or reprice existing earnings.

## Implemented behavior

- `POST /admin/sync/price-conflicts/{source}/{item_id}/resolve` requires live
  OWNER/OPERATIONS authority and rate access. The request accepts only a unique
  request ID, a review fingerprint and a reason of 10 to 500 characters.
- Only a verified version mismatch is eligible. Missing execution time,
  unavailable/unconfirmed versions, missing prices and legacy door commands
  without a usable original door version remain unresolved. The established
  first-confirmed-price exception for old versionless work is unchanged.
- The original confirmed list must contain the same work item and unit as the
  execution-time list. A changed or missing unit/item is not a price-only
  mismatch; the original quantity cannot be reinterpreted automatically.
- The company, original queue record and work context are locked before applying
  a decision. Assignment, door version/state, addon availability/unit, quantity,
  existing work and immutable factory price evidence are rechecked. A changed
  review is rejected, not silently accepted at another price.
- Existing work handlers create the work, earning, evidence and sync changes.
  The original payload, event ID and execution timestamp stay unchanged. Only a
  derived in-memory command uses the explicitly reviewed execution-time version.
- The decision, work, earning, acknowledgement and audit share one transaction.
  An audit failure rolls all of them back. A request replay returns the original
  result; another decision for the same work is rejected.
- Migration `0067_sync_price_resolution` adds tenant-scoped command/work foreign
  keys, uniqueness constraints and an update/delete protection trigger. Downgrade
  refuses to discard recorded decisions.
- The admin dialog shows a reason field and explicit work verification checkbox,
  then displays the actual recorded result. No rate/amount editing. Network retry
  retains its request ID. Queue and earnings query caches are invalidated.
- Mobile sends up to 500 blocked price event IDs as `price_resolution_checks`.
  The server only acknowledges existing audited decisions for that installer
  and company. This lookup never executes a command. Unresolved/offline records
  remain retained; normal sync consumes successful acknowledgements.

## Verification

- PostgreSQL integration: 49 distinct tests PASS (48-test run plus a 9-test
  focused rerun with one additional changed-unit test), including both queue formats, door/addon work,
  execution-time price despite a later amendment, replay, concurrency, live JWT
  scopes, rollback on audit failure, immutable decisions and scoped mobile ACKs.
- Admin dialog and operations page: 31 PASS (16 + 15), including confirmation,
  network retry, rate permission, Russian, Hebrew and cancellation of an
  unfinished read. The operations page initial-render wait is explicitly bounded
  at 5 seconds instead of relying on the default 1 second.
- Changed admin component/test ESLint: PASS.
- Mobile sync/cold resync/queue presentation/screens: 139 PASS.
- Mobile TypeScript: PASS.
- Admin production build (`next build --webpack`, isolated dist directory):
  PASS, including TypeScript and 26 generated pages.
- Browser: real component and stylesheet, isolated synthetic in-memory data;
  RU form, confirmation/result, overlay removal and HE layout at 393 CSS px.
  No horizontal overflow or browser-console errors. This is not authenticated
  end-to-end acceptance or a physical phone test.
- The first backend run had one price-transition fixture failure (35 passed).
  Diagnostic metadata was added to the fixture; the complete final rerun passed.
  That initial cause was not conclusively reproduced or attributed to production.
- Initial admin tests lacked JSDOM ResizeObserver; a test-only stub follows the
  repository pattern. One mobile assertion assumed only the old read query; it
  now verifies both reads. Final runs above passed, initial runs are not PASS.

- Test database upgrade and empty downgrade to 0066 / upgrade to head: PASS.
- Local acceptance database upgraded from 0066 to 0067. Existing completed work
  stayed unchanged: 11 rows, 1513.50 ILS, identical ordered row digest
  `873b5115c8e2e320f325b1b8ff7ad96e` before and after. No resolution rows created.
- Acceptance API restarted: healthy; `/ready` reports database ready. OpenAPI
  exposes the resolution route and mobile check field. Unauthenticated POST
  returns HTTP 401. Integration tests cover authenticated role decisions.
- Updated admin on `http://127.0.0.1:4173`: login HTTP 200 and browser console
  without errors. The user's existing login tab/inputs were not changed.
  This local preview uses `next start`; its standalone-mode warning is retained
  as a deployment-check limitation, not claimed as production container validation.

## Data and release boundaries

Tests write only to `dimax_acceptance_tests`; browser fixtures never call the API.
No production work, factory approvals, price activation, emails or WhatsApp
messages were changed. The temporary UI server and fixture/cache were removed;
only small ignored screenshots/logs remain. The new build's 255.11 MB cache was
removed after validating its absolute path; runtime files are retained. No
one-shot test/migration containers remain. Existing unrelated build directories
and other projects were not removed.

Pre-existing admin `next-env.d.ts` and `tsconfig.json` changes are preserved and
must not be included in feature commits. Local Git commits are not a GitHub
backup. The previous public-repository publication restriction remains unresolved;
no push is authorized through a workaround.

Local implementation commits on `codex/release-hardening-20260908`:

- Backend: `6c55e19`.
- Admin: `91e5dae`.
- Mobile: `9659cfa`.

No physical-device build/install was performed in this step. The installed phone
app must be updated before relying on the new read-only decision checks.

## Next ordered step

1. Reviewed price activation and consistent administrative price writers, with
   accurate active-version display. No HTTP activation is added here.
2. Real factory link/delivery acceptance and updated physical-device offline
   work/decision/earnings acceptance.
3. Full backend/admin/mobile release gates and deployment acceptance. This
   focused step is not a production GO or a 100 percent readiness claim.
