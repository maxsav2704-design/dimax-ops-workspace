# Separate work-price chain: physical-device preparation

## Status

PREPARED, NOT a completed physical-device acceptance. No production readiness
percentage is claimed. The phone has not yet submitted the new test work.

## Observed baseline

- Android device a269dc99, package com.dimax.operations.installer, existing debug
  APK and current Metro JavaScript. No reinstall, app-data clear or password reset.
- Mobile source: 938e4103a912c75be43aac6733cea1d5099dc707, clean tree.
- Current account: Test Installer A-1, DIMAX Acceptance A. Its queue was inspected
  through the actual sync-queue screen: zero pending, failed and blocked commands.
  The phone showed a fresh successful sync after the test API was restored.
- Acceptance A has zero factory-price activations. Its legacy earnings cannot be
  presented as proof of the new factory-confirmed work workflow.
- Acceptance database is on 0074_work_price_accruals. Existing containers were
  stopped; the worker was restarting because its database was unavailable.
  Starting the database restored the worker. No schema change was needed.
- Two concurrent stacks plus Metro on the 4 GB host delayed API startup. Only
  about 264 MiB physical RAM was free. The user explicitly authorized temporarily
  stopping the four ordinary DIMAX containers, retaining every volume, for this
  phone check. API readiness subsequently became healthy.

## Added acceptance code

- `acceptance/device-price.compose.yml`: opt-in message-content URL
  https://dimax-device.example.test for the isolated API/worker only. Mail remains
  captured in Mailpit on the internal Docker network. This does not provide
  public HTTPS, DNS or external delivery, or relax the application URL guard.
- `acceptance/device_work_price.py`: guarded, staged fixture/proposal/accrual
  helper reusing the HTTP/SMTP helpers from `work_price_runtime.py`. A new company,
  new random test credentials and a new test project are used. Existing users,
  company prices and earnings are not reset or changed. The script never submits
  an installer command: `review` requires exactly one matching retained command
  from the phone's project, installer and door. Confirmation and accrual remain
  separate stages. An interrupted accrual preserves its request ID for retry.
- `acceptance/test_device_work_price.py`: rejects other environments/databases,
  external SMTP/WhatsApp, non-test link URLs, foreign/missing/ambiguous commands.

## Executed checks

1. Two acceptance guard tests passed (including multiple rejection cases).
2. Mobile Node 20.19.5: five suites, 137 tests passed: sync service, cold resync,
   account isolation, earnings service and earnings contract. No new APK built.
3. `prepare` ran against real API, worker and Mailpit: OWNER test contact,
   initial price list, invitation, separate mailbox code, confirmation, activation.
   The missing-rate door/catalog entries were created only after activation.
4. Independent SQL check of the new synthetic company: one activation, one door,
   zero completed-work rows, zero sync events. Thus preparation did not invent
   completed work or earnings. Company: DIMAX Device Price Acceptance 20261015;
   project: Device price acceptance; door: RUNTIME-101.
5. A real `review` attempt before any phone action was correctly rejected with
   "Expected exactly one retained phone door command; no command was created".
   This is a negative guard check, not a successful proposal/confirmation test.

The private fixture session is in the API container at
`/tmp/dimax-device-price.json`, backed up locally in the ignored
`artifacts/device/price-chain/private-session.json`. That directory has restricted
Windows ACLs for the current user and SYSTEM. Never publish it, print it, add it
to artifacts in GitHub, or include it in a bulk commit. The generated password
belongs only to the synthetic company. No working credentials were retrieved.

## Resume in order

1. Start only the existing acceptance containers when resources permit. Do not
   rebuild MinIO or upgrade an existing storage volume for this check. If the API
   container was recreated, restore the two scripts to `/tmp` and the ignored
   private session; do not rerun `prepare` or create another fixture.
2. Start `scripts/mobile-metro.ps1` with Node 20, API 8001 and one worker; restore
   the 8081/8001 adb reverse mappings. Verify `/ready` from the host, not merely
   that Docker says running.
3. Complete the ordinary sign-out from A-1, preserving local work. USB navigation
   taps did not switch the screen in this session; deep links and screenshots
   worked. A physical sign-out was requested. No device security setting changed.
4. Sign in to the new synthetic installer through the login form. Verify only
   its project/door is visible, not the old Acceptance A data. Preserve the known
   A-1 credentials locally for restoration; do not reset any password.
5. Disconnect only the application's API transport, mark RUNTIME-101 installed
   once on the phone, inspect its SQLite queue, then reconnect. Expect a retained
   price conflict and no earnings. Do not fabricate this event through HTTP/SQL.
6. Run `review` inside the test API with PYTHONPATH=/app:/tmp. It creates a scoped
   proposal and confirms through Mailpit. Verify the phone is still blocked and
   earnings remain zero: factory confirmation alone must not accrue.
7. Run `accrue`; verify 9.01 ILS once, including identical-request retry. Sync on
   the phone; inspect actual queue removal and visible canonical earnings, then
   repeat sync and cold-start to rule out duplicate/lost earnings. Run `verify`
   for independent ledger and unchanged company-price checks.
8. Restore A-1 and the ordinary workspace services; stop only this test session's
   processes if RAM is constrained. Keep the fixture evidence for audit.

`review`, `accrue`, `verify`, physical offline execution, factory-work confirmation,
phone ACK, visible 9.01 ILS and account restoration are not yet accepted. The
earlier deployed CI checks are separate evidence, not substitutes for these gates.
No real factory/customer was contacted. Domains, external SMTP and working-volume
storage upgrade remain separate release gates.

## Session handoff

The phone still showed the A-1 profile when the physical sign-out request was
sent. Pending that input, the six acceptance containers were stopped (not removed)
and only the Metro process tree started for this session was stopped. The four
ordinary workspace containers were started again. The private fixture and all
test/working volumes were retained. No automatic account switch or offline queue
edit was performed. Unrelated AI/backend and admin-design edits were not changed.
