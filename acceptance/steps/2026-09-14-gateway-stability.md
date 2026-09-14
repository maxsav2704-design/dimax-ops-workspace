# Acceptance gateway stability

## Scope and evidence

Follow-up to the journal form checkpoint's intermittent browser failures.
Only the acceptance gateway and its regression fixtures change. Backend, admin,
mobile source and the production proxy are unchanged. No business mutations,
phone actions, signatures or deliveries are performed in this step.

The gateway logs confirm HTTP 502 on auth, projects, calendar and outbox reads:
`lookup api: i/o timeout`, upstream dial timeout/refusal and connection reset.
This explains why API readiness could be successful while browser requests failed.
Gateway-generated failures lacked API CORS headers, so the browser could report
them as a network failure instead of exposing their HTTP status. Unavailable
preflight requests can still appear as network failures; this is not an auth bypass.

The Docker network is IPv4-only and resolves through `127.0.0.11`. At inspection,
the gateway used 22.42 MiB of its 64 MiB limit with zero OOM/kill events; its CPU
quota had accumulated throttling. The exact host-level cause of DNS stalls is
not proven. This is a targeted mitigation and error-handling fix, not a claim
that Docker/Windows under arbitrary load can no longer time out.

## Changes

- `acceptance/Caddyfile`: use cached A-record discovery for service `api`, refresh
  every 30 seconds, resolve IPv4 only, and bound DNS/socket dialing to 5 seconds.
  There is no pinned container IP, external DNS server or added egress route.
- Expire idle proxy connections after 4 seconds, below Uvicorn's 5-second default.
  Keep proxy retries disabled: an accepted write with a lost response is ambiguous.
- Return structured `UPSTREAM_UNAVAILABLE` JSON with the original error status,
  `no-store`, and origin-varying CORS for exactly the two acceptance admin origins.
  Upstream validation/auth responses pass through unchanged. No wildcard origin.
- Added opt-in Node integration runner and a stdlib Python HTTP fixture. They use
  existing images (`--pull never`), separate labelled containers/network, no DB,
  no application network and no customer data. Ownership-checked cleanup runs in
  `finally`. Commands and interruption cleanup are documented in the README.

## Verification

- Caddy 2.11.4 `adapt` and `validate`: PASS, exit 0. The installed version accepts
  repeated single-value header matchers; the initial multi-value spelling failed
  validation and was never applied to the running gateway.
- First complete isolated run: 8 scenarios PASS (Node reports 9 including the
  parent test), 80.46 seconds, exit 0. Normal/idle writes execute once; lost-response
  writes execute once and return 502; allowed/untrusted/missing origins, upstream
  validation passthrough and unavailable/recovered API are covered.
- A subsequent run exposed an over-specific outage assertion: empty DNS discovery
  correctly returns 503, while a cached refused address returns 502. The fixture
  now asserts those two failure states and allows the configured 30-second DNS
  refresh during recovery. Lost-write 502 and exactly-once assertions are unchanged.
  Final rerun: all 8 scenarios PASS (9 Node tests including the parent), 148.40
  seconds, exit 0. No assertions about successful/duplicate writes were relaxed.
- The initial fixture client run was cancelled before completion and is NOT a
  pass. Its two labelled containers and network were inspected and removed;
  later runs use a bounded HTTP client and complete their own cleanup.
- Only `dimax_acceptance-gateway-1` was restarted. The API and DB were not stopped.
- Ten sequential `/ready` probes after deployment: 10 HTTP 200; observed response
  times 0.044 to 5.201 seconds. This is bounded evidence, not a latency SLO.
- Real API preflight from `http://127.0.0.1:4173`: HTTP 200 and matching credentials
  CORS headers. Unauthenticated `/api/v1/auth/me`: HTTP 401, not successful access.
- Browser: journal form, calendar and projects load without the earlier error gate.
  Stored QA journal has five installed doors; project remains 5/9 installed.
  No retries of any live write were performed.
- Both post-deployment gateway log inspections, including after the UI round trip,
  show zero error-level records since restart at `2026-09-14T20:25:31Z`.
- Final run's labelled containers and network were removed by the runner.
  No dependency installs, image downloads, screenshots, database copies or new
  build caches were needed. Node syntax check and `git diff --check`: PASS.

## Limits and next acceptance

Long-running load, Docker DNS outage injection and production infrastructure are
not certified. A cached empty/old address may delay recovery for up to the refresh
interval; this is documented, not silently treated as data loss. The new generic
gateway error message is English; localized admin wording is a follow-up UX item.
No full backend/admin/mobile release gate was rerun for this infrastructure-only
change. Next business block: PDF layout, signature and delivery in isolated Mailpit.
Do not treat this checkpoint as production approval or a GitHub backup.

## References

- [Caddy reverse proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy):
  cached dynamic A/AAAA discovery, transport and keepalive guidance.
- [Caddy error routes](https://caddyserver.com/docs/caddyfile/directives/handle_errors):
  preserve failure status without intercepting ordinary upstream HTTP responses.
