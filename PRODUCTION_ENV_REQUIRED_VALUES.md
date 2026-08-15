# DIMAX Production Env Required Values

Status on 2026-07-21: production deploy is blocked by missing real production env files and the owner-provisioned Android release keystore.

Required files:

- `backend/.env.production.local`
- `dimax-operations-suite-main/.env.production.local`
- `mobile/.env.production.local`

Use these examples as the source shape:

- `backend/.env.production.example`
- `dimax-operations-suite-main/.env.production.example`
- `mobile/.env.production.example`

## Backend Values

Required real values:

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

- `EMAIL_ENABLED=false`
- `WHATSAPP_ENABLED=false`
- `WHATSAPP_FALLBACK_TO_EMAIL=false`
- `TWILIO_WEBHOOK_VALIDATE=false`

If `EMAIL_ENABLED=true`, SMTP host/user/password/from must be real.

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

## Validation

Run from workspace root:

```powershell
.\workspace.cmd check-production-env
.\workspace.cmd release-status
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
