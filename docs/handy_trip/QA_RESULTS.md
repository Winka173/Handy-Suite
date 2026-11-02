# QA results

Updated 2026-11-02. Results describe explicit snapshots, not universal bug freedom.

[Verified final artifact/source checkpoint](../qa/evidence/trip-final-checkpoint.json)
and [70-screen review index](../../review-shots/trip/README.md).

| Check | Evidence / result |
| --- | --- |
| Engine | 36 tests PASS; trip-engine-tests.log; analyze clean |
| App | 17 tests PASS; trip-app-tests.log; analyze clean |
| Performance | trip-performance.json; 10/100/1000 trips, 100/1000/10000 visits; host SQLite/ZIP/RSS only |
| Responsive UI | 70 actual widget screenshots, real fonts, 320/390/768/1024/1440 widths, EN/VI/light/dark; trip-review-shots.log |
| Large text | 320px at 200%, no overflow; app UI tests |
| Independent exports | trip-pdf-validation.json; PyMuPDF, Pillow, zipfile; actual PNG/PDF/ZIP decode, no booking-code/private-caption leakage, no EXIF in exported photos |
| Android P0 | trip-native-write-report.json: UI check-ins, original bytes, ZIP/Undo, OS foreground emulator GPS, schedule/delivery/cancel |
| Android restart | trip-native-read-result.json/report.json: force-stop previous process, read PID 8929; two visits, originals and links preserved; source e9531374ebd6 unchanged |
| Android share | trip-share-write-result.json: ACTION_SEND cancel/save/commit-before-ack/reopen; real response recovered from same PID after driver transport failure |
| Android permissions | trip-permissions-write-result.json: GPS denied to manual fallback, actual Photo Picker Back cancellation, notification permission denied; settings restored afterward |
| Android P1 | trip-memories-write-result.json/report.json: real PNG/PDF/book ZIP on native filesystem, EXIF preview then confirmed visit, comparison/replay, SQLite and ZIP; source e9531374ebd6, PID 9251, unchanged |
| Builds | builds-apk.json, builds-windows.json, builds-web.json: select app=trip, exitCode=0, sourceUnchanged=true and matching hash |
| Android bundle | trip-aab-result.json; unsigned, no store claim |
| Windows package | trip-msix-result.json; unsigned, not installed or store-associated |
| Web worker | trip-pwa-tests.log: Node VM service worker/cache checks, not browser runtime |

All native tests use dedicated HandyTrip_QA_API35 / emulator-5570, not physical
hardware. GPS coordinates/accuracy are emulator-generated. QA photos are synthetic
local metadata fixtures; production has no seeded examples. Native exports use a
test-owned filesystem port invoking real serializers, not the OS save picker.

Driver transport failure is not a test pass. Recovery accepts genuine integration
response only from the surviving process and an unchanged source fingerprint.
Earlier restart source drift remains historical, not current-source certification.

Baseline core/workspace analyze passed before Trip; later workspace-wide analyze
encountered concurrent unrelated app changes. Trip checks are scoped. No claim that
all other apps pass. Remaining limits: KNOWN_LIMITATIONS.md and release checklist.

Final release-to-debug test initially lacked integration_test registration. Failure
logs remain trip-memories-missing-plugin-*. Regenerating the debug registrant fixed
the harness; the rerun retrieved genuine passing results. No app data reset.

Reproduce from root (PowerShell):

```powershell
Push-Location packages/handy_trip_engine
flutter test --no-pub
Pop-Location
Push-Location apps/handy_trip
flutter analyze --no-pub
flutter test --no-pub
Pop-Location
& tooling/trip-native.ps1 -Scenario memories
& tooling/flutter-builds.ps1 -Apps trip -Target apk
& tooling/trip-aab.ps1
python tooling/trip-validate-exports.py
```

Native helper requires the dedicated QA AVD and preserves installed data. A normal
app entrypoint APK is preserved separately under artifacts/flutter/handy_trip/android;
integration runs overwrite only the generated app-debug.apk.
