# Confirmed price sync and offline provenance, October 3, 2026

## Scope

This is the next bounded step after `2026-10-03-factory-earnings.md`, not a
production release or permission to activate factory pricing for a company.
No real factory confirmation, price activation or external delivery is performed.

## Implemented

- Installer sync returns a dedicated `factory_prices` object on both cold and
  incremental responses, even if the change cursor has not advanced. It contains
  only the active, receipt-validated company price version, effective time,
  currency and installer work rates. Drafts, merely confirmed but inactive lists,
  client prices, approval tokens and representative contact details are excluded.
- An inactive company returns `null`. The mobile SQLite `sync_state` cache is
  account-scoped and validates/whitelists fields before persistence. An absent
  field from an older server preserves the cache; explicit `null` clears it.
- New door completions and addon facts copy the cached `price_list_id` into the
  existing outbox JSON alongside the execution time. Retries and cold resync
  never replace that evidence with a newer cached version or transmit an earned
  amount. Legacy versionless records remain versionless.
- Both sync command protocols propagate the seen version to the server's
  execution-time price resolver. Historical matching versions remain valid;
  mismatches, missing prices and invalid version IDs are retained as
  `CONFLICT_FACTORY_PRICE` without a completion earning. The first-confirmed-list
  exception for old pre-transition work remains unchanged.
- The mobile queue explains price conflicts in EN/RU/HE and offers neither
  blind retry nor deletion for them. An authorized resolution workflow is still
  a rollout prerequisite; a current/new list must not silently settle the conflict.
- Mobile transport no longer sends four local `previous_*` undo fields. SQLite
  retains them; `previous_version` still supplies the concurrency guard. The
  server tolerates these local-only fields from older builds and normalizes them
  for duplicate comparison without accepting monetary/approval overrides.
- Batch queue replay can no longer overwrite original work, quantity, execution
  time or price evidence under the same ID, including failed records. Reused IDs
  with changed commands return conflict without modifying the original row.

## Storage And Compatibility

No schema migration is needed: SQLite already has account-owned `sync_state`
and JSON outbox payloads; PostgreSQL already persists command JSON and execution
times (0066). The cache holds one current version, not an unbounded archive.
Each historical queued operation holds its own immutable version reference, and
the backend retains the authoritative historical prices and earning evidence.

The sync response is additive. Old versionless clients remain supported. The
batch semantic change deliberately rejects reuse of an ID for different work;
it is not a supported way to edit an execution or resolve a price dispute.

## Verification

- Backend: **190 PASS**, 680.29 seconds, on `dimax_acceptance_tests` via the
  existing acceptance Compose image. Selection:
  `test_factory_price_sync.py` (22 new cases), `test_factory_earnings.py`,
  `test_factory_price_timeline.py`, `test_installer_price_authority.py`,
  `test_sync_batch_api.py`, `test_sync_installer_snapshot_api.py`,
  `test_openapi_contract.py`. This is focused regression, not the full backend
  release suite. The image is Python 3.12; Python 3.11 is not separately certified.
- Mobile: final full Vitest run **723 PASS / 49 files**, 60.32 seconds, using
  the installed Node 20 runtime and `vitest run --maxWorkers=1`.
  `tsc --noEmit`, test discovery (49/49), production configuration self-test
  (7 API cases plus Android network/manifest policy), and Expo config PASS.
  Expo resolves DIMAX Installer 0.1.0 / SDK 52. No dependency install was needed.
- Coverage includes late upload, version mismatch without an earning, immutable
  retry after amendments, both sync protocols, batch ID/payload/time reuse,
  retained cold-reset price conflicts, account changes during in-flight sync,
  cache isolation across sign-ins, malformed snapshots, decimal strings and
  removal of confidential/unsupported response fields. Existing tests continue
  to reject installer monetary and approval overrides.
- Final `git diff --check` PASS. Intermediate transport-test/import
  failures were fixed and the relevant full suites rerun; they are not counted
  as successful runs.

Acceptance business checksums exactly match the previous checkpoint:

| Table | Rows | Checksum |
| --- | ---: | --- |
| completed_work | 11 | d972af6ed54536ef21a9d1abc9f1ec2c |
| installer_rates | 8 | 7ffab959007f5746bb9cc74f13fac706 |
| doors | 9 | 23ddc04087c8a06023ce96bc52cb92dc |
| project_addon_plans | 1 | 05d1630d4faf1ed8e44fb61f1ec698b0 |
| project_addon_facts | 1 | ffad0b2f2f4243935a4c215c69d175bc |

The acceptance database still has zero factory lists, approvals, activations and
earning evidence. Test fixtures leave zero activations/evidence in the test DB.
Both schemas remain at `0066_factory_earning_prices`; no fresh-database or
downgrade rerun was needed for this schema-free change.

Only API 8001 was restarted. It is healthy; `/ready` returns database=ready and
`/health` returns status=ok. Live OpenAPI contains the optional installer price
snapshot with exactly the five expected header fields and no price activation
route. An unauthenticated sync POST returns 401. Admin 4173 `/price-lists` returns
HTML/200; this is not an authenticated browser acceptance test. Normal API 8000
and its database were not restarted or modified.

The one-off backend test container was run with `--rm`; a final name-filtered
Docker inventory is empty. Bytecode/pytest cache writes were disabled. No APK,
archive, new database, dependency install or external message was produced.
No phone/native build or admin build was performed for this contract step.
Existing admin `next-env.d.ts` / `tsconfig.json` changes were left untouched.

Local implementation commits: backend `0e85956`, mobile `ef4e839`.

## Next Steps

1. Read-only price presentation in door/addon work cards, including truthful
   missing-price/pending-earnings states and the saved version in queue details.
2. Authorized price-conflict review preserving the original work and evidence;
   reviewed activation with accurate active-version state and writer consistency.
3. Full backend/admin/mobile release gates and physical-phone offline acceptance,
   then controlled HTTPS confirmation/delivery and deployment checks.

Do not mark legacy rates as factory-confirmed or turn on company activation
before these remaining checks. Admin source/config edits from earlier work are
outside this step. GitHub publication remains blocked by the existing public
repository restriction; local commits are not represented as remote backups.
