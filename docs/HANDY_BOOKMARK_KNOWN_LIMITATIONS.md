# Handy Bookmark known limitations

- **IN_PROGRESS** overall; code/tests are not a release or zero-bug certificate.
- iOS target and actual Share Extension source are present but need macOS/Xcode,
  an Apple team and provisioned App Group. No iOS execution is claimed.
- Real social-app share menus, authentication/private/deleted posts, installed app
  dispatch and physical-device behavior need actual installed applications. Saving
  never requires successful metadata. Facebook may require More/System Share.
- Optional metadata sends the URL to its public site, defaults off, uses no cookies
  or login sessions, and has strict public-address checks. Web metadata deliberately
  reports unavailable instead of using an unsafe proxy/redirect assumption.
- The external metadata probe on this Windows host failed (`httpStatus` for
  example.org; `networkUnavailable` for dart.dev). Parser/security unit tests pass,
  but a successful live-site fetch has not been demonstrated. See
  `qa/evidence/save-live-metadata.json`; no successful network claim is made.
- Native SQLite/FTS is measured; Web search currently reads local records for the
  shared fallback. Large-browser-library startup/memory/frame performance unverified.
- Backup byte budget is 30MB. Text formats with embedded full-state metadata can
  hit it earlier. Cached/manual thumbnail images are not included in backups.
- Native notifications schedule up to 50 future reminders; all remain visible in
  the app. Exact/background/reboot delivery and iOS behavior need device testing.
  Windows/Web use in-app reminders.
- Local database, exported URLs and notes are not encrypted. No biometric app lock
  is implemented (optional in scope). No cloud sync, backend or account system.
- Pro features require actual verified store ownership. No publisher accounts,
  real product IDs, release signing or AdMob consent configuration are available.
  No web fake entitlement or cross-store purchase portability is provided.
- Import cancellation is guaranteed before commit; a native transaction already
  committing is not presented as cancelable. Worker transport failure may have
  committed: reload before retry. Browser quota/recovery failures preserve data.
- Windows native drop compiles and parser tests pass; Explorer/browser interaction
  remains separate from compiler evidence. PWA worker VM tests are not browser QA.
- Offline reading copies and link checks (2026-11-02) run only on request through the
  same pinned public-address fetcher; they are unavailable on Web. Host tests serve
  pages from a local server through test seams; no live website, emulator or device
  run is claimed. The extractor is a heuristic: app-rendered pages (many social
  sites), sign-in walls and paywalls give no copy; images are never kept; one copy
  keeps at most 200,000 characters. Deleting a link deletes its copy, and Undo brings
  the link back without the copy. A check of 403/429/5xx or a network failure is
  "could not tell", never "gone"; checks never change an address by themselves.
