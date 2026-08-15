# Final Production Maturity Readiness

Generated at: 2026-08-15 14:16 +03:00

## Release Decision

- Overall: `CODE GO / RELEASE SOURCE NO-GO / PRODUCTION NO-GO`.
- Verified code and staging readiness: `100%`.
- Production deployment readiness: `90%`.
- The remaining gaps are immutable reviewed source, owner-provisioned production
  configuration, Android release signing, fresh physical-device QA, deployment,
  and post-deploy evidence.

## Critical And High-Risk Work Closed

- The production backend image now installs an exact constrained dependency graph,
  runs `pip check`, excludes test and env files, and runs as UID/GID `10001`.
- The production image was reduced from about 244.8 MB to 143.9 MiB while retaining
  the required English, Hebrew, Russian, and OSD OCR language packs.
- Access and refresh tokens now reject inactive users and inactive companies.
- Login no longer exposes whether an account exists or is inactive; invalid login
  attempts return the same public `401` response.
- Refresh rotation and logout lock the refresh-session row to prevent concurrent
  token rotation races.
- Installer sync batch and event application now use database savepoints. A failed
  item cannot commit partial door changes, while its conflict/failure record remains
  available for recovery and monitoring.
- Migration `0049` now handles the legacy `product_library` schema without index-name
  collisions, preserves legacy rows and `client_price_list` foreign keys, and supports
  a verified downgrade/re-upgrade round trip without dropping the legacy table.
- Company plan-limit webhook delivery remains best-effort for the core transaction,
  but success and failure are now emitted as structured redacted operational events.
- Production Compose no longer accepts a missing or floating `latest` backend image.
  The production env validator requires a sha256 digest or a release tag ending in
  a 12-64 character source SHA.
- `/health` remains a liveness check. The new `/ready` endpoint verifies PostgreSQL
  with `SELECT 1`, returns `503` when unavailable, and does not disclose connection
  errors. Production container readiness now uses `/ready`.
- New dependency advisories were remediated without a breaking Expo upgrade. Mobile
  still reports six propagated High package records from two unpatched upstream
  `image-size` advisories; the pinned postinstall patch and its security probe cover
  both, leaving no unmitigated Critical or High finding.

## Verified Gates

- Alembic full migration chain `0001 -> 0057`: PASS on a fresh isolated PostgreSQL
  database.
- Repository-boundary and backup/restore checks: PASS; restored schema contains 42
  tables.
- Legacy product-library migration round trip `0048 -> 0057 -> 0048 -> 0057`: PASS;
  legacy and canonical products, relation names, and price-list foreign keys were
  preserved.
- Backend quality gate: PASS, 348 tests in the release groups.
- Focused production-image contract: PASS for the SHA-tagged test image.
- Workspace CI contract: PASS; every release PowerShell script parses and all
  source, dependency, release-status, handoff, and Android QA self-tests pass.
- Admin production build: PASS; 24 application routes were generated.
- Admin unit/integration gate: PASS; 207 tests in 36 files.
- Admin clean-run reproducibility: PASS under Linux/Node `20.20.2` after `npm ci`;
  the complete quality gate includes environment and test-discovery contracts.
- Mobile quality gate: PASS; 17 test files and 118 tests passed, followed by Expo
  config validation and TypeScript.
- Mobile clean-run reproducibility: PASS under Linux/Node `20.20.2` after `npm ci`;
  the repository-local test-discovery contract and pinned `expo-doctor` ran without
  relying on workspace files or globally downloaded tooling.
- Expo Doctor: PASS, 17/17 checks in the clean CI-equivalent container.
- Native Android debug build: PASS; 301 Gradle tasks produced a signature-verified
  `com.dimax.operations.installer` APK with minSdk 24, targetSdk 34, and SHA-256
  `61F6B1E415F0920EEFB165DB5B7C127800A2D1254D949838CD1E74EAA936F874`.
- Last successful dependency policy run: PASS; backend 0 known vulnerabilities across 67 packages,
  admin 0 Critical/High with 2 Moderate, mobile 0 unmitigated Critical/High with
  6 locally patched High package records and 14 Moderate.
- Historical physical Android regression smoke: PASS on `2210129SG` and the
  `DIMAX_ATD34` emulator. The freshly built 2026-08-15 APK was not installed because
  ADB reported no attached device; a fresh device run remains required.
- `git diff --check`: PASS for workspace, backend, admin, and mobile repositories.
- Runtime smoke: PASS for API health, admin login, operations, reports, installer
  workspace, and installer calendar.
- API and web runtime smoke passed in the prior handoff. All Docker containers are
  intentionally stopped after the current isolated release checks.
- Changed-source safety passed for the complete pre-commit snapshot. The release
  changes are now captured in four local commits; a clean-tree handoff must be
  generated after this workspace commit and the branches still require remote review.

## Release Blockers

1. The workspace, backend, admin, and mobile release changes are captured in local
   commits, but those commits have not been pushed or verified by remote required
   checks. All four branches must be pushed and reviewed before deployment.
2. Real backend, admin, and mobile production env files are not present.
   `EXPO_PUBLIC_API_BASE_URL` must match the real HTTPS API; localhost and
   placeholder values are now rejected at validation, runtime, and Android
   release-build stages.
3. Android release signing is fail-closed, but the release environment still needs
   `DIMAX_ANDROID_KEYSTORE_FILE`, `DIMAX_ANDROID_KEYSTORE_PASSWORD`,
   `DIMAX_ANDROID_KEY_ALIAS`, and `DIMAX_ANDROID_KEY_PASSWORD`.
4. Fresh physical-device QA is still required for the APK produced on 2026-08-15.
5. A post-deploy smoke against the real HTTPS hosts is required after the production
   values are provisioned.

## Operational Notes

- The pre-commit source evidence is complete: pinned Gitleaks scanned 501 changed
  files without findings. Clean-tree source evidence is regenerated after the local
  release commits, and the dependency policy reports no
  unmitigated High or Critical vulnerability.
- GitHub Actions now has fail-closed required contexts for workspace, backend,
  frontend/admin, installer browser smoke, and mobile. Admin and mobile CI invoke
  their complete repository-local quality gates on Node 20.
- Business smoke and all nine mandatory browser/brand scenarios passed in the current
  runtime session. The browser smoke now stops preview and removes its generated
  output in `finally`, so the following hygiene gate passes.
- Historical Android device QA evidence is preserved. Fresh installation and route
  smoke for the 2026-08-15 APK remain pending because no ADB device was attached.
- Development admin and preview processes generate ignored `.next-dev`, `.next`,
  preview log, and visual artifact directories while they are running. The hygiene
  gate passed in a stopped, clean handoff state before both web runtimes were
  restarted.
- The first request to the development server on port 5173 may take about a minute
  after a clean rebuild on this machine because available RAM is limited. Subsequent
  requests are warm and respond normally.
- Existing line-ending warnings are Windows LF/CRLF notices; no whitespace errors
  were reported by `git diff --check`.

## Required Production Closure

Production can be declared complete only after the source is reviewed, committed, and
pushed; the owner supplies the real env and Android signing material; the validation
commands pass; the release APK passes fresh physical-device QA; the digest/SHA-pinned
images are deployed; and post-deploy readiness, auth/RBAC, sync, and business smoke
succeeds. Until then, the honest deployment-readiness estimate remains `90%`, not
`100%`, and the automated decision remains `CODE GO / RELEASE SOURCE NO-GO /
PRODUCTION NO-GO`.
