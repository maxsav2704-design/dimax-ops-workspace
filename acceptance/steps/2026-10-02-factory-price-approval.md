# Factory price confirmation by personal link

## Scope

This step extends the company-wide price-list drafts with factory invitations,
explicit version-bound confirmation and a public RU/EN/HE page. It does not
activate new prices, replace the legacy payroll paths, deliver external messages
or roll out approved prices to mobile. No real factory decision was simulated
in an operational company. The full price-authority requirement remains open.

## Implementation

- Migration `0064_factory_price_approval` adds invitation/decision history and
  permits CONFIRMED price-list versions. Tenant-parent foreign keys, metadata
  consistency checks and partial unique indexes protect pending/confirmed
  invitations. Downgrade locks the affected tables and refuses to discard history.
- Authorized admins issue a link for a named factory/contact/email, list prior
  invitations and revoke pending ones with a reason. Reissuing revokes the old
  invitation. The lifetime is 1-168 hours, default 72 hours. Only the latest DRAFT
  version can receive a new invitation; confirmed decisions cannot be revoked.
- Secrets are 32 random bytes, with only SHA-256 hashes stored in the database.
  The secret is returned once in a URL fragment, never exposed by history, and
  the public page removes the fragment from browser history after reading it.
  Public requests use POST bodies, omit credentials/referrers and bypass caches.
- The invitation freezes the complete price-list snapshot. Preview/confirmation
  verify both frozen and current content against its digest, version and tenant.
  Public output contains work names, units, rates and agreement metadata, not
  project, installer, payroll, target UUID or recipient-email data.
- Opening/previewing never confirms. Explicit consent, the displayed version/
  digest and a name are required. One tenant lock serializes issuance, rotation,
  draft changes, revocation and decisions. A same-name repeat returns the original
  receipt; a different name conflicts. Decision and version status commit together.
  The external decision is recorded against the invitation, not falsely attributed
  to the issuing administrator as its signer.
- The public page distinguishes installation from additional work, supports RTL,
  loading/expired/changed/throttled/error states and an ambiguous-response check.
  After a lost confirmation response, it previews the recorded result instead of
  automatically replaying the confirmation. Requests have a 30-second timeout.
- Fixed an existing draft/audit mismatch: reasons allow 1000 characters, but the
  audit summary column allows 500. Full reasons remain on the version and in
  structured audit data; only the summary is shortened. Long valid reasons no
  longer fail the whole transaction.

## Verification

- Final selected backend regression: **225 passed in 312.91 seconds**, exit 0.
  Includes factory drafts/invitations, actual JWT admin scopes, installer denial,
  revocation vs confirmation races, explicit-consent validation, lost/repeated
  requests, stale/tampered/expired links, rollback, payroll, add-ons, batch sync,
  OpenAPI and architecture. This is not the full backend release gate.
- Guarded disposable-database migration smoke passed: full clean chain through
  0064, legacy data preservation, downgrade/re-upgrade, ORM metadata agreement,
  and rejected downgrade when invitation history exists. The disposable database
  `dimax_factory_price_migrations` was removed afterward.
- Final frontend component tests: **8 passed in 2 files**, 19.32 seconds, including
  existing customer acceptance-page coverage. Added a regression for reopening
  the same fragment link, which previously could clear the view without reloading.
  Changed-file ESLint passed without warnings.
- Final Next.js production build with webpack and TypeScript passed, generating
  25 pages including `/price-approval`. Reused `.next-acceptance` and the existing
  Node/dependencies. No dependency install or APK build. `tsconfig.json` retains
  its pre-existing local changes; Next regenerated the already-modified
  `next-env.d.ts` route-types path for this output. Neither is in the new commit.
- **3 Playwright tests passed**, 38.7 seconds: EN at 1280px, RU and HE at 360px.
  Verified no page overflow, RTL, secret removal, disabled submit until consent,
  exact-version submission and a confirmation receipt. All three screenshots
  were inspected: no overlapping text or clipped prices. Responses were mocked;
  this does not claim a real factory's decision or native-device acceptance.
- `dimax_acceptance_tests` and `dimax_acceptance` are at 0064. Only the acceptance
  API was restarted; the normal backend/database were not migrated or restarted.
  Host `/ready` returned HTTP 200/database ready; admin access without a token
  returned 401; an unknown public approval token returned 404; live OpenAPI
  contains all new routes. The first readiness request hit startup (502), and
  the first cold OpenAPI request timed out at 20 seconds; both succeeded on
  recheck. Do not interpret this local check as production performance acceptance.
- The acceptance company has zero new price lists and zero invitations. No
  factory confirmation was manufactured to make the screen appear complete.

Before/after migration checksums and row counts matched exactly:

| Table | Rows | MD5 of ordered JSON rows |
| --- | ---: | --- |
| completed_work | 11 | d972af6ed54536ef21a9d1abc9f1ec2c |
| installer_rates | 8 | 7ffab959007f5746bb9cc74f13fac706 |
| doors | 9 | 23ddc04087c8a06023ce96bc52cb92dc |
| project_addon_plans | 1 | 05d1630d4faf1ed8e44fb61f1ec698b0 |
| project_addon_facts | 1 | ffad0b2f2f4243935a4c215c69d175bc |

The owned browser-test output directory was removed after inspection (128053
bytes). Existing unrelated files were not cleaned. API test containers used
`--rm`; the temporary migration database was removed. Local preview is running
at `http://127.0.0.1:4173` against the isolated API on 8001, not production.
Its localhost invitations are not externally reachable factory delivery links.

## Limits And Next Step

The link authorizes its holder. A typed name and the stored intended recipient
are not independent identity verification or proof of email ownership. Confirm
the factory contact before sharing; production requires HTTPS and controlled
delivery. No email/WhatsApp was sent in this step. The existing request limiter
is process-local; a multi-worker deployment needs shared/gateway enforcement.

Next implement the admin workflow for drafts, comparison, invitation sharing/
revocation and decision history. Then connect confirmed-version activation to
server-calculated installation/add-on earnings and read-only mobile sync. Preserve
the previous active version during amendments, immutable historical earnings,
tenant isolation and offline/retry behavior. Legacy prices must not be silently
labelled approved, and factory approval must remain separate from journal signing.

Backend commit: `e7851c7`. Admin/public-page commit: `588d4c5`. Commits are local
only. The prior public-remote restriction remains unresolved; no GitHub backup
or production approval is claimed. Overall readiness is not advanced by this
bounded step while activation, admin management, mobile sync and release gates
remain open.
