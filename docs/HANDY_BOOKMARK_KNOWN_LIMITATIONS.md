# Handy Bookmark known limitations

- **IN_PROGRESS** overall; code/tests are not a release or zero-bug certificate.
- iOS target and actual Share Extension source are present but need macOS/Xcode,
  an Apple team and provisioned App Group. No iOS execution is claimed.
- Real social-app share menus, authentication/private/deleted posts, installed app
  dispatch and physical-device behavior need actual installed applications. Saving
  never requires successful metadata. Facebook may require More/System Share.
- Reading a saved page for its title and picture is on by default (Settings ›
  Data › Library tools switches it off). It sends the URL to its public site, uses
  no cookies or login sessions, never impersonates a browser or crawler, and keeps
  strict public-address checks. Web metadata deliberately reports unavailable
  instead of using an unsafe proxy/redirect assumption.
- Live reads on 2026-11-07 (Windows host, the app's own client) gave a title and
  picture for Facebook share links (posts and reels), Instagram posts/reels,
  YouTube videos/Shorts, X and Threads posts (the post text is the title), TikTok
  videos and ordinary sites. Limits seen:
  - Facebook/Instagram sometimes answer with their login page, and always do for
    age-restricted or private items. The app does not keep that as a title; it
    asks again after 45 s and when the app next opens.
  - TikTok's caption and cover come from the video page's data block (read as
    JSON, never run); TikTok can change that shape without notice. A video TikTok
    says is gone keeps the page's generic title.
  - Reddit post pages answer apps with a bot check (not bypassed): the title and
    author come from Reddit's official oEmbed, which has no picture.
  - Stack Overflow and Amazon answered apps with an error. Short share links
    (`vt.tiktok.com`, Reddit `/s/`) were not tested with real links.
  - Not run on a real iPhone; iOS uses the same Dart client.
- Android's share sheet (2026-11-07): sharing to the app saves first, then shows
  the page's picture and title and asks where it goes (a collection, a new one
  named in place, or Not sorted on close). Tested on BlueStacks (Android 11)
  from Chrome; the sheet starts its own Flutter engine, so it appears about a
  second after the tap. If the app takes the share in while the sheet is open,
  the choice is queued again and moves the link out of Not sorted (a picture
  share keeps Not sorted). With the app lock on, no collection is listed.
  iOS's Share Extension has no such sheet yet.
- Native SQLite/FTS is measured; Web search currently reads local records for the
  shared fallback. Large-browser-library startup/memory/frame performance unverified.
- Backup byte budget is 30MB. Text formats with embedded full-state metadata can
  hit it earlier. Cached/manual thumbnail images are not included in backups.
- Native notifications schedule up to 50 future reminders; all remain visible in
  the app. Exact/background/reboot delivery and iOS behavior need device testing.
  Windows/Web use in-app reminders.
- Local database, exported URLs and notes are not encrypted. The optional app lock
  (fingerprint/face/device PIN) guards opening the app only. No cloud sync, backend
  or account system.
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
  keeps at most 200,000 characters. Schema 3 retains deleted reading copies for
  seven days, hidden from active reads and backups. Restoring the same ID and URL
  restores its exact copy atomically; the one-step UI Undo still does not survive
  app restart. Expired deleted copies are pruned on a later write. A check of
  403/429/5xx or a network failure is
  "could not tell", never "gone"; checks never change an address by themselves.
