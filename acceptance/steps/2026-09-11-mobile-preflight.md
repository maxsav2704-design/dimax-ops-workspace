# Mobile acceptance: step 1, environment and safe launch

Scope: inspect the Android environment and build provenance before performing
installer business actions. This does not approve native/offline acceptance or
advance the frozen readiness criteria. Mobile baseline: `0ed0823`; correction:
`515cb12` on `codex/release-hardening-20260908`.

## Environment Evidence

- `workspace.cmd preflight-mobile-device` found the Android SDK, ADB, emulator
  executable and Java. `adb devices` returned an empty device list. Toolchain
  detection is not evidence that a phone is connected.
- A separate `emulator.exe -list-avds` returned `DIMAX_ATD34`. Its configuration
  specifies Android 34 AOSP ATD, x86_64 and 2 GB RAM. It was not booted.
- `workspace.cmd preflight-mobile-native-build` exited 0: Java 17.0.17 and cached
  Gradle 8.10.2 are available. This command does not compile an APK.
- Host memory observation: 3,978,360 KiB usable RAM, 376,828 KiB free physical RAM.
  No emulator was started on top of the running services with this headroom.
- Mobile checks used the existing local Node 20.19.5 runtime, within the package's
  declared `>=20.18 <21` range. No dependencies or toolchains were installed.

The saved `mobile/artifacts/android/dimax-installer-debug.apk` is dated August 27.
Its SHA256 matches `native-build-latest.json`:
`2FF4362630E0E50412000F464FC9AED7341C5C659BD4C178ACB2C35AE61E7FA4`.
That manifest identifies source `5f4369cc66110ce4e0553c013d1a288e2ad3a725`, not
the current source, and uses Android Debug signing. Version `0.1.0` alone cannot
prove freshness. No current installed app, fresh native build or owner-signed
release was verified.

## Defect: Implicit Test Account and API

Priority: P1 for safe acceptance setup. Status: FIXED AND VERIFIED in source and
launcher tests; device verification remains pending. This was not a production
authentication bypass.

Reproduction: import the mobile configuration in development with all E2E
environment variables absent. Before the fix, automatic login was enabled and
used a built-in seeded company/account/password. The dedicated E2E launcher also
overwrote the caller's API and account with fixed values and the ordinary port
8000. This could send acceptance actions to the wrong environment.

Changes in mobile commit `515cb12`:

- `src/lib/config.ts`: automatic login defaults off and has no embedded account
  fallback. It requires development mode, explicit opt-in, an explicit API and
  complete credentials. Normal manual login and its development API fallback
  remain unchanged; production automatic login remains disabled.
- `start-expo-e2e.ps1`: requires explicit synthetic credentials and a loopback
  HTTP(S) test API for ADB reverse; validates company UUID and distinct API/Metro
  ports. It derives the API port from the provided URL rather than assuming 8000.
  Production mode, incomplete configuration and unsafe URLs fail before ADB or
  Metro is invoked. `-ValidateOnly` prints connection details, not credentials,
  without touching a device or starting Metro.
- `start-expo-e2e.cmd`: forwards launcher options, including `-ValidateOnly`.
- `src/lib/config.test.ts`: regression coverage for defaults, opt-in, incomplete
  configuration and production mode.
- `scripts/e2e-launcher.test.mjs`, `package.json`: runnable PowerShell contract
  tests using only `-ValidateOnly` and synthetic values.
- `.github/workflows/mobile-quality-gate.yml`: dedicated Windows launcher test
  job. Its YAML parses locally; the remote job has not run for this commit.
- `README.md`: explicit isolated launch instructions and warning that Expo public
  environment variables are embedded in bundles and must never contain real
  credentials or be included in distributed test-login/release builds.

This safeguard prevents implicit target/account selection. It does not certify
that an explicitly chosen localhost service is a test database: the operator
must still select the isolated acceptance API and synthetic account.

## Verification

| Check | Result |
| --- | --- |
| New config regression before correction | 6 FAIL, 6 PASS; exit 1 |
| Focused config/API URL tests after correction | 19 PASS; exit 0 |
| Complete mobile Vitest run after final test adjustment | 189 PASS in 25 files; 0 skipped; exit 0 |
| Node launcher contract tests | 14 PASS; exit 0, including successful and rejected configuration |
| `npm run typecheck` | PASS; exit 0 after test adjustment |
| Expo `config --json` | PASS; DIMAX Installer 0.1.0, `com.dimax.operations.installer` |
| Workflow YAML parsing and `git diff --check` | PASS |
| Connected phone / fresh installed build | BLOCKED: ADB had no device |
| Emulator workflow / current APK build | NOT TESTED |

The first typecheck rejected dynamic imports in the new test under Expo's
existing module setting. The test now uses Vitest's `importActual`; application
TypeScript settings were not changed. The full test suite and typecheck were
repeated successfully. A second successful launcher run is a repeat of the same
14 cases, not additional coverage. The focused 19 cases overlap the 189 total.

Full test evidence (ignored local artifact):
`artifacts/acceptance-20260909/mobile-preflight-tests.json`.
Reproduction commands, with the supported Node runtime selected:

```powershell
cd mobile
npm.cmd run test -- --maxWorkers=1
npm.cmd run typecheck
npm.cmd run test:e2e-launcher
npm.cmd run config-check
```

No new installer login, door action, accrual, database migration, API mutation,
ADB reverse, APK installation or customer message occurred in this step. The ADB
daemon started during detection was stopped after the empty-device observation.
No project data, existing APK, database volume or unrelated changes were removed.

## Next Handoff

1. Connect and authorize a physical Android device, or deliberately provision
   sufficient memory for the configured emulator. Do not count browser testing
   as native acceptance.
2. Build/verify a current development APK and load the current JavaScript against
   the isolated acceptance API on port 8001, with explicit synthetic credentials.
   Do not clear the device's SQLite data or pending outbox to simplify setup.
3. Only then proceed to the next separate acceptance item: assignments and
   installer-specific project, door and calendar visibility. Offline restart,
   reconciliation and journal/signing/delivery remain later unverified items.

Code and evidence are saved in local commits only. No GitHub push was attempted:
the earlier public-publication restriction still requires explicit authorization.
Local commits are not remote backups. No overall readiness percentage is raised.
