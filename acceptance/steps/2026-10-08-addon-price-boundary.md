# Additional work price boundary

## Scope

Continue the individual-rate boundary checkpoint, without activating factory
pricing for a real company. Existing strengths reused: company activation lock,
execution-time factory quotes, immutable completed-work snapshots, UOW rollback,
rate access checks, and the shared admin pricing-state query.

The gap was a mismatch between earning calculation and editable planning prices.
Factory-mode completion already ignored legacy addon plan prices, but admins
could still edit them and create manual urgency amounts. The plan read models
continued displaying those legacy amounts as though they controlled earnings.

## Implemented

- All addon price writers acquire the company lock before inspecting mode.
  Concurrent activation cannot leave a legacy write accepted after cutover.
- In factory mode, plan writes omit `installer_price`; quantity, client price and
  notes remain editable. An existing legacy price is retained unchanged; a new
  plan's unused legacy price is zero. Supplied manual prices return HTTP 409 with
  reason `FACTORY_ADDON_PRICE_REQUIRED`, even when sent through the older API.
- Creating a catalogue work type remains possible with a zero legacy default.
  A nonzero manual installer default is rejected after activation. A new type
  still needs inclusion in a factory-confirmed price version before it is paid.
- New manual urgency rows are rejected in factory mode with reason
  `FACTORY_URGENCY_REQUIRES_ADDON`. Use an additional-work type with a confirmed
  factory price for payable urgency work. Existing rows remain readable; there
  is no migration, automatic conversion, deletion or new earning from them.
- Admin catalogue and plan reads use the validated effective factory snapshot.
  Missing prices return null, never a misleading zero or a legacy fallback.
  Stored legacy prices are not overwritten with a new factory version.
- Factory-mode addon summary payroll uses the completed-work ledger, including
  reversals/corrections, rather than done quantity multiplied by today's price.
  Earned totals remain visible even if the project plan is removed. Legacy-mode
  summary behavior and client-revenue calculations are unchanged in this step.
- A batch checks tenant ownership of every addon type and rolls back the whole
  transaction on an invalid item. Plan request models are separate from response
  DTOs and validate nonnegative quantity/prices and supported decimal precision.
- Admin project forms use the existing shared pricing-state hook. Factory prices
  are read-only; loading/error states lock writes; a stale rejected write refreshes
  mode without replaying the operation. The form retains entered work scope.
- Projects and report plan tables show missing confirmed prices explicitly and
  do not display an incomplete installer total as a complete zero-based sum.
  Explanations and conflict errors are available in EN/RU/HE.

## API compatibility

URLs and legacy-mode successful payloads remain unchanged. Before activation,
omitting the installer plan price still yields 422. After activation, omit it
(or send null); any explicit amount yields 409. The catalogue default accepts
zero as an unpriced placeholder, not as a confirmed factory price.

In admin addon read DTOs `installer_price` / `default_installer_price` can now be
null for work missing from the active list. Consumers must distinguish missing
prices from zero. Both admin consumers were updated. Installer/mobile endpoints
were not changed; existing earning ingress tests cover direct and offline sync.

## Verification

- Initial PostgreSQL regression: 82 PASS (173.02s), covering this boundary,
  existing addon APIs and all factory earning ingress paths.
- Extended PostgreSQL regression: 41 PASS (115.70s), including 21 boundary tests
  plus existing admin access/validation tests. Across both runs: 106 distinct
  tests. Additional checks cover concurrent catalogue/urgency writes, damaged
  confirmation evidence, atomic batch rollback and earnings without a plan.
- Initial admin regression: 71 PASS (229.59s). Final expanded admin regression:
  83 PASS across five files (189.37s), including absent-price totals, background
  refresh, stale form rejection, real pricing-hook auth reset and EN/RU/HE errors.
  An intermediate run found a stale text assertion and a one-second fixture wait;
  the text expectation was updated and the asynchronous report assertion retains
  its exact checks with a five-second deadline. Changed-file ESLint PASS.
- Restarted acceptance API: `/ready` reports database ready; OpenAPI exposes the
  separate validated plan request model and nullable read prices.
- Read-only financial check remains 11 works / 1513.50 ILS / row digest
  `873b5115c8e2e320f325b1b8ff7ad96e`, unchanged from the previous checkpoint.
- Production build PASS: Next.js 16.2.11 webpack, TypeScript, all 26 static pages,
  exit 0. Output: `.next-acceptance/addon-price-20261008`.
- Local admin runs the generated standalone `server.cjs`, with static/public
  assets copied as in the repository Dockerfile, on `http://127.0.0.1:4173`.
  `/login`, `/projects`, `/price-lists` and all four root-main JS assets return
  HTTP 200. Runtime stderr is empty. No authenticated live financial write was
  used for this smoke check; form interactions are covered by component tests.
  This is not native-phone or browser pixel-level visual acceptance.
- Only the new build cache was removed after resolved-path/reparse-point checks:
  268575767 bytes. Runtime retained. Build-added config paths were removed while
  preserving both pre-existing uncommitted admin configuration changes.

## Remaining and limits

Next: audit shared financial forecasts, report SQL and exports that still read
individual rates, door snapshots or historical urgency plans. Separate today's
planned costs from historical earned snapshots. Updating the addon plan tables
does not make the entire reports module factory-rollout ready.

Keep activation internal until that audit is complete, then finish the reviewed
activation API/UI and deployment gates. Real representative confirmation-link
delivery and native phone release checks are not certified by this step.

No real approval, activation, completed work, email or WhatsApp message was
created. Tests use the isolated `dimax_acceptance_tests` database. No dependency,
APK or migration is required. Pre-existing admin `next-env.d.ts` / `tsconfig.json`
changes are preserved and excluded from this step's commits. Mobile is unchanged.

Implementation checkpoints: backend `617bb0c`, admin `c1129f0`. This report and
the protocol reference are saved in a separate root documentation commit.
Checkpoint uses local commits only.
GitHub publication remains restricted by the
previous public-repository decision; no push or publication workaround.
