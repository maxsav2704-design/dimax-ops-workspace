# Installer price authority and factory-confirmed common price list

## Agreed business rule

The owner clarified that the factory supplies the price, an administrator enters
it, and the factory representative confirms the exact version through a personal
link. The price list is common to all projects. It can be changed by request and
agreement with the factory, not by an installer and not by silently editing an
already confirmed version. A pending replacement does not displace the active
confirmed version. Mobile displays read-only confirmed rates and calculated
earnings after work, including fractional additional-work quantities.

In the preceding phone test, 1.50 was the quantity entered by the installer;
9.00 ILS was a test rate set through the administrative service. That test proved
offline work and exactly-once payroll, NOT factory approval of a price.

## Actual code before this step

- Installer requests contain work/status/quantity, not writable price fields.
- The server obtains door rates through installer_rates and add-on prices from
  an administrative project plan. Completion stores historical rate snapshots.
- Rate/catalog/plan/correction routes require an administrative role/scope.
- Unexpected financial fields in installer bodies were silently ignored rather
  than rejected. They did not control the server's price, but the API could still
  report success for a request pretending to set or approve a price.
- Base door rates are scoped to installer/type, while add-on prices are scoped
  to a project. This is NOT yet the common factory-confirmed price-list model.
- There is no price-list confirmation link, factory approval version/history or
  approval gate on price activation. Mobile does not yet receive a complete
  confirmed price list before work. These are open release requirements.

## Current bounded implementation

PASS for input authority only, backend commit `1085d68`:

- AddFactBody and installer door work schemas reject extra fields. Body-less
  installation still accepts no body or an empty object; injected fields return
  422. The mobile/web installer callers already send supported command fields.
- Sync applies explicit work-payload allowlists before executing door/add-on
  events in both sync formats. Invalid commands use the existing per-event/item
  conflict contract rather than setting a price or a factory-approved flag.
- Integration cases verify direct add-on, direct door/status, sync and batch
  rejection with no fact, status/lock/rate change or completed-work accrual.
- A real installer JWT is denied seven administrative mutations: rate create,
  update, delete, bulk price change, add-on catalog/plan and payroll correction.
- Contract tests check price/amount/surcharge/approval fields individually, plus
  valid fractional quantities and existing version fields.

The guard supplements existing server-side price calculation; it does not fix
an observed ability to set one's own rate. Before it, unsupported fields were
ignored and some of these requests reported success at the server-owned rate.

No schema migration, real price edit, earnings correction or automatic approval
of existing prices was performed. This does not implement the missing common
price-list/confirmation/activation workflow described below.

## Verification and preservation

- Final regression: **169 passed**, 255.82 s, exit 0: test_addons_api,
  test_admin_access_and_validation, test_sync_batch_api, test_payroll_lifecycle
  and tests/architecture. The legitimate work/payroll cases pass alongside the
  new input/role checks. This is not the full backend release gate.
- Tests used `dimax_acceptance_tests`, no pytest cache/bytecode, one check process
  at a time, existing local image and auto-removed test containers.
- No admin/mobile source or UI was changed, and no new native workflow or
  admin/mobile build is claimed. The prior phone payroll test remains separate.
- No APK, database export or extra dependency tree was created. Existing unrelated
  admin generated-file changes were preserved. `git diff --check` passed.
- Only the isolated acceptance API was restarted; host `/ready` returned 200
  with database ready after restart. The normal API/database were not restarted.
- Commits are local only, with no GitHub push/remote backup in this step.

## Ordered remaining implementation

1. Add a company-wide versioned price-list model and Alembic migration. Keep
   existing financial snapshots. Inventory current installer/project differences
   for administrative reconciliation; do not choose or approve a price silently.
2. Add admin draft/version controls, change-request/reason and agreement reference,
   and a factory-representative recipient.
   Create revocable, expiring confirmation links with hashed secrets, bounded
   public access and no unrelated company/project/payroll data exposure.
3. Show the exact version/line prices to the representative. Require an explicit
   POST confirmation, bind it to that immutable version, serialize concurrent
   decisions, reject stale/revoked links and make repeated confirmation harmless.
   Record the recipient, decision and time. Link access is not a journal signature.
4. Activate only the confirmed version across door rates and add-on work; remove
   alternate unconfirmed project overrides. Preserve old confirmed terms and
   completed-work snapshots. Define work-time/version handling for offline events
   and surface any pending-price work without inventing earnings or losing facts.
5. Publish read-only confirmed rates/version to the native offline cache. Connect
   admin and public confirmation UI, then verify factory -> admin -> phone ->
   completion -> earnings end to end with synthetic data and local delivery.

Until these steps are verified, do not label current administrative rates as
factory-approved or this business process as implemented/100% ready. Existing
source and native payroll test passes do not prove these new requirements.
