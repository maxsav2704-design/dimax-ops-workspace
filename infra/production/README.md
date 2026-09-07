# DIMAX Recommended Production Infrastructure

## Decision

Use DigitalOcean `fra1` for the first real DIMAX deployment:

- one Basic Droplet with 4 shared vCPU, 8 GiB RAM, and 160 GiB SSD;
- one managed PostgreSQL 16 cluster, starting at 2 GiB RAM;
- one Spaces Standard bucket for documents and imports;
- one private VPC containing the Droplet and PostgreSQL cluster;
- Caddy on the Droplet for automatic TLS and reverse proxy;
- GitHub Container Registry or DigitalOcean Container Registry for immutable images;
- daily Droplet backups and the managed database backup/PITR policy.

This is deliberately not Kubernetes. DIMAX currently needs reliable storage,
recoverable data, and predictable operations more than cluster orchestration.

## Runtime Topology

```text
Internet
  |
  +-- ops.<domain> -- Caddy :443 -- admin:5173
  |
  +-- api.<domain> -- Caddy :443 -- api:8000
                                      |
                                      +-- outbox worker
                                      +-- maintenance worker
                                      +-- sync GC worker
                                      +-- sync health worker
                                      |
                           private TLS/VPC
                              /          \
                  Managed PostgreSQL   Spaces (S3)
```

Only ports `80` and `443` are public. Restrict SSH `22` to trusted operator IPs.
Do not expose `8000`, PostgreSQL, or object-storage credentials to the internet.

## Estimated Monthly Cost

Pricing checked on 2026-08-28, before tax and domain fees:

| Resource | Recommended size | Approximate monthly cost |
|---|---:|---:|
| Basic Droplet | 4 vCPU / 8 GiB / 160 GiB | USD 48.00 |
| Managed PostgreSQL | 1 vCPU / 2 GiB | USD 30.45 |
| Spaces Standard | 250 GiB included | USD 5.00 |
| Daily Droplet backups | 30% of Droplet price | USD 14.40 |
| Total | | about USD 97.85 |

The 4 GiB Droplet and 1 GiB database reduce this to roughly USD 51 per month,
but the recommended tier leaves room for OCR, imports, reports, and concurrent sync.

## Provisioning Order

1. Register the final domain and create `ops` and `api` DNS records.
2. Create a `fra1` VPC and the 8 GiB Ubuntu 24.04 LTS Droplet.
3. Create managed PostgreSQL 16 in the same VPC. Allow only the Droplet as a
   trusted source and use the TLS connection string.
4. Create a private Spaces bucket in `fra1`. Keep object listing disabled and
   enable object versioning through the provider API.
5. Enable daily Droplet backups and a cloud firewall: public `80/443`, restricted
   `22`, deny all other inbound traffic.
6. Install Docker Engine and the Compose plugin on the Droplet.
7. Place the checked-out workspace at `/opt/dimax/app` and production secrets at
   `/opt/dimax/secrets/backend.env` with owner-only permissions.
8. Build and push backend/admin images tagged with their exact source SHA.
9. Copy `.env.example` to `.env.local`, replace every coordinate, and run the
   production validators before deployment.
10. Deploy, rotate the bootstrap password, run post-deploy and business smoke,
    then record the release evidence.

## Image Build

Build images on CI or a build machine, not on the production Droplet:

```bash
docker build -t <registry>/dimax-backend:git-<backend-sha> backend
docker build \
  --build-arg NEXT_PUBLIC_API_BASE_URL=https://api.<domain> \
  -t <registry>/dimax-admin:git-<admin-sha> \
  dimax-operations-suite-main
docker push <registry>/dimax-backend:git-<backend-sha>
docker push <registry>/dimax-admin:git-<admin-sha>
```

Use a registry digest in production when available. Never deploy `latest`.

## Server Layout

```text
/opt/dimax/app/                         checked-out release source
/opt/dimax/app/infra/production/        Compose overlay and Caddyfile
/opt/dimax/secrets/backend.env          backend secrets, mode 0600
/opt/dimax/app/infra/production/.env.local  non-secret deployment coordinates
```

Create the local files from the tracked examples. They are intentionally rejected
until the real domain, database, storage, images, and owner credentials are supplied.

## Validate And Deploy

```bash
cd /opt/dimax/app
chmod 600 /opt/dimax/secrets/backend.env
chmod +x infra/production/deploy.sh

./infra/production/deploy.sh --check
DIMAX_RUN_BOOTSTRAP=true ./infra/production/deploy.sh  # first deploy only
./infra/production/deploy.sh                           # later releases
```

Before the first deploy, run from the workspace root:

```powershell
.\workspace.cmd check-production-env
.\workspace.cmd test-production-infra
.\workspace.cmd release-handoff
```

The default infrastructure gate builds Next on the host and packages the generated
standalone runtime into Docker. This avoids Docker Desktop memory failures on the
4 GiB development machine while still testing the exact non-root runtime image.
CI runners with at least 4 GiB available to Docker should additionally run:

```powershell
.\workspace.cmd test-production-infra container
```

After deploy, follow `POST_DEPLOY_SMOKE.md`. A successful container start is not a
GO decision until role isolation, door import/assignment, completion, earnings,
reports, and sync health pass against the production API.

## Backup And Recovery

- Managed PostgreSQL provides daily backups and seven-day point-in-time recovery.
- Keep independent encrypted logical exports outside the database cluster account;
  provider backups disappear when the cluster is destroyed.
- Enable Spaces object versioning and lifecycle retention for document recovery.
- Test restore quarterly and before destructive schema changes.
- Record RPO of 24 hours for independent exports and RTO of four hours for the MVP.

## Scale Triggers

Upgrade the database or add a standby before one of these conditions persists:

- database memory above 70% during the working day;
- API p95 latency above 500 ms without an external provider delay;
- repeated sync lag above the operational threshold;
- more than 25 concurrent installers syncing during the same shift;
- OCR/import jobs noticeably delaying normal API traffic.

At that point, separate OCR/background workers onto a second Droplet before
considering Kubernetes.
