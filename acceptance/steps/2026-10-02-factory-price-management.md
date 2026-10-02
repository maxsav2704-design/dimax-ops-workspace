# Admin factory price-list management

## Scope And Architecture

This bounded step adds the administrative workspace for the existing 0063/0064
price-list and invitation APIs. The current Next.js application, authenticated
admin layout, role helpers, API client, shared controls and brand tokens are
reused. No backend API, database schema, payroll or mobile implementation changed.
Factory confirmation still records a decision only; it does not activate rates.

The gap was an absent admin workflow: drafts and invitations could be managed
through API calls, but not through a normal administrative screen. `/price-lists`
now provides that workflow in RU/EN/HE, with a sidebar entry and RTL support.

## Implemented

- Version list and details, paginated decision/invitation history, explicit
  statuses, agreement/reason fields, refresh/loading/empty/error states.
- Create the initial draft or copy a selected version into a new immutable
  version. The editor loads all active installation/add-on catalog entries,
  rejects duplicate/missing/invalid rates, and does not prefill legacy add-on
  defaults as if they were factory prices. Removed catalog entries require an
  explicit decision in the editor, not silent omission.
- Decimal input accepts comma or dot, serializes exact two-decimal strings and
  does not round floating-point input into money. Creation uses a request UUID
  and the expected latest version. An uncertain response locks the original
  payload for an explicit same-request retry. A conflict never silently rebases.
- Explicit-reason draft cancellation and invitation revocation. Invite a named
  factory representative for the latest draft, with an expiry and acknowledgement
  that replacement invalidates the earlier link. No confirm-as-factory action.
- The one-time link can be copied or selected manually. Its secret remains in
  dialog state only, not browser storage or query data. History never recovers
  the secret. A lost issuance response asks the admin to inspect history rather
  than silently issuing another link. No email or WhatsApp delivery was added.
- OWNER/OPERATIONS with rate access can manage prices. FINANCE with rate access
  can read them. VIEWER, installers and users without rate access are denied.
  Server authorization remains authoritative; the UI does not broaden it.
- Financial query data uses a workspace-local QueryClient and is cleared on
  unmount. An authentication-change event remounts the workspace, removing open
  forms, responses and invitation secrets. This is deliberately fail-closed.
- History refresh detects a factory decision and refreshes version status.
  The screen explicitly distinguishes confirmation from future price activation.

## Verification

- Final selected Vitest regression: **71 passed in 6 files**, 49.75 seconds,
  exit 0. Covers amounts/catalog pagination, scopes/navigation, initial draft,
  copy/retry/conflict behavior, cancellation/revocation, one-time links,
  uncertain issuance, session change and the existing public confirmation page.
  The management component suite also runs under React StrictMode.
- Changed-file ESLint: PASS, no warnings. Production Next.js webpack build and
  TypeScript: PASS, 26 generated pages including `/price-lists`.
- **6 Playwright tests passed**, exit 0, 4.0 minutes: a mocked admin draft,
  revoke/reissue and factory-decision workflow in separate browser contexts;
  RU/HE FINANCE read-only views at 390px; existing public confirmation cases
  at desktop/RU/HE mobile widths. Screenshots inspected: no clipped amounts,
  text overlap or page overflow; Hebrew direction is correct.
- Browser APIs were mocked. No real company draft, invitation, factory decision
  or external message was created. These checks do not replace a live end-to-end
  factory/phone/payroll acceptance run.
- The Windows test server did not finish teardown promptly after the cases.
  Its owned Next.js PID was verified and stopped; the runner then exited 0.
  Existing `next start`/standalone-output and terminal-color warnings remain;
  this local run does not certify the production launch configuration.
- Reused the existing `.next-acceptance-preview` build directory and dependencies.
  Replaced only the verified prior local preview process. The admin remains at
  `http://127.0.0.1:4173`, connected to isolated API 8001. `/price-lists` returned
  HTTP 200 and API `/ready` returned database-ready. The normal backend was not
  restarted or migrated. Backend/mobile release suites were not rerun because
  their implementation was not changed by this step.
- Read-only acceptance DB check: revision `0064_factory_price_approval`, zero
  factory price lists and zero invitations. `completed_work` still has 11 rows
  and checksum `d972af6ed54536ef21a9d1abc9f1ec2c`, matching the prior checkpoint.
  The other four historical business-table checksums were not rerun this step.
- No dependencies, APKs, archives or databases were added. The inspected owned
  browser-test output was removed (7 files, 302812 bytes). Existing unrelated
  outputs were preserved. Pre-existing `next-env.d.ts` and `tsconfig.json` changes,
  including generated build-path updates, remain outside the feature commit.

## Remaining Work

1. Reconcile legacy per-installer/project rates with the proposed common price
   list, without manufacturing approval or changing historical earning snapshots.
2. Connect confirmed-version activation, previous-active-version retention during
   amendments, server-calculated earnings and read-only mobile rate sync. Define
   and verify the treatment of work queued offline during a version change.
3. Configure HTTPS and controlled delivery to a verified factory contact. The
   personal link is a bearer capability, not independent proof of identity.
   Localhost links cannot be used by an external representative.
4. Complete live cross-client and full release gates. New prices must not be
   advertised as active, and legacy prices must not be called factory-approved.

The admin can inspect/copy versions individually; a side-by-side price difference
view is not yet implemented. A shared authentication-change event also fires on
token refresh, so the conservative workspace reset can discard an unsaved form
or a displayed one-time link. This usability limitation remains explicit rather
than weakening account-switch isolation. Existing shared dialog close text is
not localized by this narrow module change.

Admin implementation/test commit: `41ac9ee`. Backend checklist-only commit:
`19156d5`; backend runtime remains unchanged from `e7851c7`.
All commits for this step are local only. The prior public-remote restriction is
unresolved; no GitHub backup is claimed. Overall production readiness is not
advanced to 100% by this administrative UI step.
