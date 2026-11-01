# Import/export contracts

Reviewable sample bank exports are committed under
`packages/handy_spend_engine/test/fixtures/`: Vietnamese BOM/semicolon/multiline CSV
and an English XLSX generated independently with openpyxl (Excel date cells,
debit/credit and running balances). Engine tests require both to reconcile exactly.

Statements: CSV/TXT and first-sheet XLSX, selected by picker or dropped explicitly.
12MB input, <=100000 data rows and <=256 columns. CSV supports comma/semicolon/tab,
quoted multiline fields, UTF-8, UTF-16 BOM and explicit Latin-1. Mapping requires
account, date/description and signed amount or debit/credit columns, date convention,
decimal/grouping separators, optional sign reversal and IANA timezone. No bank APIs.
Optional closing/running balance column and newest-first ordering support explicit
calendar-day reconciliation. The result shows statement balance, selected-ledger
balance and difference; it never inserts a silent correction. Positive liability
credits require explicit row classification before commit. Review is paginated
100 rows at a time; every parsed row remains accessible.
Bad grouping, invalid calendar dates, ambiguous times without offset, zero amounts
and malformed debit/credit pairs are refused. Full ISO timestamps retain their time.

XLSX: OpenXML ZIP/relationship/shared-string/inline-string cells. ZIP paths/CRC/size
are checked before expansion. Formula cells, external relationships, macro binaries,
XML entities and 1904 date workbooks are refused; export values/CSV instead. Excel's
fictional serial date 60 is refused. No formula evaluation or document scripts.

Preview displays new, potential duplicate/reversal and invalid rows. Duplicate keys
use account/date/amount/normalized payee, plus a file fingerprint in history.
Potential matches also allow a one-calendar-day date difference, with exact minor
units (zero amount tolerance), same account and normalized payee. Absolute amounts
flag possible reversals. Nearby matches remain unselected and require manual review;
legitimate daily repeated purchases can be false positives. This
is conservative review, not automatic deletion or merchant-specific certainty.
Unselected duplicates are retained on disk in the original source file. Partial
import requires explicit opt-in; selected writes/log are one transaction. A stale
preview is refused. Reusable mapping profiles are gated by verified Pro ownership.
Batch Undo refuses changed rows and dependent refunds. Originals are never overwritten.

CSV/XLSX exports include readable columns and a versioned portable record per row
for exact IDs/timestamps/BigInt/provenance. Visible columns must match that record
when reimported; edited files use ordinary mapping. Formula-like visible text is
escaped. Account IDs must already exist. Refund dependencies may be included to keep
filtered exports valid. JSON exports use the same references; PDF is a real report,
not a reimport format. PDF refuses over 5000 rows; exports must be <=30MB. The PDF
layout is configured for 200 pages, but the library's page-count guard is debug-only;
this is not a certified release page-count or peak-memory limit. Very long cells
and large production reports still need broader QA; layout errors do not save output.

Full ZIP backup: manifest + SHA256 data.json, schema version and explicit empty
attachment list. Restore previews counts, requires two confirmations and guards
revision before replacing. Engine JSON/ZIP and CSV/XLSX roundtrips are tested.
Web download dispatch does not prove the user saved the file. Exports are private
and unencrypted; receipt files and encrypted backups are not implemented P0 features.
