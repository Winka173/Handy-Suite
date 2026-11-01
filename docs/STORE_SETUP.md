# Ads + Pro Lifetime setup

Publisher accounts and production product/ad identifiers are not configured.
Real purchase, restore, refund and release validation remain required.

Implemented: shared controller/settings, real native store adapters, mobile
consent-gated AdMob banner, public per-app/platform config, no subscription,
no custom backend, no entitlement flag in settings imports. Default product IDs
are empty; no sale or Pro unlock occurs. Native mobile app IDs currently use
official Google test IDs and ads default off. Windows/Web Free is ad-free.

## Public identifiers and app identity

Copy `config/monetization.example.json` to a local config and fill the seven app keys
independently. Run:

```
python tooling/prepare-store-config.py config/monetization.local.json
```

From an app directory, Flutter accepts
`--dart-define-from-file=../../.tooling/monetization-defines.json`. The public config
contains product IDs, Play licensing RSA public key, banner ad-unit IDs and an
explicit adsEnabled boolean. Never put service-account JSON, passwords, private
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
