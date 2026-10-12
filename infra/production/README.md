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
6. Install Docker Engine, the Compose plugin and Python 3.11+ on the Droplet.
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
DIMAX_RUN_BOOTSTRAP=true ./infra/production/deploy.sh --check  # include owner credentials
DIMAX_RUN_BOOTSTRAP=true ./infra/production/deploy.sh  # first deploy only
./infra/production/deploy.sh                           # later releases
```

`--check` renders the effective Compose configuration, including the tools
profile, and validates it before any pull, migration or service change. It checks:

- a dedicated `dimax-production` / `dimax-staging` project name (optional suffix);
- HTTPS gateway hosts, API/app URLs and the admin-only CORS origin agree;
- every backend service passes the existing backend production-env validator;
- API and workers share the same database, JWT/mail encryption keys, storage,
  SMTP configuration and release image;
- release images use a source-SHA tag or digest, workers publish no ports,
  direct API/admin ports are loopback-only, and the mail worker has its health probe;
- bootstrap credentials only when `DIMAX_RUN_BOOTSTRAP=true` is explicitly set.

Compose reads `.env` files as data; the deployment script does not execute them
as shell code. Do not `source` them as an extra deployment step. Rendered secrets
remain in process memory/stdin and are not printed or written by the script.
`infra/production/.env.local` is Git-ignored, but backend secrets still belong in
the owner-only file outside the repository.

On an actual deploy, the same checks run first, followed by image pull and an
admin image metadata check: its recorded `NEXT_PUBLIC_API_BASE_URL` must match
the gateway API host, and its runtime user must be `10001:10001`. This guards
against choosing an image built for localhost; it is not cryptographic proof of
the bundled JavaScript. Build through the tracked Dockerfiles and use a digest
for the release. Migrations follow these checks; a failed migration stops the
script before `up`. Services start with a bounded health wait. Unrelated orphan
containers are not removed.

Passing `--check` is configuration evidence only: it does not resolve DNS, obtain
TLS certificates, connect to PostgreSQL/storage, send SMTP mail, prove factory
mailbox access, or inspect a downloaded admin image. Do not treat it as a release
GO or weaken validation to make the placeholder examples pass.

Before the first deploy, run from the workspace root:

```powershell
.\workspace.cmd check-production-env
.\workspace.cmd test-production-infra
.\workspace.cmd release-handoff
```

For a local, build-free Compose/Caddy syntax check:

```powershell
.\scripts\production-infra-contract.ps1 -ConfigOnly
```

This uses the already cached Caddy image with networking disabled; it never
cleans `.next`, images or existing containers. It is separate from the semantic
production preflight above, which intentionally rejects the example coordinates.

The default full infrastructure gate builds Next on the host and packages the
generated standalone runtime into Docker. It refuses to overwrite an existing
`.next`; use a separate checkout or the container build below in that case.
It restores the caller's build environment and only cleans output/resources
created by that invocation. Docker resources have unique names and ownership
labels. Both admin Dockerfiles launch the CommonJS standalone entry as
`server.cjs`, including when the package declares `type: module`.
CI runners with at least 4 GiB available to Docker should additionally run:

```powershell
.\workspace.cmd test-production-infra container
```

Regression tests (no real deployment or mail):

```powershell
node --test scripts/production-infra-contract.test.mjs
```

```bash
python3 -B -m unittest discover -s infra/production/tests -v
```

The Python shell-contract tests require Linux and an executable temporary
directory. If using a read-only test container, mount `/tmp` with `exec`;
the fake Docker command is created there. No Docker socket is needed.

After deploy, follow `POST_DEPLOY_SMOKE.md`. A successful container start is not a
GO decision until role isolation, door import/assignment, completion, earnings,
reports, and sync health pass against the production API.

## Trusted Proxy Boundary

The edge overlay pins Caddy to `DIMAX_PROXY_GATEWAY_IP` on a dedicated RFC1918
`DIMAX_PROXY_SUBNET` (defaults `172.30.254.2`, `172.30.254.0/29`). Choose an unused
subnet before deployment; check Docker networks and host/VPN routes for overlap.
Do not use the subnet's first host address, reserved for Docker's gateway.
Only Caddy's exact address is trusted by Uvicorn `FORWARDED_ALLOW_IPS`, never `*`
or the whole private range. Admin/Caddy share this network; workers stay off it.
This keeps distinct client IPs visible to existing per-process rate limits and
does not replace shared/gateway throttling for a multi-worker production setup.

The gateway denies framing through X-Frame-Options and CSP frame-ancestors,
and restricts base-uri. This is not a complete script-source/XSS CSP.

## Current Local Boundary

As of 2026-10-10, the owner confirmed that the domain and SMTP service are not
provisioned. Continue using the isolated local acceptance environment and mail
capture. Do not send localhost approval links to a real factory representative.
Before real use, supply the production coordinates/secrets, prove backup restore,
then verify the public HTTPS invitation, mailbox code, version confirmation and
separate administrator activation end to end. A local captured email is not
evidence of external delivery or representative authority.

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
