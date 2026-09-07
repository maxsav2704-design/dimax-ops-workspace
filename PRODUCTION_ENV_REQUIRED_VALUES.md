# DIMAX Production Env Required Values

Status on 2026-08-28: application code and staging gates are ready. Production deploy
remains blocked by missing real production env files, unpublished release commits,
and the owner-provisioned Android release keystore.

Required files:

- `backend/.env.production.local`
- `dimax-operations-suite-main/.env.production.local`
- `mobile/.env.production.local`
- `infra/production/.env.local` on the deployment server

Use these examples as the source shape:

- `backend/.env.production.example`
- `dimax-operations-suite-main/.env.production.example`
- `mobile/.env.production.example`
- `infra/production/.env.example`

## Infrastructure Values

Required non-secret deployment coordinates:

- `DIMAX_ADMIN_IMAGE`: immutable admin image built with the production API URL.
- `DIMAX_API_HOST`: public API hostname without a URL scheme.
- `DIMAX_ADMIN_HOST`: public admin hostname without a URL scheme.
- `DIMAX_TLS_EMAIL`: owner address used for ACME certificate notices.
- `DIMAX_BACKEND_ENV_FILE`: absolute server path to the protected backend env file.
- `DIMAX_CADDYFILE`: absolute server path to `infra/production/Caddyfile`.

Use `infra/production/README.md` for the recommended topology, provisioning order,
estimated cost, image build, firewall, backup, and deployment procedure.

## Backend Values

Required real values:

- `DIMAX_BACKEND_IMAGE`: immutable registry image reference. Use a `sha256` digest or
  a release tag ending with the 12-64 character source commit SHA.
- `DATABASE_URL`: real PostgreSQL URL, not local Docker, with `sslmode=require`, `verify-ca`, or `verify-full`.
- `JWT_SECRET`: random production secret, at least 32 characters.
- `PUBLIC_BASE_URL`: HTTPS API URL, for example `https://api.your-domain.com`.
- `CORS_ALLOW_ORIGINS`: HTTPS admin URL, for example `https://ops.your-domain.com`.
- `MINIO_ENDPOINT`: real S3/MinIO endpoint, not `minio:9000`.
- `MINIO_ACCESS_KEY`: real storage access key.
- `MINIO_SECRET_KEY`: real storage secret key.
- `MINIO_BUCKET`: production bucket name.
- `MINIO_SECURE=true`.
- `SEED_ADMIN_EMAIL`: real owner/admin email.
- `SEED_ADMIN_PASSWORD`: strong temporary bootstrap password, rotate after first login.

The one-shot production bootstrap creates the initial company, OWNER admin profile,
default company plan, door types, and operational reasons. API and worker containers
mask the seed email/password; the values are exposed only to the bootstrap service.

Can remain disabled for MVP if not used yet:

- `EMAIL_ENABLED=true`
- `WHATSAPP_ENABLED=false`
- `WHATSAPP_FALLBACK_TO_EMAIL=false`
- `TWILIO_WEBHOOK_VALIDATE=false`

SMTP host/user/password/from must be real. Production validation blocks release when email is disabled because signed journal PDFs must be delivered to the developer and administrators.

If `WHATSAPP_ENABLED=true`, Twilio WhatsApp credentials, HTTPS callback, and signature validation must be real. Without Twilio credentials, email fallback is allowed only when SMTP is fully enabled.

`OUTBOX_WEBHOOK_TOKEN` can remain empty only when the generic provider webhook is not used. An empty value makes that endpoint return `403`; an enabled token must contain at least 32 characters.

## Admin Values

Required real values:

- `NEXT_PUBLIC_API_BASE_URL`: the same HTTPS API URL as backend `PUBLIC_BASE_URL`.

Optional:

- `VITE_API_BASE_URL`: set only if legacy Vite paths are still used; if set, it must exactly match `NEXT_PUBLIC_API_BASE_URL`.

## Mobile Values

Required real value:

- `EXPO_PUBLIC_API_BASE_URL`: the same non-local HTTPS API URL as backend
  `PUBLIC_BASE_URL` and admin `NEXT_PUBLIC_API_BASE_URL`.

Android release tasks fail closed when this value is missing, uses HTTP,
localhost, credentials, query/fragment data, or a placeholder host.

## Android Signing Values

Provide these values only in the protected release environment. Do not commit the
keystore or its passwords to any DIMAX repository:

- `DIMAX_ANDROID_KEYSTORE_FILE`: absolute path to the readable production keystore.
- `DIMAX_ANDROID_KEYSTORE_PASSWORD`: keystore password.
- `DIMAX_ANDROID_KEY_ALIAS`: production signing key alias.
- `DIMAX_ANDROID_KEY_PASSWORD`: signing key password.

The release build intentionally fails when any value is absent, the keystore cannot
be read, the mobile API URL is not production-safe, or Android release signing falls
back to the debug key.

## Release Source

All four reviewed release commits must be pushed before deployment so the workspace,
backend, admin, and mobile source SHAs are recoverable and match the evidence bundle.
Publishing source is an explicit owner action and is not performed by the local gates.

## Validation

Run from workspace root:

```powershell
.\workspace.cmd check-production-env
.\workspace.cmd source-readiness
.\workspace.cmd release-status
.\workspace.cmd release-handoff
```

Production can be marked `GO` only when `check-production-env` passes.

The validator intentionally rejects:

- `localhost`
- `127.0.0.1`
- Docker service URLs such as `db:5432` or `minio:9000`
- `example.com`
- `replace-*`
- `placeholder`
- `change-me`
- weak default secrets
