# Ads removed from Handy Bookmark (2026-11-06)

## What changed

- `google_mobile_ads` moved out of `packages/handy_monetization` into the new
  `packages/handy_ads`. `handy_monetization` keeps Pro Lifetime purchases only and draws an
  ad banner or ad privacy button only when an `AdProvider` was installed.
- The eleven committed apps that show ads (Tools, Docs, Media, Dev, Keep, Recall, Spend,
  Habit, Trip, Boards, Card) depend on `handy_ads` and call `installHandyAds()` in `main`;
  their ads work as before.
- Handy Bookmark does not depend on `handy_ads`. Removed: `adsVisible` from the controller,
  add-link flow and `HandyApp`; `com.google.android.gms.ads.APPLICATION_ID` and
  `DELAY_APP_MEASUREMENT_INIT` from `AndroidManifest.xml`; the `handyAdmobAppId`
  placeholder from `build.gradle.kts`; `GADApplicationIdentifier` and
  `GADDelayAppMeasurementInit` from `ios/Runner/Info.plist`; `bannerAdUnitId` and
  `adsEnabled` from the Bookmark entry of `config/monetization.example.json`.
- Without a provider the Pro section says "One-time purchase unlocks the Pro features of
  this app. There are no ads." instead of offering to remove ads.

## How it was checked (Windows host, Flutter 3.44.9)

| Check                                                         | Result                                                                                                                                                     |
| ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `apps/handy_bookmark/.flutter-plugins-dependencies`           | `google_mobile_ads`: absent; `webview_flutter_android` (pulled by the ads SDK): absent. Same file for Handy Tools: both present                            |
| `flutter build apk --debug --no-pub` in `apps/handy_bookmark` | Built. Merged manifest (`build/app/intermediates/merged_manifest/debug/...`): 0 matches for `com.google.android.gms.ads`, `MobileAdsInitProvider`, `AD_ID` |
| APK contents                                                  | 0 entries matching `googlemobileads` or `gms/ads`                                                                                                          |
| `packages/handy_monetization/test/ad_slot_test.dart`          | No provider: no banner, no privacy button, "There are no ads"; with a provider: banner for Free, privacy options open                                      |
| `dart analyze`                                                | Clean in handy_monetization, handy_ads, handy_ui, Bookmark and the eleven apps                                                                             |

## Not verified here

- An iOS build (needs macOS/Xcode). The iOS plugin list follows the same Dart dependency
  closure, but no iOS binary was inspected.
- A release (`--release`) Android build and the Play data-safety form; the store privacy
  declaration must be updated to "no ads" when Bookmark is listed.
- Handy Forms and Handy Widget are another session's uncommitted apps: they no longer get
  a banner from `handy_ui` until they add `handy_ads` and call `installHandyAds()`.
