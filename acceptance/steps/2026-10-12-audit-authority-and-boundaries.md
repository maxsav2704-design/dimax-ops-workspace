# DIMAX audit: authority and access boundaries

## Scope and confirmed decisions

This is the first implemented audit block, not closure of the complete external
audit and not production approval. Findings were checked against the repository,
not accepted automatically from the external report.

- OWNER separately verifies and approves the factory representative. OPERATIONS
  can invite only that contact; it cannot register, replace or revoke authority.
- The owner may revoke authority without a replacement. Pending links become
  unusable; historical decisions and earnings are retained.
- The owner must verify actual factory authority outside the software. A mailbox
  code proves mailbox possession, not legal identity or signing authority.
- Untrustworthy offline time or unprovable entitlement to an older price must
  retain the submitted work for admin review without automatic earnings. This
  second decision is a requirement for the NEXT financial block, not implemented
  by the changes below.

## Implemented

1. The production gateway has a dedicated private network and an exact trusted
   IPv4 address. Uvicorn trusts only that address. Preflight rejects wildcard
   trust, inappropriate networks, Docker gateway addresses and worker membership.
   Existing rate limits remain per process; shared throttling is not implemented.
2. Direct ASGI production startup runs the existing security validator, including
   the separately configured factory-mail encryption key. Unsafe configuration
   fails closed without printing secret values. Production API docs are disabled.
3. Company settings mutations are OWNER-only. Calendar assignment validates every
   installer in the same tenant before changing anything, with a uniform 404 for
   unavailable, foreign and inactive installers.
4. Migration 0070 adds versioned owner-approved factory contacts, one active
   contact per company, tenant-aware invitation references and constrained
   external audit actors. No historical authority is fabricated. Destructive
   downgrade refuses to discard authority or external decision history.
5. Registration, replacement and revocation serialize with invitation and
   confirmation operations using the existing company lock. Pending invitations
   without a currently authorized matching contact fail closed. Queued mail
   rechecks the invitation before sending. Confirmed decisions are preserved.
6. Factory confirmation is audited once with contact, version, snapshot hash,
   verified mailbox time, IP and user agent. The external actor is not falsely
   recorded as the administrator. Tokens and verification codes are not logged.
7. Admin has OWNER contact registration/revocation dialogs in EN/RU/HE, explicit
   consent/reason, duplicate-submit protection and stale-contact conflict checks.
   Recipient fields in invitations are read-only. Dialogs retain their initial
   contact revision through background refreshes.
8. Caddy denies framing and restricts base-uri. This is NOT a complete XSS CSP.
   Admin env files are ignored, with sanitized template exceptions. The unrelated
   AI-specific ignore change was not included in this checkpoint.
9. Historical migration tests use historical schema fixtures rather than running
   current mailbox/contact services against schema 0065. Current business logic
   remains tested separately at head. The real delivery driver now registers the
   OWNER-approved contact and checks the external audit decision.
10. The production checklist no longer recommends destructive shared-volume
    cleanup. It explicitly blocks use of the old unsafe backup/restore script
    until that separate tool is fixed.

## Verification actually executed

Final selected runs: **250 passed**, **2 skipped**, not the complete release suite.

| Check | Result |
| --- | --- |
| Approval API, price timeline, application check, factory earnings | 133 PASS |
| Contact authority, calendar isolation, proxy/startup, settings roles | 41 PASS |
| Invitation outbox and mailbox verification | 33 PASS, 2 opt-in Mailpit tests skipped |
| Admin `src/test/PriceListsPage.test.tsx` | 23 PASS |
| Production preflight/deploy contract unit tests | 20 PASS |
| Admin TypeScript `--noEmit --incremental false` | PASS |
| ESLint on all six changed admin TS/TSX files | PASS |
| Real Compose/Caddy `scripts/production-infra-contract.ps1 -ConfigOnly` | PASS |
| Fresh PostgreSQL migration chain to 0070 | PASS |
| Historical 0063/0064/0065 upgrade/rollback and history protection | PASS |
| Historical fixture upgrade 0065 to 0070 | PASS |
| Diff whitespace checks | PASS |

The historical fixture retained exactly one earning with checksum
`fa80e326b41ec33eb644eabd9488ea60` before and after the final upgrade. At 0070 it
had zero factory contacts and one retained confirmed invitation without a contact,
as required for legacy evidence. The test did not invent an owner approval.

Backend checks used cached `dimax-backend-workspace:local` with Python 3.12,
PostgreSQL, read-only source mounts and disposable databases. They do not prove
Python 3.11 compatibility. Mail tests mocked sending; the two real Mailpit cases
and the updated process-level delivery driver were NOT executed in this block.
There was no real SMTP delivery, browser E2E run, full admin build, mobile release
suite or physical-device acceptance.

An earlier combined backend run was interrupted under memory pressure after 27
passes; it was NOT counted as a successful suite. Earlier Vitest worker-start
timeouts and a 512 MB TypeScript heap failure were followed by successful
sequential runs. No unrelated services were stopped to obtain these results.

Both owned databases (`dimax_audit_20261012_c71e` and the newly created
`dimax_factory_price_migrations`) were removed and their absence verified. Owned
audit containers were removed. No new build directories or dumps were created.

## Deployment boundary and checkpoints

- Backend: `7342867` production startup/settings/calendar; `b339f30` contact
  authority, audit, migration and supporting tests/docs.
- Admin: `86fae33` contact controls, invitation recipient restriction and env ignore.
- Root: the commit containing this report records gateway trust and its tests.
- These are LOCAL checkpoints, not an off-machine GitHub backup. No push occurred.
- Existing AI changes in root/backend/admin were preserved and not staged.
  Concurrent mobile changes were also left untouched.
- Migration 0068 and its chain were not rewritten. AI feature-code release
  ownership remains a separate coordination concern.
- No migration or deployment was applied to the running acceptance database.
  Its API/ready endpoints on 8001 and existing admin login on 4190 still returned
  HTTP 200; API, worker, DB and Mailpit were healthy at the final readback.
- The running admin/API are NOT evidence that this new feature is deployed.
  Apply 0070 before restarting/deploying the matching API/worker/admin release.
  Register the owner-approved contact and reissue old pending invitations;
  pre-0070 pending links intentionally cannot authorize new decisions.

## Audit disposition and remaining order

| External finding | Current disposition |
| --- | --- |
| 1. Backdated offline execution time | OPEN High |
| 2. Every dated sync command treated as legacy | OPEN High |
| 3. Missing-price work cannot be resolved | OPEN, part of the next financial block |
| 4. Database-level financial immutability | OPEN; do not add one-original-per-door uniqueness blindly |
| 5. Arbitrary factory recipient/self-confirmation | Implemented agreed OWNER authority boundary; organizational verification still required |
| 6. Missing external confirmation audit | Implemented and tested |
| 7. Legacy rates before factory activation | OPEN transition policy/enforcement |
| 8. OPERATIONS company settings mutation | Implemented and tested |
| 9. Foreign installer calendar assignment | Implemented and tested |
| 10. Twilio signature default | Production validator already rejects disabled validation when Twilio is enabled; not a proven production bypass |
| 11. Proxy client IP/rate-limit bucket | Local configuration and regression fixed; public deployment still unverified |
| 12. Startup/docs/CSP/env/demo hardening | Startup, docs, framing and env fixed; full CSP/token policy and demo exposure remain |
| 13. Backup, mutable images, unhealthy worker recovery | OPEN; restart policy alone does not restart a live unhealthy process |

Next logical blocks, each with its own migration/tests/checkpoint:

1. **Offline financial authority (1, 2, 3):** persist server-owned assignment and
   receipt evidence, distinguish demonstrably old queue items, retain unresolved
   work and implement audited admin review for untrusted time/missing price.
   Door creation/assignment time is only a lower bound: it does not prove when an
   offline action happened. A phone timestamp or a claimed old version alone must
   not authorize a favorable historical price. Do not introduce an arbitrary
   N-day window or silently substitute the current price. Honor confirmed
   execution-time prices where supported, and the approved first-price legacy
   policy only for eligible records. Test forged dates, reassignment, replay,
   missing versions/prices and review without duplicate earnings.
2. **Financial persistence and transition (4, 7):** protect immutable amounts and
   price evidence at the database boundary; retain valid reversal/recompletion
   cycles. A blanket unique ORIGINAL per door would break legitimate behavior.
   Close remaining unapproved legacy-price writes without recalculating history.
3. **Safe recovery and deployment (12, 13):** fix exclusive dump creation,
   source/target validation, refusal to overwrite existing restore databases,
   owned-resource cleanup and business-data checksums; prove restore before
   migration. Coordinate changes to the already-dirty demo Compose. Pin images,
   close public demo ports and establish unhealthy-worker recovery. No `down -v`.
4. **Release acceptance:** complete access/JWT matrix based on actual test gaps,
   backend/admin/mobile suites, admin build/browser dialogs and device offline
   flows. Run real local API/worker/Mailpit flow, then actual HTTPS/domain/SMTP
   acceptance when infrastructure exists. No production rollout before these
   gates and a supervised business pilot.

Current verdict: the authority/access block is tested in source, but financial
High findings remain. Overall production readiness is not 100% and has not been
re-scored in this step.
