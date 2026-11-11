# Release checklist — R27

2026-11-11. Host source candidate, not store certification. Existing Google Play
setup/draft history in [RELEASE](RELEASE.md) unchanged. Version 1.0.0+2;
supervisor owns next build/version/submission. [Host results](TEST_RESULTS.md).

- [x] Schema 9/physical 2/protocol 1 and migration documented.
- [x] Feature/entitlement/platform/settings/help/backup/sync inventories reconciled.
- [x] Six phone scenes per EN/VI, 1080×2160 (360×720 @3x), `apps/handy_habit/build/store/`.
- [ ] Supervisor approves/uploads PNGs; icon/feature graphic/localized listing match actual capabilities.
- [ ] Privacy policy URL **pending, owner will make it later**. Intended About links: `https://winka.top/en/apps/handy-habit/privacy/` and VI equivalent; do not declare them live.
- [ ] Owner checks support/contact, identity, final merged permissions, version code/signing/target SDK against current Play acceptance.
- [ ] Complete Data safety and ads declaration from actual release SDK/config inventory below; retain submitted answers.
- [ ] Complete IARC content rating for local habits/routines/mood/advertising; no public chat/UGC service or gambling source feature.
- [ ] Choose actual target age groups; UI does not establish child-directed/Families status. Review audience/ads configuration.
- [ ] Health apps declaration: wellness/fitness/nutrition/sleep templates and optional mood; no Health Connect/Apple Health access or diagnosis/clinical advice. Select categories matching final features/listing; absent health permissions alone does not mean no health features.
- [ ] Drive API/consent publication/test users, debug/upload/Play-signing Android OAuth clients per RELEASE; no Web client ID required.
- [ ] Owner fills Play licence key locally; active `handy_habit_pro`/price supervisor-reported, not transaction evidence.
- [ ] Closed-track and licence testers: install/update/buy/cancel/pending/restore/refund/revoke/offline restart; supported-region ads/consent.
- [ ] Final Android device/binary checks below with actual provenance; existing BlueStacks startup alone insufficient.
- [ ] Resolve or explicitly accept the legacy schema-8 mood/pause CSV import gap in [KNOWN_ISSUES](KNOWN_ISSUES.md); JSON/ZIP1–9 migration remains supported.
- [ ] iOS macOS/Xcode/signing/native QA, Windows installed-package QA, Web release/browser/offline QA before those releases.

## Data safety answer worksheet — draft, not submitted

| Data/path | Source fact | Answer/evidence still required |
| --- | --- | --- |
| Habits/check-ins/routines/optional mood/notes | SQLite/IndexedDB, no developer backend, explicit export | Local-only processing alone is not off-device collection; assess backup/sync separately, no blanket “no collection” claim |
| Drive appdata | Optional causal upload/download including mood; session authorization; not end-to-end encrypted | Assess actual categories/collection/sharing/exceptions. App reads/writes synced data; own-cloud exception not assumed |
| Windows cloud folder/export | User-selected files, vendor transport | Explain user transfer/provider responsibility/retained copies; verify release behavior |
| Play Billing | Native purchase/restore/verified device cache, no app card entry | Actual SDK purchase-history/account/identifier disclosures; grants/tokens not in backups |
| Ads/consent | Supported Android host, Pro removes ads, config determines traffic | Review actual AdMob/UMP identifiers, IP/location, interactions/diagnostics/purposes as applicable; encryption/sharing/optionality/deletion responses need actual config/SDK evidence |
| Account/deletion | No Habit server account; optional Google account; local delete-all leaves external files | Confirm applicable console responses; explain provider/backup cleanup, no remote secure-erasure promise |

Google's [Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
requires actual app/SDK behavior assessment. The
[Health declaration guidance](https://support.google.com/googleplay/android-developer/answer/14738291?hl=en)
also covers closed/open/production tracks. Checked 2026-11-11; submitted console
answers remain owner work. This worksheet is not a completed declaration.

## Supervisor device order

1. At 1080×2400/density ~2.6: guide story/practice/final EN/VI, light/dark, default/large text, Skip/Back/Enter/OS back, no shrink/clipping or practice writes; fresh/update/replay.
2. Pro batch archive/group/pause/reminder preview, exact selection, one Undo, stale/failure refusal, disabled reminders stay off.
3. Durable check-in/zero/Undo, archive/Trash, schema upgrades, restart/runner background/crash, real-provider/sealed backup/restore/recovery.
4. Two-device OAuth/offline/concurrent deltas, absolute conflicts/mood/Undo/tombstones/disconnect/revoke; separate backups first.
5. Reminder deny/grant/quiet/private/reboot/battery; compact/large widget privacy/links; TalkBack/keyboard; actual Billing/ads/consent.

[Code versus external tasks](KNOWN_ISSUES.md).
