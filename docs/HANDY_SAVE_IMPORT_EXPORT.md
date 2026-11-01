# Handy Save portability

Supported imports/exports: JSON, CSV, Netscape browser HTML, unambiguous Markdown
links, TXT URL lists and ZIP. No source application login or API is needed.

The default mapping accepts URL/title/description/tags/note/collection fields.
Browser HTML folders become collections. Unknown proprietary export layouts are
not claimed universally compatible. Invalid rows and duplicate counts appear
before commit; preview shows representative records. Cancel changes nothing.

JSON and ZIP preserve complete bookmark fields, original/normalized/canonical URL,
collection hierarchy, standalone tags, notes, smart rules, saved searches and
reminder times. Other Handy Save exports include an explicit versioned full-state
payload alongside interoperable visible rows/links so a self roundtrip is exact.
Other applications can ignore that payload. Imported reminders do not silently
grant notification permissions. App settings, secrets and ad identifiers are excluded.

ZIP has a schema-versioned manifest, data and SHA256 checksums. Shared ZIP guards
reject unsafe paths, duplicates, CRC/digest failures and excessive decompression.
Thumbnail cache is disposable and intentionally excluded; user-selected thumbnail
images are currently treated as cached images too. There is no media downloading.

Merge skips known equivalents without silently overwriting notes/collections;
ID conflicts are remapped. Replace requires an additional confirmation and refuses
a stale preview if the library changed. Database commits are transactional.
Full library, selected bookmarks and current filtered/collection results can export.

Each portable operation has a 30MB byte budget inherited from the shared ZIP guard.
There is no bookmark-count paywall or fixed database count cap. At 50k sample rows,
JSON approaches this bound; base64 metadata in text formats can reach it sooner.
Export collections/subsets or reduce oversized descriptions when needed. Never
promise unlimited-size backups. All exported formats can contain private URLs.
