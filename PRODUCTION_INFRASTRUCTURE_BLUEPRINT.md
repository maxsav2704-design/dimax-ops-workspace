# DIMAX Production Infrastructure Blueprint

Status: recommended target topology. No production infrastructure is provisioned yet.

## 1. Topology

```text
Internet
  |
  +-- ops.dimax.<tld>  -> CDN/WAF/TLS -> Next.js admin + public acceptance page
  |
  +-- api.dimax.<tld>  -> WAF/TLS -> reverse proxy -> FastAPI (2 replicas)
                                             |
                                             +-- PostgreSQL 16
                                             +-- S3-compatible private storage
                                             +-- SMTP provider
                                             +-- outbox-worker
                                             +-- sync-health worker
                                             +-- sync-gc worker
                                             +-- maintenance worker

Expo mobile -> HTTPS API only. The mobile app never connects to PostgreSQL,
object storage, or SMTP directly.
```

## 2. Recommended Services

| Area | Recommended production service | Required behavior |
|---|---|---|
| DNS/TLS/WAF | Cloudflare or an equivalent managed edge | TLS 1.2+, HTTP to HTTPS redirect, rate limiting, separate `ops` and `api` hosts |
| Admin/public web | Container platform or managed Node hosting | Immutable image, two instances during rolling deployment, `/acceptance/{token}` publicly reachable |
| Backend API | Container platform, two replicas | Private runtime network, `/health` liveness, `/ready` readiness, no direct public port |
| PostgreSQL | Managed PostgreSQL 16 | Private endpoint, encrypted disk, TLS, daily backup, point-in-time recovery, restore drill |
| PDF storage | Managed S3 or private MinIO | Private bucket, encryption, versioning/lifecycle, access only through short-lived backend tokens |
| Email | Transactional SMTP provider | Verified DIMAX sender/domain, TLS, delivery/bounce monitoring; required for signed journal PDFs |
| Workers | Same immutable backend image | Exactly one deployment per worker type initially; independent restart and logs |
| Secrets | Platform secret manager | Separate staging/production values, no secrets in Git or image layers |
| Monitoring | Central logs + metrics + alert delivery | API 5xx/readiness, worker failures, outbox backlog, sync health, DB capacity, backup failures |

## 3. Network Boundaries

- Public: edge proxy only. PostgreSQL, S3/MinIO, and worker processes have no public ingress.
- Application: admin/public web may call only the HTTPS API origin.
- Data: only backend API and workers can reach PostgreSQL and object storage.
- SMTP: outbound TLS from the outbox worker only.
- CORS: production admin origin only; no wildcard and no localhost.
- File access: private objects are returned only through expiring, audience-bound download tokens.

## 4. Environments

Use two isolated environments before real operation:

1. `staging`: separate database, bucket, SMTP sandbox, admin users and mobile build.
2. `production`: real customer data, verified SMTP domain, protected backups and alert recipients.

Never share a database, object bucket, JWT secret, SMTP credentials, or seed account between them.

## 5. Initial Capacity

Start conservatively and scale from measurements:

- API: 2 replicas, 2 web workers each, 1-2 vCPU and 2 GB RAM per replica.
- PostgreSQL: 2 vCPU, 4 GB RAM, 50 GB encrypted SSD with automatic storage growth.
- Workers: 1 replica of each worker, 0.5-1 vCPU and 512 MB-1 GB RAM.
- Object storage: 50 GB initial capacity with lifecycle monitoring.

These are starting values, not guaranteed sizing. Confirm them with staging load tests and the actual number of projects, doors, mobile sync events, imports and PDFs.

## 6. Deployment Order

1. Build backend/admin images once and identify them by digest.
2. Validate production environment files; all validators must pass.
3. Back up PostgreSQL and verify the latest restore point.
4. Run the one-shot `migrate` service and verify Alembic head.
5. Deploy API and wait for `/ready`.
6. Deploy workers from the same backend image digest.
7. Deploy admin/public web and run login, installer RBAC and signing smoke tests.
8. Sign a staging journal and verify the attached PDF reaches the developer mailbox and admin copy.
9. Run backup/restore and mobile cold-resync drills before the production go-live decision.

## 7. Go-Live Blockers

- Real domain names and TLS certificates are not configured.
- Managed PostgreSQL/S3 and a tested backup destination are not provisioned.
- SMTP provider, verified sender and administrator delivery addresses are not configured.
- Production secrets and alert recipients are not installed in a secret manager.
- Android production configuration/device release test is not signed off.
- Staging migration, restore, role-isolation, offline-resync and signed-PDF delivery drills have not passed.

Until these items are closed, the repository can be release-ready source code, but the product is not production-operational.
