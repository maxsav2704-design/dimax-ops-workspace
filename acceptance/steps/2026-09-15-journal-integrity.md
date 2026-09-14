# Journal: signed archive integrity and isolated PDF delivery

## Scope

Continue the journal acceptance block, following the September 14 form and gateway
checkpoints. No production approval or readiness-percentage increase is implied.
Only backend code/tests change. No phone storage, acceptance assignments,
completions, earnings or customer signatures are modified. The existing
`QA JOURNAL FORM 20260914` remains unsigned in Acceptance A.
Local commits only under the existing public-repository publication restriction.

## Findings and fixes

- High: the central PDF export still regenerated signed documents from live
  project/type metadata. Explicit export and resend bypassed the previous
  download/share preservation guard. The central use case now returns the
  archived file without re-reading mutable project metadata.
- Signing finalizes a separate `_signed.pdf` object inside the existing signing
  transaction. The prior unsigned object is not overwritten. Journal row locking
  serializes export with signing; locked reads refresh cached ORM state. Repeated
  finalization reuses the same signed archive. Legacy signed paths are preserved;
  a missing archive record is rejected instead of reconstructed.
- High: any nonempty signature dictionary was previously accepted, including
  values the renderer could not draw. New signatures require the current canvas
  format, finite bounded coordinates, a valid viewport and a nondegenerate visible
  line. Invalid/blank/oversized payloads return 422 without archiving. Pointer
  capture outside the canvas remains supported and rendering clips to its frame.
- PDF notes were omitted. They now render with escaped literal characters and
  preserved line breaks. UTC timestamps convert to Asia/Jerusalem with DST.
  Font-family registration keeps bold multilingual text consistent. The footer
  states that delivery is tracked separately, rather than claiming it happened.
- Existing delivery tests depended on host WhatsApp settings. Test-only channel
  configuration is now explicit; their worker is scoped to the fixture company
  and fixture database. The old core E2E placeholder signature is replaced with
  actual canvas-format points. Runtime WhatsApp settings remain unchanged.
- No migration is required: no database model, column or stored enum changes.
  Public API fields remain compatible; malformed signature input is now rejected.

## Verification

- Initial architecture/PDF checks: 25 PASS, 28.46 seconds.
- Initial API/delivery run: 11 PASS, 3 FAIL, 110.69 seconds. All three failures
  were delivery tests assuming WhatsApp enabled on the disabled acceptance stack;
  this is not recorded as a successful gate.
- First Mailpit attempt stopped at an incorrect test guard (`settings.APP_ENV`
  instead of environment lookup). No journal or email was created in that attempt.
- Corrected real MinIO/SMTP run: pytest reports 1 PASS, 66.74 seconds. Its Compose
  wrapper later returned exit 1 with no diagnostic; it is not the final gate.
- Final combined journal run: 60 PASS, 184.55 seconds; process exit 0 and explicit
  container inspection `exited / exit=0 / oom=false`. This includes actual Mailpit
  receipt, API signing/concurrent-sign rejection, permissions, snapshots, archive
  reuse, validation and timezone tests. This is focused coverage, not a full suite.
- Supplemental core E2E/final fixture-guard run: 2 PASS, 86.56 seconds, exit 0;
  container inspection confirms `exited / exit=0 / oom=false`. The core scenario
  uses real JWT login and covers projects, additional work, journal and sync.
- Final geometry/freshness rerun after rejecting subpixel viewports: 27 PASS,
  25.63 seconds, exit 0. There are 62 unique cases across these focused runs;
  repeated tests are not counted twice. `git diff --check`: PASS.

## PDF and delivery evidence

The opt-in test creates a separate ephemeral company/project in
`dimax_acceptance_tests`, five installed QA positions, a marked test document and
`QA TEST SIGNER`. It calls real application APIs via TestClient, real MinIO,
the actual SMTP sender and a worker restricted to that test company.

Mailpit receives one message addressed to the fixture developer with its admin
in Cc. There is exactly one application/pdf attachment; its SHA-256 matches the
signed archive. A second ordinary worker pass processes zero messages. Changing
the test project name and re-exporting does not change signed bytes, and the
old unsigned object retains its original bytes. This is not an exactly-once SMTP
guarantee under ambiguous network failure.

Both generated PDFs were rendered with Poppler at 100 DPI and every page viewed:
one page each; five rows, short RU/HE/EN notes, escaped punctuation, local work
time, test signer and signature frame are readable without overlap. This covers
these samples, not all long documents or a fully translated PDF template.

The fixture removes only messages matching its unique subject and objects under
its exact company/journal prefix; its DB fixture removes only its own company.
No global mailbox, bucket or queue cleanup is used.

## Deployment and cleanup

Backend source/tests/documentation are locally committed as `56ca995`.
Only the acceptance API was restarted; initial gateway readiness returned 502
during startup, and the bounded readiness wait initially timed out at the HTTP
client. It then returned HTTP 200 on attempt 6. A subsequent direct check returns
`status=ok / database=ready`; Docker reports `running / healthy / oom=false`.
The admin journal was fully reloaded after startup. It displays the same DRAFT
title, version 2, five completed doors, zero addons and unchanged notes. No write
or signature was performed in Acceptance A. Startup and browser hydration were
slow; these observations do not establish a latency SLO.
The two retained one-off containers were inspected as stopped with exit 0 and
removed by exact name. Other test containers used automatic removal. No
`dimax-journal-*` test containers remain. Mailpit has zero messages after cleanup.
The four owned QA PDF/PNG artifacts (281,138 bytes) and their exact ignored
directory were removed after the final render/inspection; no build cache or
dependency installation was introduced. The admin production build and mobile
bundle are unchanged; their full release gates were not rerun in this step.

## Remaining acceptance

- Full PDF template translation and long RU/HE/EN pagination/RTL acceptance.
- The legacy manual-send public link still targets the JSON API rather than the
  human signing page. Correct and test this separate invitation path next.
- Metadata can still change before signing; this step freezes generated signed
  bytes, not a new immutable project/type snapshot schema. Legacy archives are
  preserved, not retroactively certified. Unsigned exports are not versioned.
- Real browser/phone signing, offline journal workflow and fresh native evidence.
- External test inbox, production HTTPS/SMTP configuration, bounce handling,
  signed-file backup/restore and customer/legal acceptance remain separate gates.

Mailpit status proves local SMTP acceptance, not delivery to a real developer.
No release GO, remote GitHub backup or 100% product completion is claimed.

## Reference

[Mailpit API](https://mailpit.axllent.org/docs/api-v1/): local message inspection,
raw MIME retrieval and deletion by explicit IDs; no message release endpoint is used.
