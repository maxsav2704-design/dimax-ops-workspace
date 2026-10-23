# Commercial contract and price confirmation: remaining acceptance (2026-10-22/23)

Continues `2026-10-21-commercial-approvals.md`. Owner's instruction (chat, 2026-10-22): finish the
remaining backend checks in an isolated database, the installer-rate regression, a production admin
build, the real HTTP/JWT chain OWNER → invitation → factory review → mailbox code → consent →
admin history, forbidden roles and foreign tenant, stale versions and replays, persistence across an
API restart and the downgrade refusal, desktop / RU 390 px / HE 768 px. Owner also chose the new
section name "Договоры и оплаты" (EN "Contracts & billing", HE "חוזים וחיובים").

Marks: **confirmed by tests**, **studied by code**, **seen live** (browser pane, disposable stack),
**not verified**, **needs external infra**.

## 1. Migration chain reconciled

The predecessor `0083_import_inbox` is now committed (backend `244ebc5`, 2026-10-21). Its SHA256
`34c4d9a3…b84c` equals the hash the commercial chain was tested against; `0086` recreates the audit
actor check including the import-inbox rule. The working database reached `0086_commercial_approvals`
when the working API restarted after a host reboot (its start command runs `alembic upgrade head`);
schema only, no data changed by this acceptance.

## 2. Backend checks (isolated `dimax_acceptance_tests` database, workspace image Python 3.12)

| Check | Mark | Evidence |
|---|---|---|
| 42 commercial price draft cases that had not finished | confirmed by tests | `test_commercial_drafts.py`: 42 passed |
| All 88 commercial cases in one command (approvals 16, contract terms 30, drafts 42) | confirmed by tests | one run, 88 passed |
| Factory contact authority + mailbox verification | confirmed by tests | 28 passed, 1 skipped (`DIMAX_FACTORY_MAILPIT` not set: needs isolated Mailpit) |
| Installer work-price regression: accruals, approvals, proposals | confirmed by tests | 110 passed in 6 min 27 s |
| Factory price regression (lists, approvals, activation, application check, review, reconciliation, sync, timeline, write boundary) | confirmed by tests | 9 files, 262 passed in 8 min 02 s |

Two earlier attempts of the work-price regression stalled: the admin dev server ran next to the test
container (45 MB free, 13.3 of 14 GB commit charge) and the Docker engine answered HTTP 500; the owner
approved a Docker Desktop restart. A pipeline ending in `tail` had reported exit 0 for a run that never
printed a pytest summary; that run is not counted. The runner now records pytest's own exit code.

## 3. Admin build and tests (host Node 25.5.0; the package declares Node 20.x)

| Check | Mark | Evidence |
|---|---|---|
| Section renamed in three locales, search keywords, sidebar and page tests, e2e and the runtime browser script | confirmed by tests | `AppSidebar`, `FactoryAccountingPage`, `admin-access` tests: 48 passed after updating the denied text |
| Production build `next build --webpack` (`NEXT_DIST_DIR=.next-ai-core`, API base `http://127.0.0.1:8003`) | confirmed | first attempt compiled in 456 min under swap and the page-data worker died (`3221225794`); the retry after the reboot compiled in 20.7 s, TypeScript 45 s, `/commercial-approval` and `/factory-accounting` emitted |
| `next start` of that build on 4194 | seen live | login page 200 at once |

Runtime caveat stands: Node 20 exists only as a Docker image on this host, the admin dependencies are
installed for Windows; Python 3.11 is not installed locally. Repeat the gates with the declared
versions before production acceptance.

## 4. Real HTTP/JWT chain on the disposable stack (seen live in the browser pane)

Stack: `acceptance/commercial-runtime.compose.yml` + `commercial-approval.compose.yml`, project
`dimax-approval-20261021`, clean source snapshot in `.tmp/approval-20261022/backend` (no `.env`),
tmpfs database, gateway on 8003, built admin on 4194, no external egress, no SMTP.

1. `approval.py prepare`: fresh synthetic company, OWNER / OPERATIONS / FINANCE / VIEWER / INSTALLER
   / FOREIGN users, nonzero installer rate and earning baseline; contract, terms v1, price v1
   (400.50 and 60.00 ILS excl. VAT), OWNER-approved factory contact created through the real API.
2. OWNER logged in on the built admin (company id + email + generated password), opened "Договоры и
   оплаты" → "Согласование заводом": empty history, "Проверить последние версии" showed
   "Условия v1 / Коммерческий прайс v1", the TEST ONLY notice and the OWNER-approved representative.
3. "Отправить заводу" dialog: full pair shown, send button disabled until the consent box was
   ticked (checked by script: `disabled` true → false), then sent. History: "Ожидает завода",
   "Отправка письма: В очереди", expiry 26 Oct. The admin API response carried status, versions,
   snapshot hash and outbox id only: no link, no code.
4. `approval.py link` rendered the encrypted outbox message locally and captured the 43-character
   token. The public page opened with the token in the fragment; after load the address had no
   fragment and the page had no cookies. RU locale, TEST notice, both versions, representative name.
5. "Получить код на почту" → 200 `{"status":"QUEUED", …}` with no code in the response;
   `approval.py code` captured the six-digit code from the locally rendered mail.
6. A wrong code with consent → `POST /confirm` 403 (the page kept the form; the inline message was
   not captured in the screenshot). The captured code → 200, "Решение завода сохранено ·
   Synthetic Representative · 23 окт. 2026, 07:52".
7. RU at 390 px: no horizontal scroll (`scrollWidth 390 = innerWidth`). HE at 768 px: `main dir=rtl`,
   heading "אישור הסכם מסחרי", no horizontal scroll, decision block present.
8. Admin history after refresh: "Подтверждено", "Посмотреть точные версии" opened the frozen pair.
   "Проверить последние версии" for the decided pair shows "Решение завода сохранено" and no send
   button: the UI itself blocks a repeat invitation.
9. `approval.py verify`: exactly one CONFIRMED row bound to the prepared terms and price ids,
   `mailbox_verified_at` set, `usable_for_billing` false, `is_demo` true; OPERATIONS and INSTALLER
   get 403, FOREIGN tenant 404, anonymous 401 on the history endpoint; financial table digests equal
   the baseline (no installer rate or earning changed); one `COMMERCIAL_APPROVAL CONFIRM` audit row.

Replay and tamper checks through the gateway (`scratchpad/approval-replay.py`, seven PASS lines):
exact replay with the same code returns the same recorded decision; replay with another signer
name 409; a different version than displayed 409; a new mailbox code for a decided invitation 409;
a tampered link 404; OWNER revoke of a recorded decision 409; history still one unchanged row.

Persistence and downgrade: the API container was force-recreated; after `/ready` the same `verify`
passed again. `alembic downgrade 0085_commercial_terms` raised
`RuntimeError: Cannot discard commercial confirmation history`; `alembic current` stayed at
`0086_commercial_approvals (head)`.

Not repeated live: superseding by a new version, factory contact change and revocation of a pending
invitation (confirmed by the 16 approval tests; the live stack had one decided pair only). The
Playwright script `commercial-approval-browser.mjs` was not run; the same steps were driven by hand in
the browser pane with the owner watching, so no PNG files were written.

## 5. Environment and cleanup

Host 4 GB RAM. The approval chain ran with the built admin only; backend regression ran alone. The
disposable stack was removed with `compose down` (two networks removed, zero containers left); the
tmpfs database is gone. Proof directory `.tmp/approval-20261022/proof` holds generated test
credentials, link and code for the destroyed stack only (ignored by git). The working API, database,
MinIO and the five workers were not stopped by this acceptance; Docker Desktop was restarted once
with the owner's approval and once started after a host reboot, which restarted every container.

## 6. Still open before "release-accepted"

- Node 20 / Python 3.11 gate repeat (declared runtimes).
- Real domain, HTTPS and external email delivery to the factory (separate deployment gate).
- Isolated Mailpit case (`DIMAX_FACTORY_MAILPIT=1`).
- The next stage, activation of terms and settlements, is a separate proposal; nothing here
  activates a contract, creates an invoice or changes installer earnings.
