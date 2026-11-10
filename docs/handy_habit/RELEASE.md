# Handy Habit release preparation

R15/R16, 2026-11-10: source implemented and host tested. Android APK compilation is
recorded separately from OAuth, two-device runtime, physical-device and store verification.
No iOS cloud adapter, iCloud entitlement or Android ↔ iOS automatic sync is claimed.

## Google Drive sync (Android)

The Free, optional adapter uses `google_sign_in: 7.2.0` and `http: 1.6.0`, matching
Boards. It requests **only** `https://www.googleapis.com/auth/drive.appdata` for
Drive storage. The account picker’s basic sign-in identity is used to show the
selected account; it does not grant access to ordinary Drive files.

The Settings › Data › Sync row exists only on Android with
`--dart-define=HANDY_DRIVE_SYNC=true`. The public web OAuth client ID described
below is also needed to connect. It is an identifier, not a client secret. A
build without it gives a setup error; backup and offline tracking still work.
Do not bundle OAuth secrets, tokens, keystores or `google-services.json`.

The engine writes immutable, checksummed operation generations and per-device
version receipts. It never PATCHes a shared data file: two writers use different
device/generation names, so a mutable global lock and its check/write race are
unnecessary. Both generations survive concurrent uploads; the next sync joins
them. Download/validation precedes upload and local application is one durable
controller commit. Newer remote schema/protocol data refuses before upload.
See [DATA_SCHEMA](DATA_SCHEMA.md) for merge rules and limits.

## Owner setup — Google Cloud, click by click

These steps require the owner’s Google Cloud/Play access. Code cannot create or
verify the project, consent publication, domain ownership or signing identities.
No keystore or signing certificate was read during this run.

1. Open [Google Cloud Console](https://console.cloud.google.com/). Click the project
   selector at the top → **New project**. Name it **Handy Habit** → **Create**.
   Select that project. Use its own project, not Boards, Bookmark or the publishing project.
2. Open **APIs & Services → Library**. Search **Google Drive API**, open it → **Enable**.
3. Open **Google Auth Platform → Get started** (or **OAuth consent screen**).
   Set app name **Handy Habit**, support email and developer contact to the owner’s
   support address. Choose **External** audience. Complete the initial setup.
4. Open **Branding**. Keep the logo empty unless a verified logo is ready. Enter
   the real published Habit home, privacy and terms URLs. Suggested site paths,
   which the owner must verify/publish before using them:
   `https://winka.top/en/apps/handy-habit/`, `/privacy/`, `/terms/`.
   Add `winka.top` under authorized domains; verify ownership in Search Console
   if Google asks. Save. Do not claim a policy page exists before checking it.
5. Open **Data Access → Add or remove scopes**. Add only
   `https://www.googleapis.com/auth/drive.appdata` as the Drive scope → **Update → Save**.
   Do not choose `drive`, `drive.file` or broad metadata scopes.
6. During setup, open **Audience → Test users → Add users** and add the accounts
   used on the two Android test phones. Before public release, use **Audience →
   Publish app**, complete any Google requirements and verify production access.
7. Open **Clients → Create client → Android**. Create the three entries below.
   Paste the exact package and owner-supplied SHA-1; each certificate needs its
   own client. Click **Create** for each. Current package IDs come directly from
   `apps/handy_habit/android/app/build.gradle.kts`; no production rename is assumed.

   | Name | Package | SHA-1 filled by owner |
   |---|---|---|
   | Handy Habit — Play app signing | `com.example.handysuite.habit` | `<PLAY_APP_SIGNING_SHA1>` |
   | Handy Habit — upload/local release | `com.example.handysuite.habit` | `<UPLOAD_KEY_SHA1>` |
   | Handy Habit — debug | `com.example.handysuite.habit.flutterpilot` | `<DEBUG_KEY_SHA1>` |

   Play certificate: **Play Console → Handy Habit → Test and release → Setup →
   App integrity → App signing key certificate → SHA-1**. The owner supplies the
   upload/debug fingerprints from their signing records or local signing tools.
   Do not paste signing passwords or private keys into documentation or chat.
   Release signing is currently unconfigured in Gradle. If the release package
   changes before publishing, recreate the matching Android clients first.
8. Still in the same project, **Clients → Create client → Web application**.
   Name it **Handy Habit Android sign-in** → **Create**. For this native-only
   use, no web redirect URI or JavaScript origin is needed. Copy its public
   **Client ID**, not the client secret. This is required by the Android
   Google Sign-In 7 integration when no Google Services JSON is used.
9. Build the Android app with the two non-secret defines:

   ```powershell
   flutter build apk --debug --dart-define=HANDY_DRIVE_SYNC=true --dart-define=HANDY_GOOGLE_SERVER_CLIENT_ID=<WEB_CLIENT_ID>
   ```

   Use the equivalent defines for the signed release/appbundle build after
   configuring release signing. A debug build with only the sync gate is a
   compilation check and cannot prove Google authorization is configured.
10. On the owner’s two Android devices, choose the same Google account in Sync.
    Verify the displayed account, successful sync, pending count and activity.
    Recheck all three signing variants before calling Drive release-ready.

Official references: [Drive appdata](https://developers.google.com/workspace/drive/api/guides/appdata),
[Drive uploads](https://developers.google.com/workspace/drive/api/guides/manage-uploads),
[Google Sign-In Android integration](https://pub.dev/packages/google_sign_in_android#integration).

## Supervisor two-device verification

- Start with a separate backup on both phones. Cancel account selection and deny
  permission once; then connect. Confirm only appdata access and the correct account.
- Make simultaneous count check-ins and negative incidents offline; reconnect in
  both orders. Confirm both contributions, no duplicates, and stable stored days.
- Record conflicting absolute totals, skip versus add, and same-day mood notes.
  Confirm Needs review, both alternatives, neutral progress, explicit resolution
  and convergence after both phones sync again. Test Undo from either phone.
- Change schedules/archive/routine steps concurrently; complete the same linked
  step twice offline, create separate runs, trash/restore/purge with a stale phone.
  Check exactly-once linked contributions and no tombstone resurrection.
- Interrupt upload/download, toggle airplane mode, background/return, force-close
  and reopen. Confirm local data survives, retries converge and no closed-app
  background schedule is promised. Revoke Google access externally and retry.
- Turn off, disconnect, reconnect and change accounts explicitly. Check neither
  copy is deleted and the old account is never silently selected for a new account.
- Inject a newer-protocol/schema generation in a controlled test account; verify
  the update message, no upload/overwrite, unchanged local data. Check corrupt,
  incomplete and duplicate remote bodies also fail safely.

## Limits

Foreground sync only; preferences, reminders, clock policies, running timer
anchors and OAuth metadata are device-local. Saved civil event days never move.
One local active runner is allowed: concurrent extra active sessions are retained
as aborted recovery records; receiving does not start their timers.
No attachment field exists in Habit, so there are no attachment bytes to sync.
Remote generations are retained without automatic compaction or deletion. Current
limits: 30 MB/file, 200000 operations, 10000 Drive-listed files; long-running
history growth/initial sync performance needs later scale work. Sync is not a
backup and is not end-to-end encrypted. Real OAuth/runtime remains unverified
until the owner and supervisor complete the steps above.
