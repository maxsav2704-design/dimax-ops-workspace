# Public Demo Flow Readiness

Date: March 10, 2026

## Scope

This document records the public demo/front-door baseline for the current product branch.

Covered flow:

- public entry at `/welcome`
- secure entry at `/login`
- locale persistence across public and secure routes
- `en / ru / he`
- RTL behavior for Hebrew
- browser-level smoke for public and admin entry paths

## Implemented

- public landing route:
  - `dimax-operations-suite-main/app/welcome/page.tsx`
  - `dimax-operations-suite-main/src/views/PublicLandingPage.tsx`
- secure login route remains the protected handoff:
  - `dimax-operations-suite-main/app/login/page.tsx`
  - `dimax-operations-suite-main/src/views/LoginPage.tsx`
- multilingual public/demo entry:
  - `English`
  - `Русский`
  - `עברית`
- locale persistence via `localStorage`
- Hebrew `dir="rtl"` support
- route-based secure handoff:
  - `/login`
  - `/login?next=/installer`
  - route previews into admin/report/installer narratives
- public route metadata and share-ready page titles
- demo review/handoff docs:
  - `DEMO_REVIEW_PACK.md`
  - `SCREENSHOT_ROUTES.md`

## Validation

Validated locally on the current preview/build baseline.

Checks:

- `npm.cmd run build`
- `npm.cmd run test:e2e:smoke:local`

Browser smoke now covers:

- `/welcome`
- locale switch `en -> ru -> he -> en`
- locale persistence into `/login`
- installer secure entry handoff via `next=/installer`
- admin login and protected flow smoke
- admin locale persistence across `reports` and `operations`

## Operational Notes

- public entry is intentionally separate from protected admin/installer operations
- the public layer does not expose the control plane directly
- demo/showcase flow is now reproducible through browser smoke, not only visual review

## Remaining Risks

- copy quality in `ru/he` is functionally covered, but future changes can still regress if new strings bypass `t(...)`
- preview/demo reliability still depends on local preview or future staging infrastructure
- `login-preview.png` in workspace is only a local artifact and not part of the baseline

## Readiness

Public demo/front-door baseline is considered ready on the current branch.
