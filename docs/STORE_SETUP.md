# Ads + Pro Lifetime setup

Publisher accounts and production product/ad identifiers are not configured.
Real purchase, restore, refund and release validation remain required.

Implemented: shared controller/settings, real native store adapters, mobile
consent-gated AdMob banner, public per-app/platform config, no subscription,
no custom backend, no entitlement flag in settings imports. Default product IDs
are empty; no sale or Pro unlock occurs. Native mobile app IDs currently use
official Google test IDs and ads default off. Windows/Web Free is ad-free.

## Public identifiers and app identity

Copy `config/monetization.example.json` to a local config and fill the eleven app keys
independently.

Handy Trip uses its independent `trip` key and provisional
`com.example.handysuite.trip` identifiers. iOS receiving shares additionally
needs the Trip Share extension and `group.com.example.handysuite.trip` App Group
registered for the publisher team. No production identifiers are fabricated.

Handy Boards uses key `boards`, provisional Android
`com.example.handysuite.handy_boards` (debug `.flutterpilot`) and iOS
`com.example.handysuite.boards`. Its BoardsShare target needs the publisher
App Group `group.com.example.handysuite.boards` on BOTH host and extension.
Replace these provisional identifiers consistently before registration/signing.
The AAB and MSIX evidence is unsigned; no store release is claimed.

Handy Card uses key `card` and provisional `com.example.handysuite.card`
identifiers on Android (debug `.flutterpilot`) and iOS. Everything is free in
this build because no product exists yet; the planned Pro gates are listed in
`docs/HANDY_CARD_PRODUCT_SPEC.md`. Ads stay off in the studio and export sheet.

Run:

```
python tooling/prepare-store-config.py config/monetization.local.json
```

From an app directory, Flutter accepts
`--dart-define-from-file=../../.tooling/monetization-defines.json`. The public config
contains product IDs, Play licensing RSA public key, banner ad-unit IDs and an
explicit adsEnabled boolean. Each platform may also carry a public
`listingUrl` (https only): the app's store page there, or its web address. The
"Other Handy apps" section in every app's settings lists only siblings that
have one, so it stays hidden until apps are published. Never put service-account JSON, passwords, private
keys or signing material in Dart defines or app assets.

Development APKs use the `.flutterpilot` application ID suffix.
Actual store test/release builds need the correct registered package/bundle IDs,
authorized signing identity, listing association and store test users. Do not
publish debug-signed APKs or the provisional unsigned MSIX.

## Android

For each app: create a managed one-time product for Pro Lifetime, obtain the Play
licensing **public** RSA key, configure internal-test accounts, associate the app
with AdMob and create its banner unit/UMP privacy messages. Native Billing uses
INAPP only and never consumes Pro; acknowledgement follows verified purchase.
Signature/package/product checks reject untrusted receipts. Encrypted Keystore
cache is not a user-importable Pro flag; reinstall/backup without its key requires
Store restore. Offline cached ownership cannot detect a new refund until Store
access succeeds. These are local-verification limits, not backend verification.
[Play Billing integration](https://developer.android.com/google/play/billing/integrate),
[Android Keystore](https://developer.android.com/reference/android/security/keystore/KeyGenParameterSpec).

Replace the native AdMob application ID per app using the Gradle project property
`handyAdmobAppId` (for example the environment variable
`ORG_GRADLE_PROJECT_handyAdmobAppId` before the Flutter build). Banner ad-unit IDs
in Dart config are separate from the native application ID. Run real pending,
cancel, acknowledge, offline reopen, restore, revoked/refunded ownership and
account-switch tests on the signed internal-test build before publishing.

## iOS

Create a non-consumable StoreKit product per app and sandbox testers. Set the
native `HANDY_ADMOB_APP_ID` in each app's Release.xcconfig or an overriding Xcode
build setting; the current xcconfigs contain Google's official test app ID.
Configure AdMob/UMP, app privacy declarations and store metadata for actual SDK
use. Native StoreKit2 accepts verified current entitlements/updates, rejects
revoked/expiring/non-lifetime transactions and calls finish/restore sync. Pro
purchase support requires iOS15+; older supported Free builds do not fake it.
[Apple current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements).

Mac/Xcode archive, StoreKit sandbox purchase/Ask-to-Buy/refund/restore, consent
and physical-device tests are still required. None ran on this Windows host.

## Windows

Associate each signed MSIX with its actual Partner Center app and a durable
non-subscription add-on. Configure its 12-character add-on Store ID. Native
StoreContext is initialized with the Flutter window HWND; it checks associated
Durable products and active matching non-subscription SKU licences. Missing app
identity/association reports unavailable. No fabricated license or simulator
unlock is used. [Microsoft Store purchases](https://learn.microsoft.com/windows/uwp/monetize/enable-in-app-purchases-of-apps-and-add-ons).

Define/implement and verify actual per-app Windows Pro benefits before offering
it for sale; mobile ad removal alone is not a Windows benefit. Package signing,
real associated-product query, pricing, purchase/cancel/restore and refund/account
tests remain pending. Windows currently has a functional ad-free Free tier.

## Ads, consent and Web

AdMob is enabled only for Android/iOS and only after UMP permits ad requests.
Non-personalized requests contain no document/image/QR/API content. Privacy
choice changes discard and re-evaluate the banner. Debug-only HANDY_TEST_ADS uses
official test banner units; privacy messages still require a configured account.
No fake banner is substituted when consent/network is unavailable.
[Google UMP Flutter guide](https://developers.google.com/admob/flutter/privacy),
[Google Mobile Ads plugin](https://pub.dev/packages/google_mobile_ads).

Web stays functional without payment backend; mobile IAP/AdMob are not emulated
there. Store ownership is not automatically shared across stores or applications.

## Evidence and remaining gates

Flutter controller/channel tests pass; Android JVM tests verify real RSA signatures
and reject tampering/wrong keys. Android emulator instrumentation verifies actual
Keystore AES-GCM, random IVs, non-exportable key and tamper rejection. Native
Android/Windows compilation is verified separately from real store ownership.
Logs/XML: `docs/qa/evidence/store-native-*`. Test ports exist only in tests.
Actual sales, store privacy flows and release certification remain CONFIG_REQUIRED.

## Handy Habit

Public config has a ninth `habit` entry (empty/ads disabled until publisher setup).
App namespace `com.example.handysuite.habit`, debug suffix `.flutterpilot`; iOS bundle
`com.example.handysuite.habit`. Android/iOS currently use official test AdMob app IDs;
replace through public build configuration before distribution. Pro uses the same
non-consumable official adapters/restore flow as the suite. Concrete benefits are ad
removal where supported (reusable Routine Lite variants went with Lite on
2026-11-03). Core tracking, reports and full backups remain free. No fake price, purchase or Web payment.
Needed: publisher-owned final bundle/package IDs, product IDs/public license key,
AdMob IDs/UMP configuration, release signing, privacy forms and official sandbox QA.
iOS also needs macOS/Xcode. No credentials should be pasted into docs/source.

## Pro plan (not gated yet)

No build has a store product ID, so nothing can be bought and every Pro gate
would lock the feature for everyone, testers included. The features added on
2026-11-02 are therefore free for now. Already gated: Bookmark smart
collections and saved searches; Spend forecasts past 30 days and statement
templates (what-ifs were removed on 2026-11-03). When products exist, gate one or two features per app
with the existing `LifetimeScope.maybeOf(context)?.pro` check and leave the core
of each app free:

| App      | Pro                                                                          | Stays free                               |
| -------- | ---------------------------------------------------------------------------- | ---------------------------------------- |
| Tools    | Subtitles; salary rule overrides                                             | Gross ↔ Net, number words, lunar, VietQR |
| Dev      | Side-by-side diff; IDs beyond 10 at once; URL query editor                   | Timestamp, HMAC, cron, bases             |
| Docs     | Sign and fill with saved signatures; searchable scan PDF; strong compression | OCR copy and save, picture compression   |
| Media    | GIF export                                                                   | Windows capture, find private details    |
| Keep     | CSV export with value totals; batch add from photos                          | Totals on screen                         |
| Recall   | Anki import keeping Anki's schedule; per-deck read-aloud voices              | Cloze, reverse cards                     |
| Bookmark | Batch link check and batch offline copies                                    | Single-link actions, Pocket import       |
| Spend    | More than 20 receipts or PDF receipts; settle-up history export              | Splits                                   |
| Habit    | Pausing only chosen habits                                                   | Pausing everything, the run notice       |

Automatic backups and their password lock stay free in every app.
