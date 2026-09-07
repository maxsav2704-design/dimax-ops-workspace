# Public Landing Readiness

Date: March 10, 2026

## Scope closed

- added public route:
  - `dimax-operations-suite-main/app/welcome/page.tsx`
- added public view:
  - `dimax-operations-suite-main/src/views/PublicLandingPage.tsx`
- linked secure login to the public entry layer:
  - `dimax-operations-suite-main/src/views/LoginPage.tsx`

## What the landing now covers

- premium public-facing product entry
- route-driven previews for:
  - `Operations`
  - `Reports`
  - `Installer Web`
- trust / readiness layer:
  - preview baseline
  - multilingual and RTL readiness
  - release-discipline signals
- architecture strip for:
  - `Projects`
  - `Issues`
  - `Journal`
  - `Installers`
- use-case narrative:
  - admin recovery day
  - installer execution day
- audience framing:
  - who this is for
  - who this is not for
- closing CTA flow into secure admin and installer routes

## Localization

- public landing strings are covered in:
  - `en`
  - `ru`
  - `he`
- Hebrew keeps RTL behavior through the existing i18n provider

## Validation

- `npm.cmd test -- src/test/PublicLandingPage.test.tsx src/test/LanguageSwitcher.test.tsx`
- `npm.cmd run build`
- `http://127.0.0.1:5174/welcome` responded with `200`

## Known issue

- `.\workspace.cmd preview-web status` currently reports:
  - `http://localhost:5174/login -> 500`
- this does **not** block the public landing route itself
- it should be fixed before presenting the secure login flow as part of the same demo

## Recommendation

- treat `/welcome` as the public demo/front-door route
- treat `/login` recovery as the next follow-up item before calling the preview flow fully demo-clean
