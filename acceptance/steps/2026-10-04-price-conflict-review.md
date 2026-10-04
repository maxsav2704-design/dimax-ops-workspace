# Read-only price conflict review, October 3-4, 2026

## Scope

The next bounded step after mobile price cards: let an authorized administrator
inspect a retained price conflict without changing the command or earnings.
This does not settle, retry, discard or approve a work record. Factory approval
and internal activation rules are unchanged; no activation HTTP route was added.

## Implemented

- Additive GET `/api/v1/admin/sync/price-conflicts/{source}/{item_id}` for
  `sync_event` and `sync_queue`. Company-scoped repositories, existing admin
  scope enforcement and live `can_view_rates` verification protect the read.
- A focused application service and DTO retain the device execution time,
  server receipt time, original seen price version and quantity. Missing time
  is not replaced with receipt time. Raw command data and signing tokens are
  not returned by the new endpoint.
- Reuse the existing confirmed-price timeline for a comparison at execution,
  never today's price. Versionless pre-transition work uses the agreed first
  confirmed list. Invalid quantity, missing work/price, unit changes and
  unverifiable confirmation have explicit outcomes; unavailable money is not 0.
- The comparison uses the current catalog work type. It does NOT prove that
  the original type, assignment, state, quantity or timestamp are acceptable.
  `resolution_available` is always false; the UI states this limitation.
- Add `status=price_conflict` to the existing problem list, applying the filter
  to both SQL sources before limits/counts. Existing status semantics remain.
  Legacy factory-price errors now have a specific diagnosis and no blind retry.
- The Operations page offers a price-review dialog instead of a misleading
  cold-resync action on price-conflict cards. Server-authorized rates and the
  calculated comparison are not editable or labelled as accrued earnings.
- EN/RU/HE labels, loading/error states, read-only refresh, responsive/RTL layout,
  original identifiers and close controls. Permission loss hides loaded prices;
  a session change closes the dialog; an unfinished request is aborted and query
  data is not retained after unmount.
- Added an optional translated close label to the shared dialog primitive,
  preserving the default for existing callers.
- Fixed five pre-existing Testing Library type errors in calendar/price tests:
  ByRole does not accept `exact`; string names are already exact. Two initial
  calendar data-loading assertions now wait up to five seconds, not one.

## Verification

Initial focused backend run: 21 PASS, including all four door/addon and legacy/
batch combinations, correct historical quote, unchanged commands and no new
earnings/facts, missing evidence, rate permission and SQL filtering before limit.

Final selected frontend coverage: 75 unique PASS across Operations (15), access
rules (14), price list/reconciliation (25), calendar (10), and review dialog (11).
The final dialog rerun includes cancellation of an unfinished request. Initial
worker startup and calendar-loading timeouts are failures, not PASS; isolated
reruns completed successfully. TypeScript and changed-file ESLint passed before
the production build. No interrupted run is counted as a release gate PASS.

Browser inspection used the real dialog and CSS with synthetic in-memory data,
no API or database. RU/HE tested at actual CSS widths 268/322/859, including
long identifiers, scrolling, closing, reopening and removal of the overlay.
No horizontal overflow was found. This is not authenticated end-to-end or native
phone acceptance. Small QA artifacts are ignored by Git.

An expanded backend regression stalled and was interrupted/stopped; its partial
output is not PASS. A shorter real-JWT/company-isolation run and a separate
production build are tracked in the final verification section below.

## Final Verification

- Real JWT/scope/tenant checks: 8 PASS / 14 deselected, exit 0. Combined with the
  initial focused run, 27 unique backend checks passed. The broader interrupted
  regression is NOT declared complete.
- Both production Next/webpack builds completed successfully, including the
  final request-cancellation code, TypeScript, 26 static pages and route traces.
  Output: `.next-acceptance/price-review-20261004`; its generated build cache was
  removed after success. Required runtime assets and the standalone output remain.
- Only the identified DIMAX preview on 4173 was replaced (current PID 19016).
  The admin is built against acceptance API `http://127.0.0.1:8001`, not another
  project's API. `/login` returns 200; a fresh browser tab renders correctly with
  no browser-console errors. The user's existing login form was not reloaded or
  submitted, and its entered values were not changed.
- Acceptance API restart had a prolonged cold startup with temporary 502s.
  Final `/ready`: status `ok`, database `ready`; OpenAPI includes the new route;
  anonymous access to it returns 401. No test containers remain.
- Local preview still uses the repository's `next start` convention, which emits
  a warning for `output: standalone`; production deployment must use the packaged
  standalone entrypoint. Local 200 responses do not certify production packaging.
- Local commits: backend `3d8ffa2`; admin test repairs `132a467`; admin review
  feature `44a2895`. No GitHub publication was attempted.
- Temporary UI server stopped, browser tab closed and viewport reset. Fixture
  sources and generated Vite cache removed; retained screenshot/logs total
  approximately 52 KB, plus the small current preview logs.
- Mobile remains unchanged. No native-device or full-release acceptance here.

## Data And Release Boundaries

No schema or migration change; no mobile code change; no production price,
approval, activation, earning or work mutation was requested. Integration tests
use only `dimax_acceptance_tests`. Existing admin `next-env.d.ts` and
`tsconfig.json` changes are preserved and excluded from commits.
The build's additional generated route-type paths were removed afterward,
restoring those two files to their pre-step contents without reverting user edits.

No external delivery or GitHub push. The earlier public-repository publication
restriction remains unresolved; local commits are not a remote backup.

## Next Ordered Step

1. Authorized, audited resolution of retained work: immutable original command,
   explicit decision/evidence, all assignment/state/quantity/duplicate checks,
   idempotency and transactional earning creation. Do not turn this comparison
   quote into an automatic replay or silently substitute another version.
2. Reviewed activation and consistent administrative price writers, followed by
   accurate active-version UI and real factory-confirmation acceptance.
3. Full backend/admin/mobile gates, physical offline-device tests, controlled
   delivery and deployment acceptance. No production GO or 100% claim here.
