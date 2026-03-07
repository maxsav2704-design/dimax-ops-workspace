# v1.1 Product Backlog

Status date: March 7, 2026

This backlog starts after `v1.0.1` hardening is complete.

## Priority 1

### Installer web: execution speed

- bulk actions for door completion / not-installed flow where business rules allow it
- clearer daily agenda view for installer schedule
- faster door filtering/search inside project details

Reason:

- this is the shortest path to measurable installer productivity in the shipped web-first baseline

### Admin visibility: operational queue health

- dedicated admin screen/widget for:
  - failed imports
  - failed outbox deliveries
  - sync health anomalies

Reason:

- operators should not need to infer critical queue state from raw logs only

## Priority 2

### Project/import UX

- better diagnostics presentation for failed import rows
- simpler retry/reconcile flow for recent import runs
- stronger import mapping profile usability

### Installer issue workflow polish

- clearer issue status transitions
- better issue-to-door navigation
- tighter reason/comment visibility for not-installed cases

## Priority 3

### Reporting and audit polish

- export-ready operational reports
- clearer trend/report filters
- faster path from report anomaly to concrete project/installer/action

### Integration ergonomics

- cleaner admin setup UX for email/whatsapp/webhook integrations
- explicit last-success / last-failure visibility

## Optional later

### Mobile return path

- resume mobile only after web-first installer flow saturates its value
- use web telemetry/support feedback to define the real mobile scope

## Delivery rule

For every backlog item:

1. define business outcome first
2. keep repo boundaries intact
3. add or update tests with the change
4. ship through PR + required gates
