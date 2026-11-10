# Platform capabilities

| Capability | Android                                 | iOS                                               | Windows                 | Web                       |
| ---------- | --------------------------------------- | ------------------------------------------------- | ----------------------- | ------------------------- |
| Local data | SQLite worker                           | SQLite source                                     | SQLite worker           | IndexedDB                 |
| Files      | User picker/share                       | User picker/share                                 | Native dialogs          | Upload/download           |
| Reminders  | Permission + inexact local schedule; diagnostics | Permission/local source | Kit Windows toast source; permission unreadable | In-app due list |
| Widgets | Today / One habit / Routine; compact/large, system theme + Pro palette; Android compiled | Preview only | Preview only | Preview only |
| Runner     | Foreground monotonic; paused-run notice | Foreground monotonic; paused-run notice (passive) | Foreground monotonic    | Foreground monotonic      |
| Cloud sync | Optional Drive appdata; Android build define + owner OAuth setup | Not implemented; use backup | Not implemented; use backup | Not implemented; use backup |
| Ads/Pro    | NativeLifetimeStore / Play Billing, device-bound verified cache; Pro page and configured ads removal (run12) | Pro demo page; purchase unavailable | Pro demo page; purchase unavailable | Pro demo page; no checkout |

Runtime verification is separate from compilation. Browser eviction/quota, physical
devices and real stores need evidence. iOS needs macOS/Xcode, unavailable on this host.
No precise background delivery/autoplay guarantee. No habit history in ads/telemetry.

Reminder planning is bounded to 200 rules and the earliest 50 occurrences within
400 days; reopen/edit to refresh. This supports 90/366-day intervals without a fake
month-only preview. Android boot receiver is registered; actual delayed/reboot delivery
is NOT VERIFIED. Windows toast source is wired with kit identity/details in run14; delivery still needs Windows runtime checks. Web background reminders remain unavailable.
Builds, emulator runtime, host SQLite tests and physical/store verification are separate
in QA_PLAN and the audit. No release readiness follows from compilation alone.

R15/R16 source/host tested; actual Android Drive authorization and two-device runtime remain unverified. [Owner setup](RELEASE.md).


Run14/R22: diagnostics reads Android exact-alarm/battery status; exact alarms are not
required and are never requested. Battery/notification links open system settings.
Widget selections apply to every instance of a type; taps open Habit, not a background
writer. Refresh follows changes/app open; closed-app midnight refresh is not scheduled.
OS/launcher theme and resize behavior, reboot, battery restrictions and actual delivery
remain supervisor checks. See [R22](R22_REVIEW.md).
