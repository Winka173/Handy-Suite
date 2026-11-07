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
- Closed testing (`alpha`): **1.0.0 (5)** released on 2026-11-07 by
  `fastlane android publish` (share sheet lists collections made in earlier
  sheets, newest first), tester group `testers-community@googlegroups.com`;
  the app passed its first review on 2026-11-07. Build 4 (Pro and Google Drive
  sync) was uploaded by hand while every API edit for this app answered 500
  for a few hours after the first review; the API worked again for build 5.
  Codes 1–5 are used up.

## Left for the owner in Play Console (the API cannot do these)

1. **Store settings → App category:** Productivity. Tags as you like
   (bookmarks, read later, organizer).
2. **Policy → App content:**
   - **Privacy policy:**
     `https://github.com/Winka173/Handy-Suite/blob/ui-rebuild/apps/handy_bookmark/PRIVACY.md`.
     Change `ui-rebuild` to `main` once the branch is merged.
   - **App access:** no account or sign-in. If Play asks for full access to
     paid content, give a promo code for `handy_bookmark_pro` (see Pro below).
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
   - *Releases:* done for 1.0.0 (4).
4. **Publishing overview → Send changes for review.** Until this first review
   passes, Play accepts drafts only; afterwards `fastlane android publish`
   rolls out by itself.
5. Testers open the opt-in link, accept, then install from Play.

## Pro (one-time purchase)

- Product **`handy_bookmark_pro`** on Play, created through the API on
  2026-11-07: one purchase option `buy`, active, **99,000 VND** in Vietnam
  and Play's conversion elsewhere (3.89 USD in the US; 174 regions), titles
  and descriptions in English and Vietnamese.
- The app finds it through `HANDY_MONETIZATION_CONFIG`: the owner's
  `config/monetization.local.json` (gitignored; `bookmark.android` has the
  product id and the listing URL) →
  `python tooling/prepare-store-config.py config/monetization.local.json` →
  `.tooling/monetization-defines.json`, which `fastlane android build`
  passes with `--dart-define-from-file`.
- **How a purchase is trusted:** Google Play's word, as most apps do (the
  `in_app_purchase` way; chosen 2026-11-07). `handy_store` checks that the
  purchase Play reports is this app's product, bought, with a token, then
  keeps it in a device-bound Keystore-encrypted cache. No licence key is set
  (`androidPublicKey` empty). Setting the key from *Kiếm tiền qua Play ›
  Thiết lập kiếm tiền › Cấp phép* turns on the extra on-device signature
  check, which stops faked answers on a tampered device.
- Testing purchases: add the testers' Google accounts as **license testers**
  (Play Console → Settings → License testing) so they are not charged.
- Reviewers: if App access asks for full access to paid content, create a
  promo code for `handy_bookmark_pro` (*Monetize → Promo codes*) and give it
  in the App access instructions, as Sticky Wall does.

## Google Drive sync (Android)

How it works: `apps/handy_bookmark/lib/sync/` (`drive_provider.dart`,
`drive_sync.dart`, `drive_section.dart`), on the engine's folder-sync merge
(`packages/handy_bookmark_engine/lib/src/sync.dart`). Shown only in builds
made with `--dart-define=HANDY_DRIVE_SYNC=true` (`HANDY_DRIVE_SYNC=true
fastlane android build`), so a store build never offers a switch that cannot
connect.

One-time setup by the owner, in Google Cloud project `play-publisher-513712`
(or another):

1. **APIs & Services → Library → Google Drive API → Enable.**
2. **OAuth consent screen** (Google Auth Platform → Branding / Audience /
   Data access): app name *Handy Bookmark*, support email
   `apps.winka.studio@gmail.com`, privacy policy
   `https://github.com/Winka173/Handy-Suite/blob/ui-rebuild/apps/handy_bookmark/PRIVACY.md`,
   terms `…/TERMS.md`; scope `https://www.googleapis.com/auth/drive.appdata`
   (a non-sensitive scope: no Google verification needed). Audience External;
   while *Testing*, add the testers' Google accounts as test users, or publish
   the app to *In production*.
3. **Clients → Create client → Android**, one per signing key:

   | Client | Package | SHA-1 |
   |---|---|---|
   | Upload key (local release builds) | `com.apps.winka.handybookmark` | `C6:CE:87:B8:6D:FF:AF:1B:34:02:35:18:E5:FB:16:0D:20:76:48:AC` |
   | Play app signing (installs from Play) | `com.apps.winka.handybookmark` | Play Console → Test and release → App integrity → App signing key certificate → SHA-1 |
   | Debug builds (BlueStacks) | `com.example.handysuite.bookmark.flutterpilot` | `40:26:55:25:3B:76:A3:F6:6D:58:FE:DF:87:8F:38:71:34:82:06:4D` |

   No client id goes into the app: Android matches the package and
   certificate.
4. Build with `HANDY_DRIVE_SYNC=true`, install on two Android devices signed
   in to the same Google account, Settings › Sync › Turn on Google Drive sync.
   Try: a save on each, one offline while the other edits, a delete and a
   restore from Recently Deleted, pictures, turning sync off, removing access
   in the Google account's settings.
5. **Play Console → Data safety:** the library goes, at the user's request, to
   their own Google Drive; the developer receives nothing. Review whether
   Google wants it declared (Sticky Wall's note says the same).

Verified 2026-11-07: provider and auto-sync tests (fake Drive in memory, two
devices); the Android build with `google_sign_in` 7.2.0; on BlueStacks the
switch opens Google's account chooser and a cancel leaves sync off. A real
Drive round trip has **not** run (needs the clients above).

## Not in this build

- Pro cannot be bought in 1.0.0 (3): it was built before the product
  existed. 1.0.0 (4) carries it.
- iOS is not set up for the App Store.
