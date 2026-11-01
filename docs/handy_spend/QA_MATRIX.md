# QA evidence and remaining checks

Updated 2026-11-01. Tests cover specified cases; no zero-bug or release claim.
Full workspace baseline: **1698 passed, 28 skipped, 27/27 packages**, source
`5844653bf4b5`. Concurrent changes subsequently affected other apps and shared UI;
that result does not certify the later live workspace. A frozen candidate under
`.tooling/spend-qa` is checked separately for Spend, its engine and shared UI, three
Spend builds, Android flows and five scoped worker/bridge checks. The published
`spend-checkpoint-audit.json` identifies the candidate and its artifact directory.
Use `python tooling/publish-spend-snapshot.py --verify-only` to recheck that candidate.
Published candidate: `8655b2af2608`, **45 tests passed** (16 app, 26 engine, 3 shared
UI), focused analyze clean; Android/Windows/Web builds passed; Android ledger/import/
Undo and notification deny/grant passed with unchanged frozen source. Unsigned AAB/
MSIX, five scoped VM checks, ten independently decoded exports and eleven screenshots
passed. Evidence: `docs/qa/evidence/spend-candidate-8655b2af2608/`; installable/debug
artifacts: `artifacts/flutter/handy_spend/candidate-8655b2af2608/`.
Spend app **16**, Spend engine **26**. Native integrations are counted separately.
Raw evidence: `docs/qa/evidence/`. `python tooling/verify-spend-checkpoint.py` checks
live-workspace evidence and writes a separate `spend-live-workspace-audit.json`;
it is expected to reject stale source records during concurrent edits.

Executed checks:

- `dart run melos test`: full workspace regression. Exact totals/package counts in
  `spend-workspace-tests-summary.json`, derived from the completed raw log.
- `dart run melos analyze`: full workspace static analysis; `spend-analyze.log`.
- Engine: exact currency scale/FX, credit repayment/refunds, duplicate and malformed
  import, JSON/ZIP/CSV/XLSX roundtrips, month-end/leap/DST/UTC, account selection,
  forecast minima, immutable scenarios, income assumptions and single due-date shifts.
  Added last-record/last-payment tests excluding pending/future entries and checking
  both sides of transfers across a reporting-zone day boundary. Custom horizon UI
  refuses zero, accepts 14 days and leaves the real ledger unchanged.
  Preset UI cancellation preserves the original; saving creates a distinct ID and
  retains the original bytes without copied import/occurrence provenance. Import
  tolerance tests cover adjacent days, sign reversals, normalization, exact amount
  mismatch and explicit selected-row commit without deleting the original.
- App: actual SQLite WAL/reopen/CAS, SQL-trigger rollback, corrupt/future database
  preservation, 1k/10k/100k records. A subprocess is killed after uncommitted writes
  spill into WAL; reopening preserves the original ledger. This does not certify
  every power-loss or disk-full case. See `spend-crash-recovery.log`.
- Widgets: account/expense/cancel/report, 320/1000px with text scale 1.5, hypothetical
  income cannot change the ledger, privacy lock cancellation/background/resume,
  bounded drop stream, EN/VI export and cancelled export without mutation.
- `python tooling/verify-spend-exports.py`: ten UI-export files independently read
  with csv/openpyxl/PyMuPDF/ZIP. Amount, timezone day, IDs and provenance checked.
  Test-only file sink does not prove operating-system file-provider interaction.
- Spend Android debug APK, Windows release and Web builds succeeded with unchanged
  source SHA. Unsigned release AAB and MakeAppx-validated MSIX also succeeded;
  MSIX is not installed or store approved. See `builds-*.json`, `spend-aab-result.json`
  and `spend-msix-result.json`.
- `tooling/flutter-screenshots.ps1 -App spend -Device emulator-5556`: real Android
  SQLite ledger, credit repayment/refund, backup decode/reopen, sandbox non-mutation,
  add transaction, CSV mapping/review/commit/reconciliation/Undo. The final balance
  returns to its pre-import value. Eleven screenshots including accounts/settings;
  result JSON records pass.
  CSV bytes use the existing explicit-file input, not the OS picker.
- `tooling/spend-notifications.ps1 -Device emulator-5556`: real denied/granted
  notification permission, 50-schedule cap, immediate delivery and cancel. Dedicated
  AVD has no enrolled credential: raw plugin binding and unavailable-device refusal
  checked, successful biometric/PIN authentication not verified.
- TypeScript typecheck and 12 Node VM RE2/PWA/share checks passed. These are not
  installed-PWA, IndexedDB or browser service-worker lifecycle tests.

Synthetic Windows samples: 100k rows write ~3.6–6.9 seconds, reopen/read ~1.2–2.1
seconds across runs under different host load. These are storage samples, not
release UI frame/memory/browser performance measurements.
Other seven apps' native/build records remain historical; workspace unit/widget
regression is current. Earlier PDF-font/UTC failure logs are retained. No background
work is claimed after a session ends.

The notification runner now uses the SDK's `--no-start-paused` option and a
240-second timeout. The prior driver-service startup stall is retained in the
candidate logs. This changes test transport, not application behavior or results.

Visual review also exposed hidden populated-field labels under the shared minimal
theme. Spend now opts into always-visible floating labels; other apps retain their
existing default. A corrupted Vietnamese required-fields message was corrected.
Media title tests now ignore decorative WidgetSpan placeholders while still matching
the exact title and checking saved-guide ordering. Initial failure logs are retained.

Still required before launch certification:

- Browser IndexedDB roundtrip/quota/eviction/multi-tab, actual drop, offline/update.
- Explorer drop, Windows Hello, signed MSIX installation and file-provider failures.
- iOS compilation/runtime on macOS/Xcode; physical Android/iOS devices.
- Successful device authentication, app-switcher capture timing, TalkBack/VoiceOver,
  reduced-motion and all critical editors with assistive technology.
- Delayed/background/reboot/tap reminders, storage pressure, process loss during
  complete import/restore UI and broader bank-file compatibility.
- Real AdMob/store configuration, consent, purchase/restore/pending/cancel/refund,
  signing and store review. Configuration gaps: `docs/STORE_SETUP.md`.
