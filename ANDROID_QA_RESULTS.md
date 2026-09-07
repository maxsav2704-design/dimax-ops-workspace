# Android QA Results

## Current Candidate (verified 2026-08-28)

- Package: `com.dimax.operations.installer`
- Build: `PASS` (`:app:assembleDebug`, 386 Gradle tasks)
- Android policy: minSdk 24, targetSdk 34
- APK: `mobile/artifacts/android/dimax-installer-debug.apk`
- APK SHA-256: `2FF4362630E0E50412000F464FC9AED7341C5C659BD4C178ACB2C35AE61E7FA4`
- Mobile source: `9262211a1cda3b9fab7424335c107c09d098f937`
- Automated mobile quality gate: `PASS`, 164 tests across 22 files
- Android emulator regression for this hash: `PARTIAL`; the APK and JavaScript bundle were verified again on 2026-08-28, but the focused project-detail rerun was blocked by a persistent Android system_server ANR on the 4 GB host
- Physical-device interaction smoke for this hash: `PASS` on `2210129SG / Android 15`; clean auto-login, restored-session cold start, assigned list, project detail, floor and door selection were verified
- Current decision: `GO for the debug release candidate; production distribution still requires release signing and production environment values`

## Session
- Date: `2026-08-28 16:34:00 +03:00`
- Tester: `Codex physical Android regression plus owner-accepted historical external-action evidence`
- Final release package: `C:\Users\Hi-tech\.vscode\DIMAX Operations Suite\FINAL_GO_NO_GO_PACKAGE.md`
- Device: `2210129SG physical device; emulator evidence retained as historical fallback`
- Android version: `15 physical device; 14 historical emulator`
- Waze version: `Historical handoff PASS; not rechecked in this regression`
- WhatsApp version: `Owner-accepted handoff; not rechecked in this regression`
- Build / environment: `Debug APK 2FF4362630E0 + current mobile source 9262211 + Node 20 Metro + ADB reverse API http://localhost:8000`

## Result Table

| Case | Screen | Locale | Fixture / Project | Expected | Actual | PASS / FAIL | Evidence file | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | Project | EN | Mobile Test Alpha | Waze opens native navigation | Waze opened native route from DIMAX project button | PASS | `artifacts/screens/android-case-01-project-waze-pass.png` | Focus: `com.waze/com.waze.MainActivity`. |
| 2 | Project | EN | Mobile Test Alpha | WhatsApp opens with correct target and prefill | Accepted as working as planned by product owner; device proof reaches normal WhatsApp chooser | PASS | `artifacts/screens/android-case-02-project-whatsapp-chooser-blocked.png` | Code prefers `whatsapp://send` over `wa.me`; final composer was blocked by MIUI App Lock on device, then accepted by owner on 2026-06-16. |
| 3 | Workspace | HE | Project A | Waze opens from workspace | Not executed from app button in this session | NOT RUN |  | External handoff gate remains open. |
| 4 | Schedule | HE | Project A | Waze opens from schedule | Not executed from app button in this session | NOT RUN |  | External handoff gate remains open. |
| 5 | Project | RU / EN | Project A | WhatsApp prefill matches installer locale | Accepted as working as planned by product owner | PASS | `artifacts/screens/android-case-02-project-whatsapp-chooser-blocked.png` | Prefill path is covered by code normalization tests; owner accepted WhatsApp behavior on 2026-06-16. |
| 6A | Project | EN | Coordinates fixture | Coordinates source is used | Waze route opened from coordinate URL | PASS | `artifacts/screens/android-case-01-project-waze-pass.png` | Mobile Test Alpha uses `ll=31.801,34.643`. |
| 6B | Project | HE | Manual Waze fixture | Manual Waze URL is used | Not executed from app button in this session | NOT RUN |  | External handoff gate remains open. |
| 6C | Project | HE | Text address fixture | Address fallback works | Not executed from app button in this session | NOT RUN |  | External handoff gate remains open. |
| 7 | Project | HE | Missing-data fixture | Safe hidden / disabled behavior | Not executed from app button in this session | NOT RUN |  | External handoff gate remains open. |

## Device Route Smoke

| Case | Route | Expected | Actual | PASS / FAIL | Evidence file |
|---|---|---|---|---|---|
| A | Launch/login | Installer can enter preview session | Auto-login reached installer workspace | PASS | `artifacts/device/android-dimax-auto-login-final.png` |
| B | Workspace | Assigned installer workspace opens and shows queue/earnings snapshot | Workspace opened; pending queue 0; today earnings 80.00 | PASS | `artifacts/device/android-dimax-auto-login-final.png` |
| C | Calendar | Calendar route opens without crash | `My Calendar`, source Online, visible events 0 | PASS | `artifacts/device/android-dimax-calendar-deeplink.png` |
| D | Earnings | Earnings route opens and shows backend money snapshot | Today 80.00; month 80.00; focused total 80.00 ILS | PASS | `artifacts/device/android-dimax-earnings.png` |
| E | Sync queue | Queue route opens and shows health | Pending 0 / Failed 0 / Blocked 0 | PASS | `artifacts/device/android-dimax-sync-queue.png` |
| F | Project detail | Real assigned project detail opens | Mobile Test Alpha; 3 doors; installed 2; not installed 1; project queue 0 | PASS | `artifacts/device/android-dimax-project-alpha-fixed.png` |
| G | Cold start | Saved installer session reopens the workspace | Workspace restored with 28 assigned projects and current sync timestamp | PASS | `artifacts/device/android-2026-08-28-physical-current-bundle-cold-fixed.png` |
| H | Assigned project | Current bundle opens project details and live door state | Business Smoke project opened; progress, open issue and queue state rendered | PASS | `artifacts/device/android-2026-08-28-physical-final-project-detail.png` |
| I | Door explorer | Floor and door positions are readable and selectable | Floor 4 displayed; installed and not-installed positions rendered; selection changed without status mutation | PASS | `artifacts/device/android-2026-08-28-physical-door-selected.png` |

## Critical Gate Summary
- `Project -> Waze`: `PASS`
- `Project -> WhatsApp`: `PASS`
- `Locale-specific prefill`: `PASS`
- Crash observed: `NO`

## Regression Device Smoke 2026-08-28

- Device: `2210129SG physical device / Android 15`
- Package: `com.dimax.operations.installer`
- APK SHA-256: `2FF4362630E0E50412000F464FC9AED7341C5C659BD4C178ACB2C35AE61E7FA4`
- Runtime: physical Android 15 + debug APK + current Node 20 Metro bundle + ADB reverse API `http://localhost:8000`
- Installer auto-login: `PASS`
- Assigned project list and sync timestamp: `PASS`
- Assigned project detail navigation: `PASS`
- Fatal Android or JavaScript runtime errors: `NONE`
- Installed APK hash match: `PASS`; device `base.apk` exactly matched the saved release candidate
- Fresh app-data bootstrap: `PASS`; installer auto-login reached 28 assigned projects
- Restored-session cold start: `PASS`; the workspace reopened after process force-stop with cached identity and database
- Assigned project detail: `PASS`; live project status, door progress and issue state loaded without SQLite constraint errors
- Floor and door explorer: `PASS`; floor 4 and two door positions were readable and selectable without mutating work status
- Automatic sync coalescing regression: `PASS` in the 164-test mobile quality gate
- Evidence:
  - `artifacts/device/android-2026-08-28-physical-workspace.png`
  - `artifacts/device/android-2026-08-28-physical-projects.png`
  - `artifacts/device/android-2026-08-28-physical-current-bundle-cold-fixed.png`
  - `artifacts/device/android-2026-08-28-physical-final-projects.png`
  - `artifacts/device/android-2026-08-28-physical-final-project-detail.png`
  - `artifacts/device/android-2026-08-28-physical-project-doors-lower.png`
  - `artifacts/device/android-2026-08-28-physical-door-selected.png`

## Focused Emulator Attempt 2026-08-28

- Device: `DIMAX_ATD34 / Android 14 / emulator-5554 / 1 GB AVD RAM`.
- Backend health and installer API path: `PASS`.
- Installed package: `com.dimax.operations.installer`.
- Installed `base.apk` SHA-256: `2FF4362630E0E50412000F464FC9AED7341C5C659BD4C178ACB2C35AE61E7FA4`; exact match with the saved release-candidate APK.
- Metro device readiness: `PASS`; Android bundle returned HTTP 200, 8,576,302 bytes, with the E2E installer auto-login environment.
- Metro cache recovery: `PASS`; the launcher now probes a real Android bundle and retries a known invalid DependencyGraph cache once with `--clear` before declaring the device server ready.
- React Native startup: `PASS`; `ReactNativeJS: Running "main"` recorded for the installed package.
- Fatal DIMAX Android or JavaScript exception: `NONE`.
- Android platform health: `FAIL`; `Process system isn't responding` returned after selecting `Wait`, so the AVD could not provide a trustworthy interactive project-detail result.
- Assigned project detail navigation: `NOT RUN`; no product PASS is claimed from an unresponsive Android system process.
- Evidence:
  - `artifacts/device/android-2026-08-28-workspace.xml`
  - `artifacts/device/android-2026-08-28-workspace.png`
  - `artifacts/device/android-2026-08-28-after-wait.xml`
  - `artifacts/device/android-2026-08-28-after-wait.png`
  - `artifacts/device/android-20260828-112045-e2e-ready.log`

## Native Build Verification 2026-08-15

- Build: `PASS` (`:app:assembleDebug`, 345 Gradle tasks; repeat gate 266 tasks up-to-date).
- Package: `com.dimax.operations.installer`.
- Android policy: minSdk 24, targetSdk 34.
- APK SHA-256: `22C2F9540E146483CD9E23F7AB5A5B5063059A792D63A61B9CEBD013482E4F35`.
- Signature verification: `PASS` with the Android debug certificate.
- ADB device: `PASS` (`2210129SG`, Android 15).
- Fresh device smoke: `PASS`.
- Physical regression includes online, offline, cold bootstrap and route navigation evidence.

## Final Recommendation
- Decision: `GO`
- Blocking issue count: `0 for the current debug release candidate`
- Follow-up fix PR required: `NO for the validated Android interaction path`
- Summary: `The current source passed automated gates and the physical-device regression, including saved-session cold start and assigned project detail navigation.`
- Production distribution: `NO-GO until a release-signed APK/AAB and real production environment values are supplied and verified.`

Validate this sheet before production mobile GO:

```powershell
.\workspace.cmd android-qa-report
```

## Evidence Checklist
- Screenshots saved in `artifacts/screens/`: `YES`
- Device files saved in `artifacts/device/`: `YES`
- Video saved if needed: `NO`

## Naming Convention
- Screenshots:
  - `artifacts/screens/android-case-01-project-waze-pass.png`
  - `artifacts/screens/android-case-02-project-whatsapp-fail.png`
- Videos:
  - `artifacts/device/android-case-02-project-whatsapp.mp4`
- Notes:
  - `artifacts/device/android-session-notes.txt`
