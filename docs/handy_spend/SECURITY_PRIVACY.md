# Security and privacy

All ledger/import/planning work is local. No bank login, SMS/contacts permission,
bank connection, external rates, AI, analytics with financial data or account system.
Only the existing monetization adapters can use network for configured ads/store.
Ads are hidden during capture, import, exports/security confirmation and sandbox.
Unconfigured stores remain unavailable; never use a local Pro switch.

Money is exact and imports are untrusted: strict dates/grouping, bounded ZIP/XML,
no external workbook targets/formulas/macros, CSV formula escaping, user-selected
files only. Atomic SQLite transactions and revision guards protect concurrent/stale
writes. The app does not reset damaged/newer databases. Keep backups outside its
sandbox and verify actual downloaded files.

The local database, audit and exported files are **not encrypted by this app**.
Amount hiding is a visual mask. Device authentication uses
[Flutter local_auth](https://pub.dev/packages/local_auth) and its OS credential
fallback; it is access control, not encryption. Device lock defaults off and enabling/
disabling requires successful OS authentication. Cold start locks when enabled;
background cover spans the entire navigator, timeout relocks on resume. Web has no
verified adapter; a restored unsupported lock flag is disabled with restore warning.
Native app-switcher capture timing/hardware and OS prompts still need device tests.

Android setup follows the [official adapter](https://pub.dev/packages/local_auth_android):
FragmentActivity, biometric permission and AppCompat theme. iOS has Face ID usage
description; Windows uses the endorsed Windows Hello implementation. No custom PIN
hashing/secret database or invented authentication success path exists in production.
Tests use explicit injected OS-response doubles, clearly separated from device proof.
