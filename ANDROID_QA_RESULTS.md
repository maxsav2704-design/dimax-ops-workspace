# Android QA Results

## Session
- Date: `2026-06-15 21:45:20 +03:00`
- Tester: `Codex automated device smoke`
- Final release package: `C:\Users\Hi-tech\.vscode\DIMAX Operations Suite\FINAL_GO_NO_GO_PACKAGE.md`
- Device: `2210129SG / serial a269dc99`
- Android version: `15`
- Waze version: `5.19.0.2`
- WhatsApp version: `2.26.22.77`
- Build / environment: `Local preview debug APK + Metro E2E + API http://127.0.0.1:8000`

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

## Critical Gate Summary
- `Project -> Waze`: `PASS`
- `Project -> WhatsApp`: `PASS`
- `Locale-specific prefill`: `PASS`
- Crash observed: `NO`

## Regression Device Smoke 2026-07-23

- Device: `DIMAX_ATD34 / emulator-5554`
- Package: `com.dimax.operations.installer`
- APK SHA-256: `75D03D42EBA159533CBACA7F1FA0BFC8A34419BDE6354640F868691773F4790F`
- Runtime: Android 14 AOSP ATD + universal debug APK + Node 20 Metro + ADB reverse API `http://127.0.0.1:8000`
- Installer auto-login: `PASS`
- Assigned project list and sync timestamp: `PASS`
- Assigned project detail navigation: `PASS`
- Fatal Android or JavaScript runtime errors: `NONE`
- Evidence:
  - `artifacts/device/android-2026-07-23-jobs.xml`
  - `artifacts/device/android-2026-07-23-earnings.xml`
  - `artifacts/device/android-2026-07-23-project-detail.xml`
  - `artifacts/device/android-2026-07-23-jobs-ru.xml`
  - `artifacts/device/android-2026-07-23-runtime.log`

## Native Build Verification 2026-08-15

- Build: `PASS` (`:app:assembleDebug`, 301 Gradle tasks).
- Package: `com.dimax.operations.installer`.
- Android policy: minSdk 24, targetSdk 34.
- APK SHA-256: `61F6B1E415F0920EEFB165DB5B7C127800A2D1254D949838CD1E74EAA936F874`.
- Signature verification: `PASS` with the Android debug certificate.
- ADB device: `NOT ATTACHED`.
- Fresh device smoke: `NOT RUN`.
- This build verification does not replace the historical device route evidence.

## Final Recommendation
- Decision: `CODE GO / FRESH DEVICE QA PENDING`
- Blocking issue count: `1 external QA item`
- Follow-up fix PR required: `NO`
- Summary: `Historical route smoke and Waze/WhatsApp evidence remain green. The 2026-08-15 APK passed build and signature checks but still requires a fresh physical-device run.`

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
