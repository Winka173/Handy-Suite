# QA progress and continuation

Current scope: implementation ongoing; no release/device/browser certification.

Executed:

- `tooling/flutter-bootstrap.ps1`: resolved dependencies and Windows plugin junctions.
- `dart analyze apps/handy_spend packages/handy_spend_engine`: initially clean; rerun
  after the latest security/drop/parser changes. Log: docs/qa/evidence/spend-analyze.log.
- Engine `flutter test --no-pub`: **19 passed** after strict timestamp/grouping and
  historical recurrence tests. Log: spend-engine-tests.log.
- App initial full test run: **9 passed**, including actual SQLite rollback trigger,
  stale revision, corrupt/future-schema refusal and 1k/10k/100k records; UI create/
  expense/cancel/report and 320/1000px text-scale 1.5. New auth/drop/audit tests running.
- Native Windows test VM sample: 100k rows write ~3630ms, reopen/read ~1178ms. These
  are synthetic storage figures, not release UI frame/memory/browser measurements.

Next required checks: latest app/engine test suites; full workspace regression;
Android/Windows/Web builds; emulator capture and financial flows; OS permission
deny/grant and lock-cancel; independent PDF/XLSX decoding; malformed/large/cancel/
restore UI; browser IndexedDB/PWA and actual Explorer drop where permitted.
No successful platform build is recorded yet. iOS needs macOS/Xcode and signing.

Feature gaps still to review before declaring P0 complete: resizable desktop table/
shortcuts; full bank mapping UI compatibility; sandbox budget/goal presentation and
conversion regressions; delayed/reboot/tap reminders; accessibility/read-only/low-
storage/provider coverage. No background execution is claimed when a session stops.
Raw evidence is under docs/qa/evidence/spend-*; failures are retained, not rewritten
as pass. FEATURE_MATRIX.md separates code, tests and runtime verification.
