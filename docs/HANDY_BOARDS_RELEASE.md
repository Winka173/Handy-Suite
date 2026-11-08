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
| Pro product | one-time product `handy_boards_pro` (in `config/monetization.local.json`, not yet created in Play) |
| Upload key | `C:\Users\Winka\handy-boards-upload.jks`, alias `upload`; SHA-1 `39:52:00:F5:76:BD:4F:28:7C:95:F3:EC:CA:FE:FC:E1:F8:A6:5B:03` |
| Key passwords | `~/.secrets/handy-boards-upload.properties`, copied to the gitignored `apps/handy_boards/android/key.properties`. Never print or commit |
| Privacy policy | `https://github.com/Winka173/Handy-Suite/blob/ui-rebuild/apps/handy_boards/PRIVACY.md` |
| Terms | `https://github.com/Winka173/Handy-Suite/blob/ui-rebuild/apps/handy_boards/TERMS.md` |

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
| 1.0.0 (1) | closed testing (alpha), **draft** | 2026-11-08 | First upload, by the API (the app accepted edits before any bundle existed). Listing text EN + VI pushed. Waiting for the owner's Play Console forms and the first review |

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
  logo**, home page `https://github.com/Winka173/Handy-Suite`, privacy
  `https://github.com/Winka173/Handy-Suite/blob/ui-rebuild/apps/handy_boards/PRIVACY.md`,
  terms `https://github.com/Winka173/Handy-Suite/blob/ui-rebuild/apps/handy_boards/TERMS.md`,
  authorized domain `github.com`; Data Access scope `.../auth/drive.appdata`;
  Audience → **Publish app**.
- **Android OAuth clients**:

  | Client | Package | SHA-1 |
  |---|---|---|
  | Play app signing (installs from Play) | `com.apps.winka.handyboards` | Play Console → Handy Boards → Test and release → App integrity → App signing key certificate → SHA-1 |
  | Upload key (local release builds) | `com.apps.winka.handyboards` | `39:52:00:F5:76:BD:4F:28:7C:95:F3:EC:CA:FE:FC:E1:F8:A6:5B:03` |
  | Debug (BlueStacks) | `com.example.handysuite.handy_boards.flutterpilot` | `40:26:55:25:3B:76:A3:F6:6D:58:FE:DF:87:8F:38:71:34:82:06:4D` |

Verified 2026-11-08: engine merge tests (two devices, both-side edits,
delete vs edit, deleted column, attachments, concurrent write, edits during
a sync) and app controller tests with an in-memory Drive. Not yet run
against real Google Drive (needs the clients above), not on iOS.

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
3. Store graphics: icon 512×512, feature graphic 1024×500, at least two phone
   screenshots (not made yet).
4. Closed testing: the testers' list or Google Group, then *Send changes for
   review*.
5. Pro: create the one-time product `handy_boards_pro` (*Monetise → Products →
   One-time products*), now possible because 1.0.0 (1) carries the billing
   permission.
