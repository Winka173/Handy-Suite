# Decisions

Use pinned existing sqlite3/path_provider/web/timezone/archive/crypto/pdf/notifications
versions and their existing MIT/BSD/Apache license notices; no dependency upgrade.
Basic Lite and reports are free. Verified Pro removes supported ads and saves reusable
Lite variants. No fabricated Web entitlement, report benefit or cross-store transfer.
Windows/Web have no AdMob. Missing publisher configuration is disclosed by real adapters.

Daily strict streak ignores unscheduled/skipped dates; open today is not a failure.
Weekly streak counts qualified closed/full weeks, plus a current week already qualified.
A switch between weekly and strict tracking starts a new streak unit segment; old logs
remain visible. Schedule edits are future-effective, weekly edits at a week boundary.
Routine Lite shrinks only declared minima then omits low-priority optional steps;
required steps stay in original order, original template never changes.

Dependency audit: existing pins were reused, not upgraded. Installed LICENSE files were
read: sqlite3 3.5.2 MIT; flutter_local_notifications 22.3.3 BSD; timezone 0.11.2 BSD;
archive/crypto BSD; pdf Apache-2.0; web/path_provider BSD. Primary package references:
[sqlite3](https://pub.dev/packages/sqlite3/versions/3.5.2),
[notifications](https://pub.dev/packages/flutter_local_notifications/versions/22.3.3),
[timezone](https://pub.dev/packages/timezone/versions/0.11.2).
Optional biometric lock deferred: existing Spend lock is app-specific. No unreliable
replacement. No P1 widgets/challenges or unrelated app features added. Pauses (P1 vacations) were
added on 2026-11-02 as schema 2: a paused day not done is neutral, a paused day done
counts, weekly quotas are prorated and rounded up (rule in DATA_SCHEMA). The routine
runner still pauses in the background; its notice says so instead of running a timer
nobody can see (no chronometer, no end-of-step alert), the smallest honest change.
