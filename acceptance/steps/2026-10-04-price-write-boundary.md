# Individual rate cutover boundary

Completed on 2026-10-08 after resuming the interrupted verification.

## Scope and findings

The preceding audited conflict-resolution step is complete within its documented
checks. This step prepares rollout by closing one concrete inconsistency: the
individual-rate APIs still allowed writes after factory pricing became effective,
even though completion already ignored those rates. Such writes created a false
expectation of changed earnings and could destroy useful legacy-rate history.

Existing strengths retained: immutable earning evidence, execution-time price
selection, company-level activation lock, live role checks, UOW transactions and
the factory-confirmed version history. No migration or mobile change is needed.
Activation is still internal; no real company was switched to factory pricing.

## Changes

- `FactoryPriceTimelineService.require_legacy_rate_writes` takes the same company
  lock as activation before examining mode. All four individual-rate service
  entry points use it: create, update/reschedule, delete and bulk set/delete.
- After any activation they return HTTP 409 with reason `FACTORY_PRICES_ACTIVE`.
  A damaged approval cannot reopen legacy writes. No rate or earning is changed.
  Companies not yet activated retain their existing individual-rate API behavior.
- `GET /api/v1/admin/price-lists/state` is an additive, tenant-scoped, rate-protected
  read. It validates the effective confirmation and returns the effective version,
  not the highest draft or merely confirmed version. Invalid evidence fails closed.
- The price-list screen shows the actual mode/version/date, defaults to the active
  version and distinguishes "confirmed" from "currently effective". The former
  unconditional "not yet applied" notice was removed because it is false after
  activation. Opening a version does not activate it.
- The installer card retains individual rates as read-only history in factory
  mode and links to the active company list. Installer profile editing remains
  available to its existing authorized roles. Rate changes are disabled while
  mode is loading or cannot be checked; retry and localized cutover errors are
  available. A rejected stale write refreshes mode instead of retrying the write.
- The shared pricing-state query is cancelled/discarded on authentication change.
  No state request is made without rate access. EN/RU/HE strings are provided.

## Verification

- PostgreSQL: 75 PASS, 125.50 seconds, covering the new boundary, existing
  individual-rate API flows and the effective-price timeline. Tests include all
  six write variants, unchanged historical rows/earnings, confirmation versus
  activation, invalid evidence, real JWT read scopes, tenant separation and a
  write waiting for concurrent activation to commit.
- Admin: 38 distinct tests PASS, with the final 15 price-page tests rerun after
  adding the selected-version status. Includes existing installer behavior,
  pending/error/retry states, stale writes, auth change, active-version navigation
  and localized status/error strings. Changed-file ESLint PASS.
- Browser: real price-list page/CSS with synthetic read-only API data, RU at
  1288 CSS px and HE at 396 CSS px. No horizontal overflow; active-version action
  returns from v2 to v1 without changing effective prices. Narrow RTL header and
  table inspected. No console errors. This is not authenticated end-to-end or
  physical-device acceptance. Screenshots are ignored local artifacts.
- Production build: PASS on 2026-10-08, exit 0. Next.js 16.2.11 webpack build,
  TypeScript validation and all 26 static pages completed. The isolated output
  remains `.next-acceptance/price-mode-20261004`; no dependency install was needed.
- Local runtime: the existing acceptance services started with `--no-build
  --pull never`. API `/ready` reports database ready; OpenAPI includes the state
  GET; an anonymous state request returns 401. No price-list activation POST is
  exposed. The built admin `/login` at `http://127.0.0.1:4173` returns HTML 200.
  Local preview uses `next start`, which warns about `output: standalone`; this
  smoke check does not certify the standalone production deployment command.
- Financial read-only check: 11 completed works, total 1513.50 ILS, row digest
  `873b5115c8e2e320f325b1b8ff7ad96e`, unchanged from the preceding checkpoint.
  Regression tests above passed on October 4; October 8 repeated the production
  build and runtime checks, not the complete backend/admin/mobile test suites.

## Remaining before activation can be exposed

1. Addon plan/default price writers: `AddonsUseCases.admin_create_addon_type`,
   `admin_set_project_plan` and `admin_set_project_plan_batch` still accept legacy
   installer prices. Keep quantity/client-price planning useful without suggesting
   an unapproved installer-price override. Factory completion already ignores
   those legacy values; their editing/read models still need alignment.
2. Urgency surcharge entry still accepts installer amounts. These must not become
   an alternative unconfirmed earning path; settle the UI/data contract as part
   of the addon writer step, without inventing logistics or extra business rules.
3. Forecast/report queries still use legacy rates or door snapshots in several
   places. Distinguish historical earned totals from current projected costs using
   the confirmed timeline. Do not claim these reports are rollout-ready yet.
4. Only after these checks: reviewed activation API/UI, then real factory-link
   delivery, updated phone offline scenarios and full release/deployment gates.

## Safety and checkpoint

No approval, activation, real earning, email or WhatsApp delivery was created.
Tests use `dimax_acceptance_tests`; browser fixtures never call the real API.
The temporary UI server and source/cache directory were removed after exact
process/path verification. The final build's cache alone was removed after
resolved-path/reparse-point checks (276661616 bytes); runtime output was retained.
Build-added changes to admin `next-env.d.ts` and `tsconfig.json` were restored to
their pre-step contents, preserving the pre-existing unstaged changes. These two
files are not part of this step's commits. No APK or dependency installation was
produced; the mobile repository and physical phone were not changed or retested.

Local implementation commits: backend `834775b`, admin `11130ae`. This checkpoint
and its protocol reference are saved in a separate root documentation commit.
GitHub backup remains blocked by the
previous public-repository publication restriction; no push or workaround.
This selected regression is not a full backend/admin/mobile release certificate
and is not a 100 percent production-readiness claim.
