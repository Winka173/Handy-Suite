# Handy Habit release preparation

R15/R16, 2026-11-10: source implemented and host tested. Android APK compilation is
recorded separately from OAuth, two-device runtime, physical-device and store verification.
No iOS cloud adapter, iCloud entitlement or Android ↔ iOS automatic sync is claimed.

## Google Drive sync (Android)

The Free, optional adapter uses `google_sign_in: 7.2.0` and `http: 1.6.0`, matching
Boards. It requests **only** `https://www.googleapis.com/auth/drive.appdata` for
Drive storage. Google handles account selection; authorization alone does not
expose the selected email to Habit or access ordinary Drive files.

The Settings › Data › Sync row exists only on Android with
`--dart-define=HANDY_DRIVE_SYNC=true`. No server client ID or Web OAuth client
is needed: initialization and scope authorization match Boards/Bookmark.
Do not bundle OAuth secrets, tokens, keystores or `google-services.json`.

The engine writes immutable, checksummed operation generations and per-device
version receipts. It never PATCHes a shared data file: two writers use different
device/generation names, so a mutable global lock and its check/write race are
unnecessary. Both generations survive concurrent uploads; the next sync joins
them. Download/validation precedes upload and local application is one durable
controller commit. Newer remote schema/protocol data refuses before upload.
See [DATA_SCHEMA](DATA_SCHEMA.md) for merge rules and limits.

## Owner setup — Google Cloud, click by click

These steps require the owner’s Google Cloud/Play access. Code cannot create or
verify the project, consent publication, domain ownership or signing identities.
No keystore or signing certificate was read during this run.

1. Open [Google Cloud Console](https://console.cloud.google.com/). Click the project
   selector at the top → **New project**. Name it **Handy Habit** → **Create**.
   Select that project. Use its own project, not Boards, Bookmark or the publishing project.
2. Open **APIs & Services → Library**. Search **Google Drive API**, open it → **Enable**.
3. Open **Google Auth Platform → Get started** (or **OAuth consent screen**).
   Set app name **Handy Habit**, support email and developer contact to the owner’s
   support address. Choose **External** audience. Complete the initial setup.
4. Open **Branding**. Keep the logo empty unless a verified logo is ready. Enter
   the real published Habit home, privacy and terms URLs. Suggested site paths,
   which the owner must verify/publish before using them:
   `https://winka.top/en/apps/handy-habit/`, `/privacy/`, `/terms/`.
   Add `winka.top` under authorized domains; verify ownership in Search Console
   if Google asks. Save. Do not claim a policy page exists before checking it.
5. Open **Data Access → Add or remove scopes**. Add only
   `https://www.googleapis.com/auth/drive.appdata` as the Drive scope → **Update → Save**.
   Do not choose `drive`, `drive.file` or broad metadata scopes.
6. During setup, open **Audience → Test users → Add users** and add the accounts
   used on the two Android test phones. Before public release, use **Audience →
   Publish app**, complete any Google requirements and verify production access.
7. Open **Clients → Create client → Android**. Create the three entries below.
   Paste the exact package and owner-supplied SHA-1; each certificate needs its
   own client. Click **Create** for each. Package IDs come from
   `apps/handy_habit/android/app/build.gradle.kts` (release id set 2026-11-10).

   | Name | Package | SHA-1 filled by owner |
   |---|---|---|
   | Handy Habit — Play app signing | `com.apps.winka.handyhabit` | `<PLAY_APP_SIGNING_SHA1>` (Play Console, see below) |
   | Handy Habit — upload/local release | `com.apps.winka.handyhabit` | `56:52:FC:04:88:CC:82:DD:63:7D:F4:F9:5C:B8:37:B1:FA:3C:60:15` |
   | Handy Habit — debug | `com.example.handysuite.habit.flutterpilot` | `40:26:55:25:3B:76:A3:F6:6D:58:FE:DF:87:8F:38:71:34:82:06:4D` (same debug key as the siblings) |

   Play certificate: **Play Console → Handy Habit → Test and release → Setup →
   App integrity → App signing key certificate → SHA-1**. The owner supplies the
   upload/debug fingerprints from their signing records or local signing tools.
   Do not paste signing passwords or private keys into documentation or chat.
   Release builds sign with the upload key `C:\Users\Winka\handy-habit-upload.jks`
   (alias `upload`; passwords in `~/.secrets/handy-habit-upload.properties`,
   copied to the gitignored `apps/handy_habit/android/key.properties`).
8. On the owner’s two Android devices, choose the same Google account in Sync.
    Verify the account in Google’s sheet, successful sync, pending count and activity.
    Recheck all three signing variants before calling Drive release-ready.

Official references: [Drive appdata](https://developers.google.com/workspace/drive/api/guides/appdata),
[Drive uploads](https://developers.google.com/workspace/drive/api/guides/manage-uploads),
[Google Sign-In Android integration](https://pub.dev/packages/google_sign_in_android#integration).

## Supervisor two-device verification

- Start with a separate backup on both phones. Cancel account selection and deny
  permission once; then connect. Confirm only appdata access and the correct account in Google’s sheet.
- Make simultaneous count check-ins and negative incidents offline; reconnect in
  both orders. Confirm both contributions, no duplicates, and stable stored days.
- Record conflicting absolute totals, skip versus add, and same-day mood notes.
  Confirm Needs review, both alternatives, neutral progress, explicit resolution
  and convergence after both phones sync again. Test Undo from either phone.
- Change schedules/archive/routine steps concurrently; complete the same linked
  step twice offline, create separate runs, trash/restore/purge with a stale phone.
  Check exactly-once linked contributions and no tombstone resurrection.
- Interrupt upload/download, toggle airplane mode, background/return, force-close
  and reopen. Confirm local data survives, retries converge and no closed-app
  background schedule is promised. Revoke Google access externally and retry.
- Turn off, disconnect, reconnect and change accounts explicitly. Check neither
  copy is deleted and the old account is never silently selected for a new account.
- Inject a newer-protocol/schema generation in a controlled test account; verify
  the update message, no upload/overwrite, unchanged local data. Check corrupt,
  incomplete and duplicate remote bodies also fail safely.

## Limits

Foreground sync only; preferences, reminders, clock policies, running timer
anchors and OAuth metadata are device-local. Saved civil event days never move.
One local active runner is allowed: concurrent extra active sessions are retained
as aborted recovery records; receiving does not start their timers.
No attachment field exists in Habit, so there are no attachment bytes to sync.
Remote generations are retained without automatic compaction or deletion. Current
limits: 30 MB/file, 200000 operations, 10000 Drive-listed files; long-running
history growth/initial sync performance needs later scale work. Sync is not a
backup and is not end-to-end encrypted. Real OAuth/runtime remains unverified
until the owner and supervisor complete the steps above.

## Google Play (set up 2026-11-10)

| Item | Value |
|---|---|
| Play package (release) | `com.apps.winka.handyhabit`, created by the owner 2026-11-10 |
| Debug package (BlueStacks) | `com.example.handysuite.habit.flutterpilot` (unchanged so test data stays) |
| Kotlin namespace | `com.example.handysuite.habit` (unchanged) |
| Upload key | `C:\Users\Winka\handy-habit-upload.jks`, alias `upload`, SHA-1 `56:52:FC:04:88:CC:82:DD:63:7D:F4:F9:5C:B8:37:B1:FA:3C:60:15`. Never print or commit its passwords |
| Listing | EN + VI title, short and full description pushed by the API (`android/fastlane/metadata/android/*`); contact `apps.winka.studio@gmail.com` |
| Pro product | one-time product `handy_habit_pro`, created and ACTIVE 2026-11-10 by the API after 1.0.0 (2) brought the billing permission: 99,000 VND (US 3.89 USD, 174 regions, others converted by Play), listing EN + VI. The licence key (Play Console > Monetization setup) still goes into `config/monetization.local.json` `habit.android.androidPublicKey` |

Publish from `apps/handy_habit/android/` as Boards does (`docs/HANDY_BOARDS_RELEASE.md`): bump `version:` in `pubspec.yaml`, write `fastlane/metadata/android/{en-US,vi}/changelogs/N.txt`, run `python tooling/prepare-store-config.py config/monetization.local.json` from the repo root, then `HANDY_DRIVE_SYNC=true fastlane android publish`. The build lane keeps the pub step: without it the Android plugin registrant lists the dev-only `integration_test` plugin and the release compile fails.

| Version | Track | Date | Notes |
|---|---|---|---|
| 1.0.0 (1) | closed testing (alpha), **draft** | 2026-11-10 | First upload by the API (store forms not filled yet, so Play keeps it a draft). Built with `HANDY_DRIVE_SYNC=true`. Gives the Play app-signing SHA-1 for the OAuth client |
| 1.0.0 (2) | closed testing (alpha), **draft** | 2026-11-10 | Adds Pro Lifetime with the real Play store (`handy_store`, billing permission), Advanced routines, consistency pass. Built with `HANDY_DRIVE_SYNC=true` |
| 1.0.0 (3) | closed testing (alpha), **draft** | 2026-11-11 | New icon (kept/due ring with today's bead), fixes from the BlueStacks walk-through, store graphics uploaded: 512 icon, feature graphic EN + VI (`tool/store_graphics.py`), 6 phone screenshots EN + VI (`tool/store_shots_test.dart`). Release APK smoke-tested on BlueStacks (guide, templates, routines; icons intact after tree shaking) |
| 1.0.0 (4) | closed testing (alpha), **draft** | 2026-11-11 | Interactive home-screen widgets (tap a bead to check in; Week and 16 weeks with Pro), quick add for habits and routines, reminder/icon/colour in the editor, runner with a timer ring, mood in one tap, Settings/Pro/How to use on the Boards frame. Store graphics remade: 7 phone screenshots EN + VI (adds widgets), feature graphic. Release APK smoke-tested on BlueStacks |
