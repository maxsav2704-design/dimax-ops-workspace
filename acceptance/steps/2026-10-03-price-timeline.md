# Factory Price Timeline And Execution-Time Quotes

## Scope And Architecture

The preceding step added advisory prerequisites. The current payroll writers
still use saved/per-installer door rates and additional-work project plans;
mobile has no confirmed-version price cache. This step supplies the internal
transition/quote engine, not an early switch of those live payroll paths.

Migration `0065_factory_price_timeline` adds company-scoped effective-version
history and an exact company/list/receipt foreign key. It does not create price
versions or decisions, activate a company, modify earning rows, or backfill
completed work. Existing completion/correction APIs, admin and mobile source
remain unchanged. No activation route or UI action is exposed.

Application services own the policy, the existing rates repository owns SQL,
and the existing UOW owns commit/rollback. No extra repository/UOW abstraction
or new external dependency is introduced.

## Implemented

- Internal activation requires an active OWNER/OPERATIONS administrator with
  rate access in the same active company. A company lock serializes factory
  transitions with existing price-version and confirmation mutations.
- The mutation rechecks company-wide preflight, exact factory evidence and
  the latest confirmed version. A pending draft does not displace an effective
  version. Review acknowledgement and a reason are required.
- The request contains the expected active version and a retry UUID, not a
  client price or effective date. Matching retries return their original event
  even after an amendment; changed payloads and stale expectations conflict.
- Effective times come from the server, must follow the receipt and previous
  activation, and cannot be backdated through the DTO. Each list is activated
  at most once. Activation and audit share a transaction and roll back together.
- Execution-time lookup uses the greatest effective time not later than the
  performed time. An older effective version remains valid for work performed
  before the next transition, even when the work uploads later.
- A supplied cached version must match that historical selection. Conflicts
  and missing prices never silently fall back to saved/per-installer/later prices.
- The explicitly classified pre-transition versionless queue uses the first
  confirmed list, which can differ from the first activated list. Missing version
  alone is not permission to backfill uploaded historical facts. `legacy_queue`
  is an internal server-caller policy input, not a mobile price override.
- The first version remains selected when its header or confirmation half is
  damaged; evidence validation then fails closed instead of choosing a later
  amendment. A missing work type in the first list is also an unresolved conflict.
- Historical quotes retain the frozen unit and rate. Later catalog renaming
  does not rewrite them, and an expired sharing link does not expire a recorded
  factory decision. Hash/receipt mismatches prevent quoting a damaged version.
- Quotes carry version, item, receipt, activation and selection evidence. For
  the first-list exception, the activation ID identifies the company cutover;
  the selected list/item/receipt may belong to the earlier first confirmed list.
  This DTO evidence is not yet persisted in an earning ledger row.
- Decimal amounts use HALF_UP at two decimals with finite, positive, bounded
  quantities/amounts. A door quantity must be one. Timezones are normalized to
  UTC; naive or future execution times are rejected by this internal resolver.

There is no update/delete operation for activation history in this service.
This is application-level append-only behavior plus FK/unique/check constraints,
not a database trigger denying all DBA updates/deletes. A downgrade refuses to
discard any recorded effective history. The test fixture explicitly deletes
its own activation rows before removing synthetic companies.

## Verification

Fresh/rollback migration smoke passed in the guarded, initially empty
`dimax_factory_price_migrations` database: empty -> 0062 -> 0063 -> 0064 -> 0065,
with round trips and history-loss guards for each new factory migration. Metadata
comparison passed. A synthetic confirmed transition quoted 300 ILS while the
existing legacy completed-work/rate snapshots stayed at 250 ILS. Other existing
business table snapshots were unchanged. The temporary database was then dropped.
The 0064 smoke excludes only the newly declared 0065 receipt uniqueness constraint
when comparing an intentionally older schema; other metadata checks remain active.

The initial focused engine/transaction run passed 51 tests. A subsequent wider
run stopped on an execution-time test using another live wall-clock sample.
The deterministic test now anchors its old work to the persisted first effective
time and tests both sides of the next boundary. Production time/price validation
was not relaxed. The failed/partial run is not a release PASS.

Final selected PostgreSQL regression: **316 passed**, exit 0, 494.54 seconds.
Includes all 54 timeline cases, existing immutable-draft/confirmation/report/
preflight APIs, additional work, earning corrections and architecture tests.
Time boundaries/timezones, first-list exceptions/missing evidence, retries,
parallel mutations, real foreign admins, amount limits/rounding, tampering,
DB constraints, audit rollback and historical snapshots are covered. This is
selected regression, not the full backend release suite.

Both acceptance and test schemas are at `0065_factory_price_timeline`. The
current acceptance database has zero price lists, approvals and activations;
the test database has zero remaining activations. Current business checksums
still match before and after migration/restart:

| Table | Rows | Checksum |
| --- | ---: | --- |
| completed_work | 11 | d972af6ed54536ef21a9d1abc9f1ec2c |
| installer_rates | 8 | 7ffab959007f5746bb9cc74f13fac706 |
| doors | 9 | 23ddc04087c8a06023ce96bc52cb92dc |
| project_addon_plans | 1 | 05d1630d4faf1ed8e44fb61f1ec698b0 |
| project_addon_facts | 1 | ffad0b2f2f4243935a4c215c69d175bc |

Only acceptance API 8001 was restarted. It is healthy; the final strict
`/ready` check returns `status=ok`, `checks.database=ready`. A price-list
request without authentication returns 401. Live OpenAPI still reports
BLOCKED/REVIEW_REQUIRED/VERIFIED with `affects_earnings=false` and contains no
price-activation route. Normal API 8000/database were not migrated or restarted.
The existing admin preview at `http://127.0.0.1:4173/price-lists` returns HTML/200.

The first post-restart readiness probe received UPSTREAM_UNAVAILABLE during
startup. An inspection assertion then used `database` instead of the actual
`checks.database` property; this check was corrected against `app/main.py`, not
by changing the endpoint. The final strict readiness/401 check passed. Those
failed probes and the partial regression are not counted as successful gates.
One ancillary DB inspection attempted unavailable dblink; no extension was
installed. Direct inspection of the exact QA database confirmed head/one
synthetic activation before its successful removal.

Temporary containers used `--rm`, bytecode/cache writes were disabled, and the
owned migration database was removed. No new APK, archive, dependencies or build
cache was produced. Admin source is unchanged except for the two pre-existing
generated/config edits in `next-env.d.ts` and `tsconfig.json`, which are preserved
and excluded from this step. Mobile is unchanged. Their builds/native tests were
not rerun for this backend-only step. The backend test image uses Python 3.12;
Python 3.11 is not separately certified here.

## Remaining Rollout

1. Persist immutable factory quote provenance on original/correction earning
   records and guard every door/additional-work completion path. Distinguish
   an old queued event from already uploaded unaccrued facts. Never infer the
   first-list exception from absence of a field alone or trust a device amount.
2. Sync readonly effective/historical versions and rates to the mobile SQLite
   cache and outbox. Preserve execution-time evidence across upload, cold resync,
   reassignment and account changes; show explicit unresolved-price conflicts.
3. Only then expose a reviewed activation action in the admin workspace and
   active-version status, with the same server checks at mutation time.
4. Verify amendments, lost acknowledgements, retries, assignment conflicts,
   missing prices, quantities and historical corrections in isolated end-to-end
   scenarios, followed by physical-phone and full release gates.

Legacy per-installer snapshots, project-plan pricing and manual earning-rate
corrections remain open authority paths until step 1 is integrated. This engine
does not claim to close those production risks by merely existing. Factory
receipt bearer links also still need controlled delivery/HTTPS and verified
contacts; clocks must be synchronized in deployment. Catalog/work-plan writers
must participate in rollout consistency checks before live activation is enabled.

No real factory decision, external email/WhatsApp, native build or financial
change in the current acceptance company is authorized by this checkpoint.
No complete production readiness is claimed. Backups are local only while the
existing public-remote publication restriction remains unresolved.

Local backend implementation/migration/tests/checklist commit: `52f31e0`.
Admin remains at `f38d109` with its prior config edits; mobile remains at `f5eaeae`.
