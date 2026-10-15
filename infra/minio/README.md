# Local object storage builds

Workspace, workspace-test, demo, acceptance and deployed work-price acceptance
use this shared source build instead of pulling `minio/minio:latest` or
`minio/mc:latest`. Existing service names, credentials, buckets, volume names
and `/data` mount paths are unchanged. No working container is replaced by
editing these files.

## Source identity

- Server: `minio/minio` commit `9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a`
  (`RELEASE.2025-10-15T17-29-55Z`), image `dimax-minio:source-9e49d5e`.
- Client: `minio/mc` commit `7394ce0dd2a80935aded936b09fa12cbb3cb8096`
  (`RELEASE.2025-08-13T08-35-41Z`), image `dimax-mc:source-7394ce0`.
- Both use Go 1.24.8, read-only module manifests and a non-floating source SHA.
  Base-image tags and module registries still require network access; this is
  not a hermetic or byte-identical build. The final images include upstream
  licenses, source/revision labels and CA certificates.

The [server repository](https://github.com/minio/minio) is archived and its
community distribution is source-only. This restores local build availability;
it is not a claim of ongoing upstream security maintenance. Do not expose these
test credentials or local storage ports publicly. Production keeps the managed
S3 scheme described in `infra/production/README.md`; no customer-file migration
or new storage provider is introduced here.

## Check without changing the running application

From the workspace root:

```sh
python -B -m unittest discover -s infra/minio -p 'test_*.py' -v
python -B infra/minio/smoke.py
```

The first command parses Compose without loading backend env files, building
images or starting containers. The second needs a build host with sufficient
RAM/disk, downloads official build dependencies and starts a unique
`dimax-minio-check-*` project. It exposes no host ports and uses only synthetic
data. It checks private bucket initialization, upload/download, denial of
anonymous reads/listing and file survival after container recreation. Its own
volume and containers are removed in `finally`. It never prunes shared images
or build caches and never accepts an external cleanup project name.

CI also runs the deployed factory-confirmation/accrual scenario against this
same server build. No phone, real SMTP mailbox or public HTTPS is implied.

## Existing local data

Do not run an unreviewed `up --build` against the working storage just to test
this patch. First inventory the running image and volume, make an independent
backup, and verify an upgrade on a disposable copy. The smoke above verifies
new-format persistence, not an upgrade of existing customer data. Never remove
the old image or volumes until backup restoration and the copy upgrade pass.

On a suitable build machine, build with:

```sh
docker compose -f docker-compose.workspace.yml build minio minio_init
```

Compose uses `pull_policy: build` so a cold checkout does not depend on an
unpublished image in a registry. A constrained local machine may use images
transferred from a trusted build host and an explicit `--no-build --pull never`
when performing an approved upgrade. Do not start a large source build on the
4 GiB development machine while the application and Docker are under load.

The independent backend repository still contains its legacy standalone
`backend/docker-compose.yml`. Its `latest` references need a separate scoped
change/release; use the root workspace configurations covered by this gate.
