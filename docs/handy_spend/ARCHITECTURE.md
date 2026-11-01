# Handy Spend architecture and repository audit

2026-11-01, before custom implementation. Existing workspace: seven independent
Flutter apps, 18 shared packages, Flutter 3.44.9/Dart 3.12.2. No Spend identity exists.
Add an eighth application, `handy_spend`, and pure `handy_spend_engine`.

Reuse LocalApp/handy_ui (adaptive theme, EN/VI, settings), handy_files (bounded user
file dialogs), handy_core (ZIP security/cancellation), handy_monetization/store
(native Ads and verified lifetime ownership), handy_notifications (permission and
timezone adapters). No handy_export package exists; PDF uses the existing pdf
dependency. Keep Save's bookmark storage independent: reuse its SQLite worker and
IndexedDB design, not bookmark schemas or data. Tools loan/compound calculators use
Decimal/Rational; their textual two-decimal outputs are unsuitable for a variable
currency-scale ledger. Spend needs integer minor units and BigInt intermediates.

Native persistence: versioned SQLite, WAL/FULL, foreign keys, revision compare-and-
swap, atomic snapshot changes, audit events. Web: IndexedDB transaction with the
same revision guard. Ledger and plans are separate. Imports and scenarios are
validated before committing. User cancellation does not mutate the repository.

Initial version is schema 1; refuse unknown future versions. Never adopt or clear
another app's data. Backup is versioned/checksummed and restored only after review.
No new state-management or routing framework. Existing seven app IDs stay unchanged.

Implementation order: exact ledger → planning → portable/import → UI → QA/builds.
Platform/runtime evidence will be recorded separately from code status.
