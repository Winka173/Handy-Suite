# Handy Trip

Independent offline travel daybook in the Handy Suite Flutter workspace.
Planning never counts as a visit: check-ins require explicit confirmation.
No backend, geofencing, paid maps or cloud AI. Production starts empty.

Run `tooling/flutter-bootstrap.ps1` from the workspace root before the first build.
Then `cd apps/handy_trip` and `flutter run`. Use workspace build scripts for
source fingerprints and the Android build mutex.

Reuses handy_trip_engine and shared UI/files/notifications/monetization packages.
Native storage is SQLite; Web uses IndexedDB. See [feature evidence](../../docs/handy_trip/FEATURE_MATRIX.md),
[functions](../../docs/FUNCTIONS.md) and [QA](../../docs/handy_trip/QA_RESULTS.md).
iOS/physical devices and publisher configuration remain release gates.
