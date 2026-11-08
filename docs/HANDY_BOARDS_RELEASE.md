# Handy Boards · Google Play release

How Handy Boards ships to Google Play. The account-wide setup (service account,
secrets, the "publish" routine, production rules) is in Sticky Wall's
`docs/release/PLAY_CONSOLE_API_GUIDE.md`; this file holds what is Boards' own.
Handy Bookmark's `docs/HANDY_BOOKMARK_RELEASE.md` is the sibling it copies.

## Identity

| Item | Value |
|---|---|
| Play package (release) | `com.apps.winka.handyboards`, created by the owner 2026-11-08 |
| Debug package (BlueStacks) | `com.example.handysuite.handy_boards.flutterpilot`: development builds keep the old id so test data stays |
| Kotlin namespace | `com.example.handysuite.handy_boards` (unchanged: the widget and channel classes hang on it) |
| Pro product | one-time product `handy_boards_pro`, created and ACTIVE 2026-11-08 by the API: 99,000 VND (the same as Handy Bookmark Pro; US 3.89 USD, other regions converted by Play), listing EN + VI |
| Upload key | `C:\Users\Winka\handy-boards-upload.jks`, alias `upload`; SHA-1 `39:52:00:F5:76:BD:4F:28:7C:95:F3:EC:CA:FE:FC:E1:F8:A6:5B:03` |
| Key passwords | `~/.secrets/handy-boards-upload.properties`, copied to the gitignored `apps/handy_boards/android/key.properties`. Never print or commit |
| Privacy policy | `https://winka.top/en/apps/handy-boards/privacy/` (VI: `/vi/…`; since 2026-11-09, the GitHub copy stays online for build 3); text from `apps/handy_boards/PRIVACY.md` |
| Terms | `https://winka.top/en/apps/handy-boards/terms/`; data deletion `…/data-deletion/`; support `https://winka.top/en/support/handy-boards/`. Legal text changes go to the website repo (`winka-studio`: `docs/website-kits/handy-boards/legal/` and `src/content/website-kits.json`) too |

Back up the keystore and its properties file with the owner's other secrets:
a lost upload key needs an upload-key reset in Play Console.

## Publish a version

From `apps/handy_boards/android/` (Ruby and UTF-8 as in the guide, §3):

```sh
fastlane android publish            # checks, build, upload to closed testing, roll out
fastlane android publish track:internal
fastlane android preflight          # read-only
fastlane android check              # read-only: can the key reach the app?
fastlane android metadata           # listing text from fastlane/metadata
fastlane android images             # store graphics from fastlane/metadata/*/images
```

Before each: bump `version: x.y.z+N` in `apps/handy_boards/pubspec.yaml`
(`python tool/play.py codes` gives Play's highest code), write
`android/fastlane/metadata/android/{en-US,vi}/changelogs/N.txt` (≤ 500
characters each), and run `python tooling/prepare-store-config.py
config/monetization.local.json` from the repo root so the build carries the Pro
product id.

## History

| Version | Track | Date | Notes |
|---|---|---|---|
| 1.0.0 (1) | closed testing (alpha), **draft** | 2026-11-08 | First upload, by the API (the app accepted edits before any bundle existed). Listing text EN + VI pushed. Replaced by 1.0.0 (2) |
| 1.0.0 (2) | closed testing (alpha), **draft** | 2026-11-08 | Time Navigator, card history, short-screen fixes, Pro card templates / My Work / carry-over / custom fields. Store graphics uploaded (icon, feature graphic, 6 phone screenshots EN + VI from `tool/store_shots_test.dart`), contact email and website set. Play keeps it a draft until the owner finishes the forms below ("Only releases with status draft may be created on draft app") |
| 1.0.0 (3) | closed testing (alpha), **rolled out** (`tool/play.py complete alpha 3`) | 2026-11-08 | Built with `HANDY_DRIVE_SYNC=true` (Drive sync on). Adds notifications (exact alarms where allowed), five home-screen widgets with styles, automation rules, digest, board history, saved filters, custom repeat, report export. Changelog `changelogs/3.txt` EN + VI |

## Google Drive sync (Android)

How it works: the engine's `packages/handy_boards_engine/lib/src/sync.dart`
(three-way merge against each device's base, repair of broken references,
attachments by content hash; tests in `test/sync_test.dart`) and the app's
`apps/handy_boards/lib/sync/` (Drive adapter copied from Handy Bookmark,
`BoardsDriveSync`, Settings › Data › Sync; tests in `test/drive_sync_test.dart`).
Scope `drive.appdata` only. Shown only in builds made with
`--dart-define=HANDY_DRIVE_SYNC=true` (`HANDY_DRIVE_SYNC=true fastlane android
publish`), so a store build never offers a switch that cannot connect.
Delete all data and a replacing restore turn sync off first, so they never
delete anything on the person's other devices.

One-time setup by the owner, click by click in Sticky Wall's
`docs/release/PLAY_CONSOLE_API_GUIDE.md` §10.1 (Google Cloud):

- **Its own project** "Handy Boards" (never `play-publisher-513712`, never
  Handy Bookmark's): Drive API on; Google Auth Platform: name *Handy Boards*,
  External, support/contact `apps.winka.studio@gmail.com`; Branding with **no
  logo**, home page `https://winka.top/en/apps/handy-boards/`, privacy
  `https://winka.top/en/apps/handy-boards/privacy/`,
  terms `https://winka.top/en/apps/handy-boards/terms/`,
  authorized domain `winka.top` (the domain must be verified in Search
  Console by the owner; switched from GitHub on 2026-11-09); Data Access scope `.../auth/drive.appdata`;
  Audience → **Publish app**.
- **Android OAuth clients**:

  | Client | Package | SHA-1 |
  |---|---|---|
  | Play app signing (installs from Play) | `com.apps.winka.handyboards` | Play Console → Handy Boards → Test and release → App integrity → App signing key certificate → SHA-1 |
  | Upload key (local release builds) | `com.apps.winka.handyboards` | `39:52:00:F5:76:BD:4F:28:7C:95:F3:EC:CA:FE:FC:E1:F8:A6:5B:03` |
  | Debug (BlueStacks) | `com.example.handysuite.handy_boards.flutterpilot` | `40:26:55:25:3B:76:A3:F6:6D:58:FE:DF:87:8F:38:71:34:82:06:4D` |

Verified 2026-11-08: engine merge tests (two devices, both-side edits,
delete vs edit, deleted column, attachments, concurrent write, edits during
a sync) and app controller tests with an in-memory Drive.

Real Google Drive, 2026-11-08, debug build on two BlueStacks Android 11
instances (emulators, not phones), the owner picking the same Google account
on each:

| Step | Result |
|---|---|
| 1. Turn sync on, first device (4 boards) | Uploaded; status "Synced" |
| 2. Turn sync on, second device (its own board) | Merged both ways: 5 boards on each |
| 3a. Edit a card on one device | Seen on the other after its sync ("9 cards · 1 done") |
| 3b. Delete a card on one device while the other adds one | Both changes kept on both ("9 cards · 2 done") |
| 4. Turn sync off and on again on one device | Same account picked again: a union, nothing lost or doubled; both devices show the same 5 boards with the same counts (9/2, 0/0, 1/0, 10/3, 0/0) |

Found and fixed during the run: Undo bars that stayed until tapped
(`persist: false`), Settings rows in the wrong group, "no cloud" wording
while Drive sync exists. Not yet run on device: attachments and offline
edits (covered by `sync_test` / `drive_sync_test`); not on iOS.

## What the owner still does in Play Console (once)

The API cannot do these (guide §7). Until the first review passes, Play only
keeps drafts; after it, `fastlane android publish` rolls out by itself.

1. App content forms: privacy policy (URL above), app access (no login),
   ads (no ads), content rating, target audience, data safety (no data
   collected or shared by the developer; optional Google Drive sync sends the
   boards only to the person's own Drive at their request, as Sticky Wall
   declares it), advertising ID (not
   used), government/financial/health (none).
2. Store settings: category *Productivity*, contact email
   `apps.winka.studio@gmail.com`.
3. Store graphics: done by the API (2026-11-08). Remake with
   `STORE_DIR=<dir> flutter test --no-pub tool/store_shots_test.dart`, copy into
   `android/fastlane/metadata/android/<lang>/images/phoneScreenshots`, then
   `fastlane android images`.
4. Closed testing: the testers' list or Google Group, then *Send changes for
   review*.
5. Pro: `handy_boards_pro` exists (above). Change the price in Play Console if
   wanted; add license testers to buy it without being charged.
