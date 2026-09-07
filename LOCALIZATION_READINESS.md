# Localization Readiness

Date: March 10, 2026

Scope closed in this cycle:

- frontend multilingual shell for `en`, `ru`, `he`
- admin routes localized:
  - `Operations`
  - `Reports`
  - `Projects`
  - `Issues`
  - `Journal`
  - `Installers`
- installer routes localized:
  - `Workspace`
  - `Project`
  - `Schedule`
- locale persistence via `localStorage`
- RTL support for Hebrew via `dir="rtl"`
- route-level and browser-level verification

What is now in place:

- `LanguageProvider` and `LanguageSwitcher`
- persisted locale key: `dimax_locale`
- automatic document language/dir updates
- English fallback for any future missing key
- explicit `ru/he` coverage for active admin and installer flows

Validation completed:

- targeted language switch tests passed
- admin localization test passed:
  - `src/test/AdminLocalization.test.tsx`
- installer suite passed:
  - `43 passed`
- installer strict local e2e passed:
  - `4 passed`
- production build passed

Operational conclusion:

- multilinguality is no longer a prototype layer
- `en / ru / he` is usable across the actual working product surface
- Hebrew is safe for RTL navigation and reload persistence

Residual risk:

- future new screens or copy can still regress if added without translation keys
- the right control is to keep all new UI copy behind `t(...)` and keep language tests in the gate

Recommended rule going forward:

- no new visible UI string without i18n key
- any new route with meaningful copy should add at least one localization assertion
