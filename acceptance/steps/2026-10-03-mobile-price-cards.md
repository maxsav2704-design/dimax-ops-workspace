# Read-only mobile price cards, October 3, 2026

## Scope And Business Rules

The next bounded step after `2026-10-03-mobile-price-sync.md`: expose the existing
installer price cache in project execution cards. This is not activation of the
factory-price workflow, native-device acceptance or production release approval.
No price entry, factory confirmation, invitation or external delivery occurred.

## Implemented

- Door/addon cards use the existing account-owned `factory_prices` cache. An
  installer sees a saved confirmed version and work rate, never an editable price.
  The displayed addon unit comes from the confirmed price item; catalog-unit
  mismatches show a warning rather than a misleading total.
- Addon quantity previews use integer minor units and HALF_UP, including decimal
  comma entry. Invalid, unsafe/overflow and zero-result amounts are not shown as
  valid estimates. The result is explicitly preliminary, never an accrued amount
  or an extra command field. Original action arguments/contracts are unchanged.
- Installed doors link to project earnings. We deliberately do not infer a
  historical door earning by label: the existing earnings rows do not provide a
  stable door ID, and labels can repeat. Today's price never fills that gap.
- Pending/failed/blocked completions take priority over the locally installed
  status. They link to the queue and show saved-version availability without
  recomputing from a newer list. An unacknowledged upload is described as not yet
  confirmed on the device, not proof that the server never processed it.
- Loading, absent cache, damaged cache, future effective date and missing work
  rate have distinct presentations. Legacy rates are not labelled confirmed and
  a missing rate is not displayed as zero. Existing work-recording rules remain.
- Project data and prices are loaded under the existing workspace/account guard,
  with a final session assertion. A price-only read error keeps door data usable;
  a changed session is rejected, not swallowed as a missing price.
- Queue technical details include original execution time and seen list ID;
  absent legacy evidence is explicit. Price conflicts still have no blind retry
  or discard control. This step does not resolve or rewrite those conflicts.
- EN/RU/HE copy follows the existing mobile design primitives and theme. No new
  UI dependency or animation framework. A confirmed 320px RTL field-overflow bug
  was fixed by allowing the addon-comment input to shrink inside its row.

## Verification

- Mobile full Vitest suite: **767 PASS / 50 files**, 80.97 seconds, Node 20,
  `node_modules/vitest/vitest.mjs run --maxWorkers=1`. A focused final calculation
  rerun additionally checks the backend's positive-result requirement: 31 PASS.
- `tsc --noEmit`, test-discovery contract (50 files), production-config self-test
  (7 API cases plus Android network/manifest policy), Expo public config PASS.
  Expo resolves DIMAX Installer 0.1.0, SDK 52. Dependencies were not installed.
- Coverage: readonly rates, quantity calculation/rounding, zero/overflow guards,
  unit mismatch, stale-version conflicts, legacy records, account changes,
  damaged cache, completed-work navigation, addon selection and RU/HE labels.
- Earlier new-test failures were traced to a closed confirmation modal retained
  by the native test mock, then corrected to test visible controls. The related
  mock element type was corrected for TypeScript. Failing runs are not PASS.
- Browser checks use the real screen components with isolated in-memory Vite
  fixtures, no API/authentication/SQLite. Verified actual CSS viewport widths
  320, 391 and 480px (browser scaling means requested outer sizes differ).
  RU/HE decimal input `1,50` / `1.50` at a synthetic rate 9 gives 13.50 ILS.
  Missing prices show no invented amount. Completed-door navigation retains the
  project ID; a conflict navigates to `/sync-queue`. Preview navigation records
  the route only; it is not a native end-to-end navigation test.
- Screenshots and DOM bounds confirm readable price bands, no horizontal page
  overflow, corrected input containment and wrapped full price UUID at 320px.
  No browser console errors on the inspected queue page. Existing RN-web shadow,
  pointer-event and native-animation fallback warnings remain preview-only.

## Data, Storage And Limits

No API, PostgreSQL/SQLite schema or migration changes. Backend and admin builds
were not rerun for this mobile-only step. Backend remained clean; pre-existing
admin `next-env.d.ts` and `tsconfig.json` edits were preserved. No phone, APK or
real offline-sync acceptance was performed and no company pricing was activated.

Preview: `http://127.0.0.1:4188/project.html`. Project fixture scenarios use
`?prices=missing`, `?prices=unavailable`, or `?prices=conflict&doorId=door-201`.
Queue conflict fixture: `/sync-queue.html?prices=conflict`. All are preview-only
aliases. Small QA logs/screenshot are under ignored `mobile/.tmp/price-card-preview`;
no archive, database copy, installer or package cache was added.

GitHub publication remains blocked by the existing public-repository restriction.
Local commits are not represented as remote backups.
Mobile implementation commit: `0e44837`.

## Next Ordered Step

1. Authorized price-conflict review preserving original work, execution time and
   confirmed price evidence. No installer override or silent use of today's list.
2. Reviewed activation, consistent admin price writers and accurate active-version
   UI; do not expose activation before these prerequisites are complete.
3. Full backend/admin/mobile release gates, then physical-device offline tests
   and controlled HTTPS factory confirmation/delivery/deployment acceptance.
