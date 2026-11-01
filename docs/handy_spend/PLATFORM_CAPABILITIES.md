# Platform capabilities

| Capability | Android | iOS | Windows | Web |
| --- | --- | --- | --- | --- |
| Ledger | SQLite worker | SQLite worker source | Real SQLite tests | IndexedDB source |
| Files | User picker | User picker | Picker + native drop | Upload/download + drop |
| Reminders | Local plugin/permission | Local plugin source | In-app upcoming list | In-app upcoming list |
| Lock | OS biometrics/device PIN | Local authentication source | Windows Hello adapter | No verified device lock |
| Ads | Official mobile adapter | Official mobile adapter source | No mobile AdMob | No fabricated ads |
| Pro | Play verification | StoreKit source | Microsoft Store adapter | Free; no fake local Pro |

`lib/capabilities.dart` controls platform affordances. Configured plugin support does
not mean a flow has been device verified. iOS cannot build on this Windows host.
Real accounts/product IDs/AdMob consent/release signing are unavailable. No bank
credentials, SMS/notification reading, cloud service or cross-store ownership claim.
PWA offline/cache checks and actual installed-browser behavior are separate checks.
Browser records can be evicted; offer manual backup. Native build/test results will
be recorded in QA_MATRIX.md; untested runtime remains explicitly unverified.
