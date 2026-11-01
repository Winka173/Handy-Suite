# Import/export contracts

Statements: CSV/TXT and first-sheet XLSX, selected by picker or dropped explicitly.
12MB input, <=100000 data rows and <=256 columns. CSV supports comma/semicolon/tab,
quoted multiline fields, UTF-8, UTF-16 BOM and explicit Latin-1. Mapping requires
account, date/description and signed amount or debit/credit columns, date convention,
decimal/grouping separators, optional sign reversal and IANA timezone. No bank APIs.
Bad grouping, invalid calendar dates, ambiguous times without offset, zero amounts
and malformed debit/credit pairs are refused. Full ISO timestamps retain their time.

XLSX: OpenXML ZIP/relationship/shared-string/inline-string cells. ZIP paths/CRC/size
are checked before expansion. Formula cells, external relationships, macro binaries,
XML entities and 1904 date workbooks are refused; export values/CSV instead. Excel's
fictional serial date 60 is refused. No formula evaluation or document scripts.

Preview displays new, potential duplicate/reversal and invalid rows. Duplicate keys
use account/date/amount/normalized payee, plus a file fingerprint in history. This
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
not a reimport format. PDF is bounded to 5000 rows/200 pages; exports <=30MB.

Full ZIP backup: manifest + SHA256 data.json, schema version and explicit empty
attachment list. Restore previews counts, requires two confirmations and guards
revision before replacing. Engine JSON/ZIP and CSV/XLSX roundtrips are tested.
Web download dispatch does not prove the user saved the file. Exports are private
and unencrypted; receipt files and encrypted backups are not implemented P0 features.
