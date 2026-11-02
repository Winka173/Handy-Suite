# Handy Card — test matrix

Statuses: NOT_STARTED / IN_PROGRESS / IMPLEMENTED / UNIT_TESTED /
INTEGRATION_TESTED / PLATFORM_VERIFIED / BLOCKED. Evidence:
`docs/qa/evidence/card-engine-tests.log` (30 tests),
`docs/qa/evidence/card-app-tests.log` (3 widget flows),
`docs/qa/evidence/card-engine-performance.json`.

| Area                                                              | Status                           | Tests                             |
| ----------------------------------------------------------------- | -------------------------------- | --------------------------------- |
| Scene graph serialization, unknown fields and types kept          | UNIT_TESTED                      | editor_test                       |
| Schema migration (0 → 1), newer schema refused                    | UNIT_TESTED                      | editor_test                       |
| Hit test: rotation, nested groups, entered group, locked          | UNIT_TESTED                      | editor_test                       |
| Resize in rotated axes, aspect lock, no drift                     | UNIT_TESTED                      | editor_test                       |
| Group/ungroup placement, group scaling, restack into group        | UNIT_TESTED                      | editor_test                       |
| Arrange, align, distribute, duplicate                             | UNIT_TESTED                      | editor_test                       |
| History: drag = 1 step, coalesced typing, cancel, redo cut, bound | UNIT_TESTED                      | editor_test                       |
| Snapping and angle snap                                           | UNIT_TESTED                      | editor_test                       |
| Badge extension and compatibility without it                      | UNIT_TESTED                      | editor_test                       |
| vCard 3.0/4.0, Vietnamese, folding, private values                | UNIT_TESTED                      | export_test                       |
| QR payloads, too long, print density                              | UNIT_TESTED                      | export_test (no camera scan)      |
| Links, bindings live/snapshot/unlink                              | UNIT_TESTED                      | export_test                       |
| HTML profile / signature escaping                                 | UNIT_TESTED                      | export_test                       |
| SVG, PDF (embedded face, bleed, crop marks), print sheet          | UNIT_TESTED                      | export_test                       |
| Picture crop/fit placement                                        | UNIT_TESTED                      | export_test                       |
| Project ZIP round trip, tampering, traversal, malformed           | UNIT_TESTED                      | export_test                       |
| Batch rows: missing, invalid, duplicates, file names              | UNIT_TESTED                      | export_test (no batch screen yet) |
| Templates valid and round trip                                    | UNIT_TESTED                      | export_test                       |
| Blank card → add, drag, undo/redo, autosave, reopen               | INTEGRATION_TESTED (host widget) | card_flow_test                    |
| Backup ZIP → fresh install → restore                              | INTEGRATION_TESTED (host widget) | card_flow_test                    |
| Phone layout: bottom bar and sheets at 360 px                     | INTEGRATION_TESTED (host widget) | card_flow_test                    |
| Performance at 10/100/500 elements (host)                         | UNIT_TESTED                      | performance_test                  |
| Visual golden comparison canvas vs PNG/PDF                        | NOT_STARTED                      |                                   |
| Android / iOS / Windows / Web runs                                | NOT_STARTED                      | no build made                     |
| NFC, Wallet, brand kits, XLSX, SVG import, batch screen           | NOT_STARTED                      |                                   |

Run: `flutter test --no-pub` in `packages/handy_card_engine` and in
`apps/handy_card`; review shots with
`SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart` from the app.
