# Known issues and external blockers

R27, 2026-11-11. [Host results](TEST_RESULTS.md) do not imply physical-device,
actual OAuth, purchase or production certification.

| Severity | Code limitation | Consequence / next work |
| --- | --- | --- |
| High | R26 partial: ledger growth, no segmentation/compaction; initial merge/validation on main isolate | 30 MB/200k guards safely refuse; 100-habit/3-year causal fixture ~81.6 MB cannot sync, 500×1095 exceeds row guard; [measurements](PERFORMANCE.md) |
| Medium | Android widgets only, shared selection per type, app-open action, no closed-app midnight refresh | Other platforms preview-only; no per-instance/background-completion claim |
| Medium | Foreground sync, no generation GC, no iCloud/Web adapter | Manual cross-platform transfer; Windows remote delivery needs vendor client |
| Medium | Android checkout only | Other platforms show demos and unsupported explanation |
| Medium | Runner pauses away; interruption counts persisted elapsed only | No killed/background auto-complete/alarm guarantee |
| Low | Mood deletion has no individual permanent purge | Delete-all removes local library; external/recovery/snapshot copies remain |
| Low | General Sync help Android-centric; convenience help inline | Windows folder explanation inline; no separate FAQ/Pro/rules topic |
| Deferred | Health adapters, dynamic shortcuts, non-Android widgets, biometric lock | Not implemented/offered |

| Severity | External/configuration/verification blocker | Owner / supervisor |
| --- | --- | --- |
| Release blocker | Privacy policy URL pending; owner will make it later | Publish EN/VI, confirm About/Play URLs; source link not live evidence |
| Release blocker | Play forms, signing/release review, tester acceptance | Data safety/ads, rating, audience, Health declaration, actual SDK/config inventory |
| Release blocker | Licence key/actual Billing/consent | Owner sets key locally; testers verify price/buy/cancel/pending/restore/refund/restart |
| High | Actual OAuth/consent/signing/two-device transport | Clients per RELEASE; conflicts/Undo/disconnect/revoke |
| High | Final device/binary acceptance | First guide density/practice, batch preview/Undo, fresh/update; then providers/reminders/widgets/runner/restart |
| High | iOS macOS/Xcode/signing/build | Native storage/Files/notifications/accessibility on owner hardware |
| Medium | Browser storage/offline/quota/eviction/tabs | Built release runtime QA |
| Medium | Windows two-PC cloud-folder/toast delivery | Actual client/conflicts/interruption/toasts |

Prior startup/guide on two BlueStacks Android 11 instances is supervisor-reported;
not final R27, physical-phone/provider/cloud/billing proof. No Gradle build was
started in R27; prior signing-lock failures are historical environment blockers.
This run started no daemon.
