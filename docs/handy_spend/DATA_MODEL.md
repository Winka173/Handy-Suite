# Data model and migrations

Schema 2, isolated `handy-spend.sqlite` / IndexedDB `handy-spend`. Native accounts
and entries are separate rows, indexed by date/account/type/status; state contains
categories, budgets, bills, goals, scenarios, profiles (statement templates), receipt
descriptions, people, splits, import logs and audit events. Foreign keys and revision
compare-and-swap prevent partial transfers/lost writes. Unknown future versions are
refused; corrupt files are never automatically reset.

Amounts are BigInt minor units, serialized as decimal strings. Currency scale is
explicit (VND/JPY 0, common currencies 2, KWD/BHD 3). Native and browser arithmetic
therefore does not depend on JavaScript's integer precision. No automatic FX rates.

Transactions have UUIDs, immutable entered timestamp in UI edits, distinct effective
timestamp, kind, signed amount, account/category/payee/tags/note/status, transfer
destination/rate/target/fee, refund reference and import/occurrence provenance.
Posted expenses reduce balances; refunds must reference a posted expense and total
refunds cannot exceed it. A refund must be on the expense's account, except a split
settlement (below), which may arrive in any account of the split's currency.
Corrections affect balances, not income. Credit/loan debt balances are negative.
Repayments are linked transfers.

All mutations append before/after change records with revision, action, UTC time
and prior-state hash. Undo preserves the audit trail; restore merges imported audit
history instead of silently discarding it. Audit records are local and unencrypted.
Goals reserve existing cash; they do not insert a second ledger transaction.
Scenarios hold deeply immutable financial snapshots and separate staged entries.
Device lock settings use destination OS credentials, not portable secret keys.

## Schema 2 (2026-11-02)

- **Receipts** (`receipts`): `{id, entry, name, mime, size, sha, added}`. The bytes are
  not in the ledger JSON: natively a `receipts(id TEXT PRIMARY KEY, bytes BLOB)` table
  in the same SQLite file, on the web an IndexedDB object store `receipts` (blob per ID).
  Type is decided from the file signature (JPEG, PNG, WebP, PDF only). Limits: 10 MB per
  file, 10 per transaction, 50 MB and 1000 files in all. The file is written first, then
  the change that lists it; a failed change leaves an unlisted file, which is swept when
  the ledger next opens (never during a session, so Undo always finds its files).
  Deleting a transaction drops its receipt descriptions in the same change.
- **People** (`people`): `{id, name, archived}`; `me` is reserved for the ledger owner.
- **Splits** (`splits`): `{id, payer, currency, date, name, method, total, parts[],
entry?, category?}`; a part is `{who, amount, units}`. Methods `equal`, `shares`,
  `exact`; parts always sum to `total` exactly, and equal/shares parts must equal the
  deterministic allocation of their units. When you paid (`payer: me`) the split names
  your posted-or-pending expense whose amount equals the total (one split per entry);
  when someone else paid, there is no entry and you must have a share.
- **Settlement links on entries**: optional `settles` (split ID) and `person`, written
  only when set, so every older entry keeps its exact JSON and import batch hashes. A
  person paying you back is a posted `refund` of the split's expense; you paying them
  is a posted `expense`. Settled totals per person never exceed their share.
- **Statement templates** (`profiles`): `{id, name, signature, headers, mapping,
delimiter, encoding}`; `signature` is SHA-256 of the headers' count and their trimmed,
  lower-cased, space-folded text. One template per signature; columns must exist.
- **Dismissed recurring suggestions**: `settings.dismissedRecurring`, a list of keys
  (`account|counterparty|kind|frequency`).

Migration 1 → 2: SQLite `user_version` 1 gains the empty `receipts` table in one
transaction (rows untouched); IndexedDB version 2 adds the `receipts` store and keeps
the others. Schema 1 JSON (from storage, a backup or a scenario baseline) loads with
empty receipts/people/splits; a v1 column profile gains its header signature and the
CSV defaults it was made with (`,`, UTF-8). The next write stores schema 2. A schema 3
or newer ledger, ZIP or SQLite file is refused unchanged. Roundtrip tests: engine
`test/schema2_test.dart`, native `test/store_test.dart` (v1 file → v2, receipts,
sweep), app `test/features_test.dart` (ZIP backup/restore with files).

ZIP backup manifest version 2 lists every receipt (`receipts/<id>`, size, SHA-256);
restore refuses a missing, altered, extra or unlisted file. Version 1 ZIPs (empty
attachment list) still restore. JSON backups leave receipts out. Import Undo is refused
once a receipt or split was added to an imported row.
