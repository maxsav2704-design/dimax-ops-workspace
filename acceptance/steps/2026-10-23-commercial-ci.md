# Commercial confirmation: isolated CI continuation

Status: PASS for this isolated acceptance block. Final run 39977245788 passed
all checks; its five screenshots were downloaded and visually inspected.

## Scope

- Finish the remaining 119 regression cases: work-price accruals, approvals,
  proposals and commercial activation.
- Run the real admin/factory browser flow with internal SMTP/Mailpit: exact
  versions, explicit consent, mailbox code, wrong code rejection, immutable
  replay, access isolation and unchanged installer financial digests.
- Verify the recorded decision after API restart and reject a downgrade that
  would discard confirmation history. Inspect the desktop, RU390 and HE768
  browser screenshots before accepting the result.

## Why not the local host

Read-only preflight showed 3,885 MB total RAM and only 282 MB available, while
the working API, PostgreSQL, MinIO and five workers were healthy/running.
No working service was paused or restarted in this continuation. No working
data, migrations, settings or Claude changes were modified.

## Frozen inputs and publication boundary

- Backend: `55d7c7ca9a6bb2f6130e26f875d6c8c31d6b7966`.
- Admin: `be6be085e9baa222ce5862f0fed9ce5806ac7fe1`.
- GitHub returned "No commit found" for both SHAs. Running the exact versions
  remotely therefore requires publishing their already committed history,
  including Claude's committed changes. Uncommitted files are excluded.
- The user explicitly approved publishing these versions, including committed
  Claude code, in new `codex/commercial-acceptance-20261023` branches in the
  three public DIMAX repositories and running Actions. All three pushes succeeded.
- Workspace publication is prepared in a separate temporary clone of public
  `main`, with an allowlist of nine acceptance/workflow files. It does not
  publish the dirty workspace or change its branch/index.

## Isolation and evidence

- Workflow: `.github/workflows/commercial-approval-acceptance.yml`.
- Additional CI overlay: `acceptance/commercial-approval-ci.compose.yml`.
- Dedicated Ubuntu runner, Node 20, at least 6 GiB total and 4 GiB available RAM.
- Unique Compose project for each run/attempt; tmpfs PostgreSQL, separate
  regression/browser databases, no existing database mounts or working secrets.
- API and Mailpit use an internal-only network; local gateway exposes only
  127.0.0.1. No external email, WhatsApp, AI or production endpoints.
- Only summary counts and allowlisted synthetic screenshots are artifacts.
  Private session/token/code files and raw test output are not uploaded.
- An always-run cleanup removes only that runner's Compose project and private
  fixtures. No deployment action is part of this workflow.

## Completed checks

- Python AST parse: runtime and approval runtime passed.
- Node syntax check: browser harness passed.
- YAML parser with duplicate-key detection: workflow and overlays passed.
- Full four-file `docker compose config --quiet`: passed; no services launched.
- `git diff --check`: passed. Backend remained clean; existing admin/root dirty
  files were preserved, including the parallel Claude work.

## Remote run

- Workspace acceptance commit: `ded2cf2c03b050addc245148f611850292cd48f5`.
- Run: https://github.com/maxsav2704-design/dimax-ops-workspace/actions/runs/39967207130
- All three checkouts and the runner memory/input preflight succeeded.
- The remaining regression step passed, including its strict JUnit assertion:
  119 tests, zero failures, errors or skips, in 291.81 seconds. The sole pytest
  warning was a cache write refused by the intentionally read-only source mount.
- The local working branches/indexes were not switched or staged; the workspace
  commit was built in the separate clone. No PR, merge or deployment was made.

### Observed harness issue and correction

- The first run stopped during fixture login with HTTP 429 after five logins
  from the same IP. The application correctly enforced its five-logins/900-second
  limit; this was not a failing business regression or browser pass.
- An intermediate bounded-retry candidate (`e0eddb1`, run 39968620661) was
  cancelled after confirming the actual 900-second setting. It is not accepted.
- The corrected fixture authenticates its five internal roles once and the
  foreign tenant through the ordinary gateway, then reuses those real JWTs for
  receipt checks. No rate limit override, fake JWT, forwarded-IP spoofing or
  application change is involved. Expired sessions still fail the assertions.
- Corrected workspace commit: `2b80d4c6545c938c2c23c467490d51199f1e635a`.
- Corrected run: https://github.com/maxsav2704-design/dimax-ops-workspace/actions/runs/39969074772

### Browser dependency setup correction

- Run 39969074772 repeated all 119 tests successfully (223.21 seconds), prepared
  the real-role fixture and completed the Node 20 production build, TypeScript
  and all 30 static pages. It was cancelled during `playwright install --with-deps`:
  the log showed Ubuntu Azure-mirror downloads taking over ten minutes. No browser
  pass is claimed for that cancelled run; its cleanup completed successfully.
- The workflow now installs only Chromium's headless shell, using runner system
  libraries. Playwright's launch-time dependency validation is not disabled.
- Dependency install, build, browser setup and server startup are separate timed
  steps. Sessions are created after build/browser setup to avoid spending their
  normal 15-minute lifetime during dependency downloads. JWT TTL is unchanged.
- Pytest cache now uses writable container `/tmp`, keeping source read-only.
- Current acceptance commit: `10dea145db12879d56bfb5c8289a4bf802ad4555`.
- Current run: https://github.com/maxsav2704-design/dimax-ops-workspace/actions/runs/39972137390

### Browser table assertion correction

- Run 39972137390 completed the 119-case regression, production build, Chromium
  installation, fresh fixture preparation and standalone startup. It failed at
  the send-dialog assertion before sending the invitation; cleanup succeeded.
- The assertion incorrectly expected an exact text node for a price name. The
  rendered table cell also contains its work-kind/stage label. The harness now
  checks one matching table row and its actual `400.50` price in the admin send
  dialog, public review and persisted history. No application change or relaxed
  financial assertion was required.
- Corrected acceptance commit: `1927ce91a34b736c70d891d717d5bc47466e7456`.
- Run: https://github.com/maxsav2704-design/dimax-ops-workspace/actions/runs/39974467094

### Public error assertion correction

- Run 39974467094 passed regression/build/setup and created the invitation
  through the real admin. SMTP link/code delivery, public preview, RU390 form
  sizing, explicit consent and HTTP 403 for a wrong code were reached.
- The error assertion then matched both the application's alert and Next.js's
  empty route-announcement alert. It is now scoped to the page's main region;
  the actual HTTP status and expected error text remain mandatory.
- Acceptance commit: `eeffc6f22e8f3dcd949c60aa894e8148a8073808`.

## First complete-chain pass

- Run: https://github.com/maxsav2704-design/dimax-ops-workspace/actions/runs/39975698710
- Job duration: 6 minutes 3 seconds; all steps, artifact upload and cleanup passed.
- Regression: 119 passed in 201.79 seconds, zero failures/errors/skips.
- Production build: Node 20, TypeScript and all 30 pages passed.
- Browser: real admin invitation; separate unauthenticated factory context;
  real internal SMTP invitation/code; required explicit consent; wrong-code 403;
  successful exact-version decision; identical replay with no duplicate; changed
  signer/version rejected; invalid token rejected; new code after decision rejected.
- Receipt: OWNER allowed; OPERATIONS, FINANCE, VIEWER and INSTALLER denied;
  foreign tenant hidden; anonymous request unauthorized. One CONFIRM audit entry,
  unchanged nonzero installer financial baseline, no agreement activation.
- After API restart and a refused downgrade to 0085: decision, current schema
  head, audit count and financial digests still intact.
- All five screenshots inspected: readable tables/forms, RU390 and HE768 without
  overlap or horizontal overflow. Language colors caught a 150ms CSS transition;
  the final harness fast-forwards screenshot animations and additionally asserts
  active/inactive language buttons' aria-pressed values. Application unchanged.
- Local read-only health/ready checks both returned HTTP 200. Frozen backend and
  admin HEADs are unchanged; no local working service restarted.

Final evidence repeat: commit `9c75ff3f8ad0eb30394bb8ad228c06104fba49eb`,
https://github.com/maxsav2704-design/dimax-ops-workspace/actions/runs/39977245788

## Final result

- Final run 39977245788: SUCCESS, 6 minutes 59 seconds, all steps including
  evidence upload and disposable-environment cleanup passed.
- JUnit summary: 119 tests, zero failures, errors or skips. Production build,
  actual browser/SMTP chain, authorization, unchanged financial digests,
  restart persistence and protected downgrade all passed again.
- Five final images inspected: admin EN, public EN review, public RU390 form,
  public RU390 confirmed result and public HE768 confirmed result. Selected
  language styling now matches the text; form controls, price columns and RTL
  layout are readable, without clipping or overlap in these captured states.
- Final evidence is kept locally in ignored
  `artifacts/commercial-ci-20261023-final/` (five PNGs and two summaries, under
  1 MiB). It contains no passwords, invitation tokens or mailbox codes.
- Acceptance code is backed up in the authorized public workspace branch at
  `9c75ff3f8ad0eb30394bb8ad228c06104fba49eb`; the two source branches contain the
  frozen backend/admin SHAs above. No application code was changed to make these
  checks pass. Corrections were limited to test setup, assertions and evidence.
- After publishing this report, remove only the temporary publication clone;
  working repositories, indexes, dependencies and Claude files remain untouched.

This closes the previously unfinished regression/browser gates for this block.
It is not a statement that the entire product is production-ready.

## Acceptance boundaries

- These are the remaining 119 targeted backend cases, not the entire backend,
  admin or mobile release suites. Earlier local checks remain recorded in
  `2026-10-23-commercial-recheck-codex.md` with their own scope and limitations.
- The factory recipient, contract, prices, users and pre-existing earnings are
  synthetic. No commercial agreement was activated by the browser scenario.
- SMTP was exercised through the real worker to internal Mailpit. A real domain,
  HTTPS, DNS/mail authentication and external recipient delivery still require
  deployment acceptance; this run does not prove them.
- No PR, merge or working deployment was performed. Uncommitted Claude changes
  are not covered by the frozen-snapshot result and were not published or edited.
- Actions reports a maintenance warning for v4 actions' Node 20 metadata and runs
  those actions on Node 24. The explicitly configured application build uses
  Node 20. The warning did not fail the checks; runtime/action upgrades need their
  own compatibility work, not an untested change to this acceptance snapshot.
