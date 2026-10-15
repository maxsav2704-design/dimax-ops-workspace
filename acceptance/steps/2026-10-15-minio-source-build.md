# MinIO source build acceptance

## Scope

Root workspace, workspace-test, demo, acceptance and work-price deployed
acceptance now share pinned server/client builds in `infra/minio`. They no
longer require the unavailable `minio/minio:latest` server image or the floating
`minio/mc:latest` initializer. Storage names, mount paths, application APIs,
price authority and earning calculations are unchanged.

The running local storage container was inspected but not replaced. Its data
has not been upgraded, exported or deleted. A real-data upgrade requires an
independent backup and a verified upgrade on a disposable copy. Production
remains on the existing managed S3 plan, not an archived community server.
The standalone backend repository's legacy Compose remains a separate task.

## Evidence

Code revision `aa28717c857c02475ab0014f4709b8e2a8bf3b2e`, branch
`codex/minio-runtime-20261015`:

[GitHub Actions run 38784533824](https://github.com/maxsav2704-design/dimax-ops-workspace/actions/runs/38784533824)
completed successfully in 6 minutes 49 seconds.

- Clean server and client builds from full upstream commit SHAs.
- Two Compose contract tests, including preserved volume identity and isolated
  test networking. Fixture env files are temporary and empty; no live env file
  is needed. The first CI attempt exposed this dependency and failed; it is not
  counted as a pass.
- Private bucket initialization twice, exact upload/download, anonymous object
  and listing denial, and exact object preservation after container recreation.
- Backend migrations/start, real HTTP and captured SMTP factory confirmation,
  separate authorized accrual, duplicate prevention, installer API receipt,
  earning reversal and isolated database backup/restore.
- Production admin build, real login and ledger browser checks at desktop and
  narrow widths. No API response mocks.
- Disposable S3 resources and the application test environment removed.

Local production-preflight regression: 14 passed, 6 Linux-only shell cases
skipped on Windows. This is not a claim that those six ran in this CI job.

## Remaining rollout gates

ADB found no connected device in either check on October 15. Real Android
SQLite/outbox completion of this workflow remains unverified in this step.
Public DNS, TLS certificates and actual external SMTP/mailbox delivery remain
unverified; captured Mailpit messages are not evidence of external delivery.
No new domain, hosting account, billing or real mail was configured.

The upstream MinIO community server is archived. Pinned source availability is
not ongoing security maintenance or a production support promise. Base images
and Go toolchain also need lifecycle maintenance. The CI emitted a Node 20
action-runtime deprecation warning; it did not fail the gate.

Unrelated in-progress AI and visual changes were left untouched and excluded
from the published branch, which starts from the previously published runtime
acceptance revision `ef7f697`.
