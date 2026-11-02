# Handy Card — platform matrix

Statuses: CODED (written, compiles), UNIT_TESTED (host tests), NOT_RUN (no run
on that platform yet), NOT_STARTED.

| Capability                         | Android                                     | iOS             | Windows         | Web                |
| ---------------------------------- | ------------------------------------------- | --------------- | --------------- | ------------------ |
| Editor, gestures, shortcuts        | CODED, NOT_RUN                              | CODED, NOT_RUN  | CODED, NOT_RUN  | CODED, NOT_RUN     |
| Storage                            | SQLite, NOT_RUN                             | SQLite, NOT_RUN | SQLite, NOT_RUN | IndexedDB, NOT_RUN |
| Pick pictures / project files      | System picker (handy_files), NOT_RUN        | same            | same            | same               |
| Save exports                       | System save (handy_files), NOT_RUN          | same            | same            | Download, NOT_RUN  |
| PNG/JPEG/SVG/PDF/vCard/QR/HTML/ZIP | UNIT_TESTED (engine + host widget tests)    | same            | same            | same               |
| NFC write                          | NOT_STARTED                                 | NOT_STARTED     | n/a             | n/a                |
| Wallet passes                      | NOT_STARTED (needs issuer accounts)         | NOT_STARTED     | n/a             | n/a                |
| Ads / Pro                          | Shared adapters, ads off in studio; NOT_RUN | same            | Ad-free         | No purchase on web |

Every result so far comes from `flutter test` on a Windows host. No build has
been made for any platform and nothing has run on an emulator or a device.
Keyboard shortcuts use Ctrl on Windows and web and ⌘ on Apple keyboards (both
are bound).
