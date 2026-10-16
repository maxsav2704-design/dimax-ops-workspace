# Physical device: separately approved work price

## Scope and result

PASS for one physically entered missing-rate door command through offline
retention, factory confirmation, separate administrator accrual, mobile ACK and
earnings after a cold start. This is not full release or production acceptance.
Continuation of `2026-10-15-device-price-preparation.md`.

The existing Android debug installation and mobile source
938e4103a912c75be43aac6733cea1d5099dc707 were used. No APK reinstall, application
data reset, password reset, security-setting change or mobile SQLite write was
performed by the operator. The API uses the existing isolated database on 0074.
Its bind-mounted backend contains unrelated local changes, so this is not proof
of an immutable release image. All work, mail and amounts below are synthetic.

## Preparation defect fixed

`seed_new_work` created the initial project/door directly but did not publish
sync metadata. With an empty company change log, cursor zero did not trigger a
cold snapshot and the fresh installer saw no projects. `device_work_price.py`
now publishes PROJECT_BASE and DOOR using the existing payload builders and UOW.
It checks the owned test company, expected stage, assignment and unlocked door;
it refuses publication once any work or sync event exists. An existing log is
not republished. It does not create performed work or change prices/assignments.

Five guard tests pass, including first publication, repeated publication, foreign
assignment/project, locked door, later stage, and refusal after work/events.
An actual `publish` after phone submission was also rejected without mutation.

## Observed chain

1. The user normally signed out of Test Installer A-1. Existing development-only
   auto-login signed in the separate Device Test Installer on API 8001. A new
   company/user SQLite file was created; the old database was retained. Read-only
   inspection showed exactly the owned project and RUNTIME-101, no A-1 projects.
2. Only the phone's API USB reverse mapping was removed. The user physically
   pressed Installed. SQLite retained the real DOOR_SET_STATUS command with its
   original timestamp. Earnings remained zero. No HTTP/SQL command was fabricated.
3. A second ADDON_FACT_CREATE, quantity 1, was also created on the phone 31 seconds
   later. It was preserved, not deleted or included in the door approval. It has
   no approved price and remains separately blocked without earnings.
4. The API mapping was restored. A transient network failure delayed the door's
   retry; the original event was subsequently retained as CONFLICT_FACTORY_PRICE.
   Both phone and server showed the pricing block, with zero earnings. The mobile
   door returned to authoritative IN_PROGRESS until the work was resolved.
5. `review` found the actual door command, proposed 9.01 ILS for that exact work,
   delivered the invitation to Mailpit and confirmed using the separate mailbox
   code. The ledger remained empty. The phone still had both blocked events and
   a zero earnings snapshot after confirmation. No external factory was contacted.
6. `accrue` performed explicit administrator review/consent and accrual. Repeating
   the identical request returned the same receipt, without a second ledger row.
7. The app was fully force-stopped and cold-launched using Metro with development
   auto-login disabled. No data was cleared. Its authenticated session survived.
   Normal sync acknowledged only the resolved door command; the unrelated addon
   remained blocked. The local door became INSTALLED, version 1.
8. Read-only SQLite verification after cold start: integrity ok; correct owner;
   one project, one door, one remaining blocked addon; today and month earnings
   both 9.01 ILS. The actual earnings screen showed 9.01, one work, one project
   and current data. A local screenshot was inspected, not published.
9. Independent SQL after cold start/repeated sync: exactly one ORIGINAL DOOR row,
   quantity 1.00, rate/amount 9.01. `completed_at` matched the original phone
   execution time, not the later accrual time. The door event had no apply error;
   the addon retained CONFLICT_FACTORY_PRICE. `verify` confirmed the active
   company price list and its one item were unchanged.

## Evidence and limits

- `python -B -m unittest discover -s acceptance -p test_device_work_price.py -v`.
- Real isolated API stages: `publish`, `review`, `accrue`, `verify`.
- Actual Android launch reported COLD; Node 20.19.5 served the device bundle with
  HTTP 200. Only the session-owned Metro process tree was stopped afterward.
- SQLite plus WAL were copied for read-only inspection into an automatically
  removed temporary directory. No application DB/queue was edited.
- The private fixture/credentials and local screenshot remain under ignored
  `artifacts/device/price-chain`; they are excluded from the GitHub backup.
- Do not call the whole queue empty: the separate unapproved addon remains.
- Public HTTPS/domain, external SMTP delivery, a release APK, working-volume
  MinIO migration and the complete release matrix remain separate gates.
- Network delays on the 4 GB host caused retries and cached-earnings UI before
  recovery. This run establishes retention/recovery, not a performance SLA.
- The debug warning overlay and Russian singular wording on the earnings screen
  remain UI follow-ups, not silently claimed fixed by this financial acceptance.

## Handoff

The user confirmed normal logout with queue preservation. A read-only check of
the now-closed synthetic SQLite still showed its 9.01 earnings and blocked addon.
Test Installer A-1 was restored through ordinary authentication using the existing
saved test credentials. Development auto-login was then disabled and the normal
bundle cold-launched again. The phone showed A-1; its SQLite had the correct owner,
the original Excel acceptance project, seven assigned doors and an empty queue.
The synthetic project/door did not appear in that database.

All session-owned Metro processes were stopped; port 8081 had no listener. Only
the two temporary `/sdcard/dimax-price-*` inspection files were deleted from the
phone. The local protected evidence folder contains one 205 KB screenshot and
the small private fixture session, not APKs, bundles or copied mobile databases.

The acceptance containers were stopped, not removed. The four ordinary workspace
containers were started again, preserving all volumes. The first three-minute
readiness wait expired during slow startup without a restart. A subsequent real
GET of `http://127.0.0.1:8000/ready` returned status ok and database ready; the logs
confirmed application startup complete. Phone A-1 remains scoped to test API 8001,
which is stopped to respect the agreed one-stack RAM limit; its offline cache is
retained. Do not silently repoint that identity at the different ordinary database.

## Addon follow-up

The separately retained addon was subsequently accepted in
`2026-10-16-device-addon-price-chain.md`. The blocked-addon state above records
this earlier door checkpoint, not the outcome of the later addon acceptance.
