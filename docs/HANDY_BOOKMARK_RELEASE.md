# Handy Bookmark on Google Play

Package **`com.apps.winka.handybookmark`**, on the Winka Studio developer
account. Tooling is the same as Sticky Wall's
(`Sticky-Wall/docs/release/PLAY_CONSOLE_API_GUIDE.md` explains it in full);
this page lists what differs and what is set up.

## Where things are

| Item | Where |
|---|---|
| fastlane | `apps/handy_bookmark/android/fastlane/` (`Appfile`, `Fastfile`) |
| Play API tool | `apps/handy_bookmark/tool/play.py` (run without `python -I`) |
| Listing text | `android/fastlane/metadata/android/{en-US,vi}/` (title, short, full, `changelogs/N.txt`) |
| Store graphics (kept in git) | `apps/handy_bookmark/store/` (`icon_512.png`, `feature_graphic_{en,vi}.png`, `screenshots/{en,vi}/1..6.png`) |
| Staged graphics (gitignored) | `android/fastlane/metadata/android/<lang>/images/` |
| Privacy policy | `apps/handy_bookmark/PRIVACY.md` (EN + VI) |
| Service-account key | `~/.secrets/play-publisher.json` (shared by every app) |
| Upload keystore | `C:\Users\Winka\handy-bookmark-upload.jks`, alias `upload`; passwords in `~/.secrets/handy-bookmark-upload.properties`; `android/key.properties` (gitignored) points at it |

Back up the keystore and its properties file with the other secrets. Losing
them means asking Play for an upload-key reset.

## Ids

- Store builds (`flutter build appbundle --release`) are
  `com.apps.winka.handybookmark`, signed with the upload key.
- Debug builds keep `com.example.handysuite.bookmark.flutterpilot`, so the
  libraries on test devices stay where they are. A Play install and a debug
  install are two separate apps on one device.
- The Kotlin namespace (`com.example.handysuite.save`), the on-device storage
  names and the backup format ids keep their old names on purpose.

## Commands (from `apps/handy_bookmark/android`, Git Bash)

```sh
export PATH="/c/Ruby33-x64/bin:$PATH" LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_HIDE_CHANGELOG=1 FASTLANE_OPT_OUT_USAGE=1
fastlane android preflight      # read-only: key.properties, changelogs, versionCode
fastlane android publish        # build, upload to closed testing, roll out (after the first review)
fastlane android closed         # upload the built bundle to closed testing as a draft
fastlane android metadata       # push listing text
fastlane android images         # replace store graphics from the staged images
cd .. && python tool/play.py check   # read-only report (PYTHONIOENCODING not needed)
```

Store screenshots are the app's own renders with sample data, at 1080×1920:

```sh
STORE_LOCALE=vi STORE_SHOTS=1 SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart \
  --name "phone (share sheet|home|collection|detail|focus|dark)"
```

Slides in order: `phone-0-share`, `phone-1-home`, `phone-2-collection`,
`phone-4-detail`, `phone-6-focus`, `phone-1-home-dark`. The photos in them
are Wikimedia Commons pictures from `assets/welcome/CREDITS.txt`; the full
descriptions credit them.

The release bundle needs `android/app/proguard-rules.pro`: the ML Kit
plugin refers to recognizers for other scripts that the app does not
bundle.

## Done through the API (2026-11-07)

- Listing in English (default) and Vietnamese: title, short and full
  description.
- Graphics for both languages: icon, feature graphic, 6 phone screenshots.
- Contact email `apps.winka.studio@gmail.com`, website
  `https://github.com/Winka173/Handy-Suite`.
- Closed testing (`alpha`): draft release **1.0.0 (2)** with release notes in
  both languages. Build 1 was uploaded first and replaced; code 1 is used up.

## Left for the owner in Play Console (the API cannot do these)

1. **Store settings → App category:** Productivity. Tags as you like
   (bookmarks, read later, organizer).
2. **Policy → App content:**
   - **Privacy policy:**
     `https://github.com/Winka173/Handy-Suite/blob/ui-rebuild/apps/handy_bookmark/PRIVACY.md`.
     Change `ui-rebuild` to `main` once the branch is merged.
   - **App access:** all functionality is available without special access
     (no account; Pro cannot be bought in this build).
   - **Ads:** no ads.
   - **Content rating (IARC):** utility/productivity. No violence, sexual
     content, gambling or user-to-user communication. The app shows the titles
     and pictures of pages the user saved and opens links in the browser;
     answer the questions about web content according to that.
   - **Target audience:** 13 and over (not designed for children).
   - **Data safety:** no data collected or shared by the developer. The app
     has no servers or analytics. To show a link's title and picture it
     requests that page from its own site at the user's choice, the way a
     browser does; nothing from the library is sent. Data is not encrypted
     in transit by the app beyond HTTPS to those sites. Users delete data in
     the app or by uninstalling.
   - **Advertising ID:** not used (the build has no AD_ID permission).
   - **Financial features:** none. Government / health: no.
3. **Testing → Closed testing → Alpha:**
   - *Countries/regions:* add Vietnam (and any others).
   - *Testers:* create an email list (or use a Google Group), add the testers,
     save, and copy the opt-in link.
   - *Releases:* open the draft **1.0.0 (2)**, review it, start the rollout.
4. **Publishing overview → Send changes for review.** Until this first review
   passes, Play accepts drafts only; afterwards `fastlane android publish`
   rolls out by itself.
5. Testers open the opt-in link, accept, then install from Play.

## Not in this build

- **Pro cannot be bought.** The build has no billing permission, so the
  Pro purchase is unavailable; no in-app product exists on Play yet. Setting
  it up needs a build with Google Play billing first.
- iOS is not set up for the App Store.
