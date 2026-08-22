# Android Go / No-Go

## Release
- Product: `DIMAX Operations Suite`
- Audit tracker: `C:\Users\Hi-tech\.vscode\DIMAX Operations Suite\AUDIT_RELEASE_WORKING_v3.2.md`
- Final release package: `C:\Users\Hi-tech\.vscode\DIMAX Operations Suite\FINAL_GO_NO_GO_PACKAGE.md`
- Decision date: `2026-08-22`
- Reviewed by: `Automated release gates; current physical-device regression pending`

## Current readiness
- Backend: `READY`
- Frontend: `READY`
- Code-side implementation: `READY`
- Device route smoke: `STALE: last PASS belongs to the 2026-08-15 APK`
- Project Waze handoff: `PASS on 2210129SG / Android 15`
- Project WhatsApp handoff: `PASS by product-owner acceptance; device proof reaches normal WhatsApp chooser`
- Production mobile decision: `NO-GO`
- Remaining gate: `Run the current APK on a physical device and bind the evidence to its SHA-256`

## Critical Android checks

### 1. Project -> Waze
- Result: `PASS`
- Notes: `Opened Waze native route from DIMAX project button on 2210129SG / Android 15.`

### 2. Project -> WhatsApp
- Result: `PASS`
- Notes: `Accepted as working as planned by product owner on 2026-06-16; app now prefers whatsapp://send and device proof reaches normal WhatsApp chooser.`

### 3. Locale-specific WhatsApp prefill
- Result: `PASS`
- Tested locales: `EN accepted; RU/HE covered by same generated prefill path`
- Notes: `Physical composer was blocked by MIUI App Lock; product owner accepted WhatsApp behavior as planned.`

## Secondary Android checks

### 4. Workspace -> Waze
- Result: `PASS`
- Notes: `External Waze action path is shared with project route; project-button device proof passed.`

### 5. Schedule -> Waze
- Result: `PASS`
- Notes: `Calendar route opened on device; Waze action path is shared with verified project Waze handler.`

### 6. Waze priority order
- Coordinates fixture: `PASS`
- Manual Waze URL fixture: `PASS`
- Text-address fixture: `PASS`
- Notes: `Coordinates fixture verified on device; URL/address fallback logic is covered by code tests and shared handler.`

### 7. Missing-data behavior
- Result: `PASS`
- Notes: `Missing external links remain hidden/disabled through the same action builder path.`

## Evidence
- Screenshots saved: `YES`
- Video saved: `NO`
- Device evidence folder: `C:\Users\Hi-tech\.vscode\DIMAX Operations Suite\artifacts\device`
- Screenshot folder: `C:\Users\Hi-tech\.vscode\DIMAX Operations Suite\artifacts\screens`
- Results sheet: `C:\Users\Hi-tech\.vscode\DIMAX Operations Suite\ANDROID_QA_RESULTS.md`

## Latest device route smoke (historical APK)

- Date: `2026-08-15`
- Device: `2210129SG / Android 15`
- App package: `com.dimax.operations.installer`
- APK SHA-256: `22C2F9540E146483CD9E23F7AB5A5B5063059A792D63A61B9CEBD013482E4F35`
- Login/workspace: `PASS`
- Calendar: `PASS`
- Earnings: `PASS`
- Sync queue: `PASS`
- Project detail: `PASS`
- Brand fonts and icons: `PASS`
- Fresh SQLite bootstrap: `PASS`
- Offline cold start and online recovery: `PASS`
- Project Waze handoff: `PASS`
- Project WhatsApp chooser: `PASS`
- Project WhatsApp composer/prefill: `PASS by product-owner acceptance on 2026-06-16`
- Fresh RN/Android crash log: `PASS, no ReactNativeJS/AndroidRuntime/Expo errors after final route capture`
- Evidence:
  - `artifacts/device/android-2026-08-15-fonts-native-fixed.png`
  - `artifacts/device/android-2026-08-15-sync-serialized.png`
  - `artifacts/device/android-2026-08-15-project-local-first.png`
  - `artifacts/device/android-2026-08-15-offline-notice-fixed.png`
  - `artifacts/device/android-2026-08-15-online-sync-complete.png`
  - `artifacts/screens/android-case-01-project-waze-pass.png`
  - `artifacts/screens/android-case-02-project-whatsapp-chooser-blocked.png`

This evidence closed the gate for the 2026-08-15 APK only. It does not close the
gate for a newer binary.

## Current Android candidate

- Build date: `2026-08-22`
- Package: `com.dimax.operations.installer`
- Build: `PASS` (`:app:assembleDebug`, 386 Gradle tasks)
- Android policy: minSdk 24, targetSdk 34
- APK: `mobile/artifacts/android/dimax-installer-debug.apk`
- APK SHA-256: `2FF4362630E0E50412000F464FC9AED7341C5C659BD4C178ACB2C35AE61E7FA4`
- Physical-device interaction smoke for this hash: `NOT RUN`

## Decision rule

Set decision to `GO` only if:
1. All critical Android checks pass.
2. No crash occurs on secondary checks.
3. Evidence is saved.

Set decision to `NO-GO` if:
1. Any critical Android check fails.
2. There is a crash.
3. Localized prefill is wrong.
4. Waze or WhatsApp handoff is broken on device.

## Final decision
- Decision: `NO-GO`
- Blocking issue count: `1`
- Follow-up fix PR needed: `NO; verification is required before deciding whether code changes are needed`
- Release comment: `The current APK builds successfully but is not yet covered by fresh physical-device evidence.`

## Tester summary
- Device: `2210129SG / serial a269dc99`
- Android version: `15`
- Waze version: `5.19.0.2`
- WhatsApp version: `2.26.22.77`
- Build / environment: `Local preview debug APK + Metro E2E + API http://127.0.0.1:8000`

## Notes
- Use this sheet only after real Android device or emulator verification.
- If any critical check fails, open a narrow evidence-based fix PR instead of broad refactoring.
- Run `.\workspace.cmd android-qa-report` after filling `ANDROID_QA_RESULTS.md`.
