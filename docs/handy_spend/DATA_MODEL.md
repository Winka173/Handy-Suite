# Data model and migrations

Schema 1, isolated `handy-spend.sqlite` / IndexedDB `handy-spend`. Native accounts
and entries are separate rows, indexed by date/account/type/status; state contains
categories, budgets, bills, goals, scenarios, profiles, import logs and audit events.
Foreign keys and revision compare-and-swap prevent partial transfers/lost writes.
Unknown future versions are refused; corrupt files are never automatically reset.

Amounts are BigInt minor units, serialized as decimal strings. Currency scale is
explicit (VND/JPY 0, common currencies 2, KWD/BHD 3). Native and browser arithmetic
therefore does not depend on JavaScript's integer precision. No automatic FX rates.

Transactions have UUIDs, immutable entered timestamp in UI edits, distinct effective
timestamp, kind, signed amount, account/category/payee/tags/note/status, transfer
destination/rate/target/fee, refund reference and import/occurrence provenance.
Posted expenses reduce balances; refunds must reference a posted same-account
expense and total refunds cannot exceed it. Corrections affect balances, not income.
Credit/loan debt balances are negative. Repayments are linked transfers.

All mutations append before/after change records with revision, action, UTC time
and prior-state hash. Undo preserves the audit trail; restore merges imported audit
history instead of silently discarding it. Audit records are local and unencrypted.
Goals reserve existing cash; they do not insert a second ledger transaction.
Scenarios hold deeply immutable financial snapshots and separate staged entries.
Device lock settings use destination OS credentials, not portable secret keys.

Receipt attachments and advanced issuer interest terms belong to P1, not this schema's
implemented attachment UI. ZIP manifest explicitly has an empty attachments list.
