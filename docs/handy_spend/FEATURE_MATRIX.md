# Handy Spend feature matrix

Implementation in progress. Results below cover specific executed tests, not every flow.
No release, physical-device, iOS or browser-runtime verification is claimed.

| Area | Status | Evidence / remaining work |
| --- | --- | --- |
| Exact money, accounts, ledger, transfers, refunds | UNIT_TESTED | 17 initial engine tests passed; additional strict timestamp/grouping cases being added |
| Native SQLite, revision guard, atomic writes | INTEGRATION_TESTED | Actual SQLite rollback trigger, reopen, stale revision, corrupt/future schema preservation, 1k/10k/100k records |
| Web IndexedDB | IMPLEMENTED | Per-record atomic transaction/revision guard; browser runtime and quota QA pending |
| Transaction/account/category/budget UI and reports | UNIT_TESTED | Create account/expense/cancel/report and 320/1000px large-text tests passed; more flows remain |
| Safe to Spend / forecast / sandbox | UNIT_TESTED | Exact breakdown, minima/shortfall, month-end/leap/DST, immutable baseline; scenario UI/device coverage pending |
| Statement CSV/XLSX mapping / review / undo | UNIT_TESTED | Local parser, duplicate/reversal statuses, explicit partial commit, unchanged-batch Undo, malformed files/formulas refusal |
| Recurring radar / goals / reminders | IMPLEMENTED | Anchor recurrence tested; no implicit posting; native notification adapter/permissions not yet exercised for Spend |
| JSON/ZIP/CSV/XLSX portability | UNIT_TESTED | Exact engine roundtrips; filtered UI export and picker flows still need integration |
| PDF export | IMPLEMENTED | Embedded shared Unicode font, real paginated document; independent decode/OS export pending |
| Ads / Pro Lifetime | IMPLEMENTED | Existing verified adapters; no ads in editors/import/sandbox; real publisher configuration absent |
| Device authentication / privacy cover | IMPLEMENTED | Real local_auth integration, OS PIN fallback, timeout and background cover; tests/device execution pending |
| Windows/Web statement drop | IMPLEMENTED | Bounded file stream into same import wizard; native/browser drop interaction pending |
| Android / Windows / Web builds | NOT_STARTED | Execute supported builds |
| iOS, store transactions, physical-device QA | BLOCKED | macOS/Xcode, publisher accounts/devices unavailable |

P1 planners/detective/OCR/advanced issuer interest are deferred. Continuation and
executed commands belong in QA_MATRIX.md; never upgrade status from code alone.
