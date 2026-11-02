# Implementation decisions

- Add Spend without changing seven existing app identities/data. Provisional Spend
  namespace/bundle: com.example.handysuite.spend; Android debug adds .flutterpilot.
  App key `spend`, accent #7C3AED distinct from the current seven apps.
- Reuse LocalApp, shared fonts/localization/theme, file dialogs, ZIP guards and
  real Ads/Pro adapters. No new routing/state framework. Save/Keep domains remain
  independent. No large native financial SDK or bank connector.
- Reuse exact-arithmetic approach, not Tools' loan UI or fixed-two-decimal output.
  BigInt minor units are strings on disk, preserving Web precision. Interest/advanced
  issuer rules are P1 until terms and formulas have independent validation.
- SQLite 3.5.2 is already compatible with the pinned SDK/hooks; no dependency override
  or Flutter upgrade. Native decode/validation and SQL run in isolates. Browser uses
  IndexedDB; browser runtime/performance is an open verification item.
- local_auth 3.0.2 provides OS credentials rather than home-grown PIN crypto.
- desktop_drop 0.8.0 matches this SDK and the documented onDragDone/XFile API.
  [Latest 0.9 API](https://pub.dev/packages/desktop_drop) requires a newer SDK, so
  it is deliberately not adopted. Drop data enters the same bounded review wizard.
- Only one editable free scenario; verified Pro enables multiple/duplicate/compare
  and >30-day advanced forecast UI. Basic data access/CSV import/export is free.
- 2026-11-02: receipts are kept as bytes beside the ledger (SQLite table natively,
  IndexedDB store on the web), never inside the ledger JSON, and ZIP backups carry them
  within an 85 MB budget. Backups are still not encrypted.
- 2026-11-02: shared costs are splits with people, not multi-line transactions: the
  ledger keeps single entries; a friend's payment back is a refund of the expense (any
  account in its currency), your payment to them an expense. Money owed to you is not
  in Safe to Spend until settled; what you owe is taken out at once.
- 2026-11-02: what-ifs are overlays on the plan's live forecast; their baseline copy is
  still stored immutably and used to check assumptions. No bank-specific statement
  templates are shipped (no real statements to verify against); saving one still needs
  verified Pro, as column profiles did.
- Advanced loan/goal reverse planning is not implemented.
