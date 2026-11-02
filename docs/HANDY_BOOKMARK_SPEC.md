# MASTER IMPLEMENTATION PROMPT — HANDY SAVE

## 0. ROLE AND OBJECTIVE

You are a Principal Flutter Engineer, Cross-Platform Architect, Senior UX Designer, Database Engineer, Security Engineer, and QA Automation Lead.

Your mission is to design, implement, integrate, and test a fully functional production-quality application named:

**Handy Bookmark — Universal Bookmark & Link Organizer**

This application is part of the existing **Handy Suite Flutter Monorepo**.

Before implementation, inspect the entire existing repository, its architecture, shared packages, styling, localization, monetization, and build configurations.

Do not create an unrelated standalone project.

Do not rewrite existing shared packages unnecessarily.

Implement the application with real, working functionality rather than mock screens, simulated results, placeholder buttons, or incomplete examples.

### Product vision

Handy Bookmark is a universal bookmark manager that helps users save interesting links from almost any application or website, organize them, rediscover them, and reopen their original source.

Its core workflow is:

**Discover → Share/Copy → Save → Organize → Search → Reopen Original**

The experience should take inspiration from Tuckii and other polished bookmarking applications, but must use original architecture, branding, interactions, and UI design.

Do not copy proprietary code or duplicate another application's distinctive visual identity.

### Critical distinction

Handy Bookmark is NOT:

- A social media downloader.
- A video downloading application.
- A social media scraper.
- A reposting platform.
- A social media client.
- A web crawler.
- A cloud bookmarking service.

Handy Bookmark stores bookmarks and associated lightweight metadata.

When users tap a saved bookmark, it must navigate back to the original URL through the appropriate external application or browser.

Do not download complete videos, reels, images, or other copyrighted media as the primary bookmarking mechanism.

---

# 1. MANDATORY ARCHITECTURAL REQUIREMENTS

The following constraints are non-negotiable:

1. Flutter + Dart.
2. Integrate with existing Handy Suite monorepo.
3. Android support.
4. iOS support.
5. Windows support.
6. Flutter Web support.
7. No custom backend.
8. No cloud database.
9. No mandatory user account.
10. No cloud AI or paid APIs.
11. No generative AI.
12. No subscription.
13. Monetization through Ads + Pro Lifetime.
14. Offline-first data storage.
15. Local SQLite database on supported native platforms.
16. Browser-compatible local storage adapter for Web.
17. Support English and Vietnamese.
18. Light and Dark themes.
19. Reuse Handy shared design system.
20. Preserve user data through migrations.
21. Responsive UI for mobile, tablet, desktop, and web.
22. Full import/export and portable backups.
23. Privacy-first design.
24. No mandatory paid infrastructure.
25. No reliance on running background services.

Do not add Firebase, Supabase, cloud authentication, hosted metadata extraction services, or paid third-party services.

Network access is permitted only when needed for user-initiated link opening, optional public metadata fetching, advertising, and official store purchase operations.

Core bookmark saving, editing, searching, organizing, and exporting must work offline.

---

# 2. APPLICATION STRUCTURE

Add the new application inside the existing monorepo.

Suggested structure:

```text
apps/
  handy_bookmark/
    lib/
      app/
      features/
        home/
        bookmarks/
        collections/
        tags/
        quick_save/
        search/
        focus/
        reminders/
        import_export/
        settings/
        pro/
      platform/
      main.dart

packages/
  handy_ui/
  handy_core/
  handy_storage/
  handy_files/
  handy_export/
  handy_workflow/
  handy_monetization/
  handy_notifications/
```

Inspect existing shared packages before adding dependencies or creating replacements.

Add Handy Bookmark-specific packages only when genuinely necessary.

Use the existing state management and routing approach if it is sound and maintained.

Prefer Riverpod or equivalent existing architecture rather than introducing another incompatible state management system.

Every platform must have independent build and configuration support.

---

# 3. PRIMARY SUPPORTED SOURCES

Handy Bookmark should recognize and save URLs from as many services as practically possible.

## Social media

- Facebook posts.
- Facebook Reels.
- Facebook videos.
- Instagram posts.
- Instagram Reels.
- Instagram profiles.
- TikTok videos.
- TikTok profiles.
- X/Twitter posts.
- X profiles.
- Threads.
- Reddit posts.
- Reddit comments.
- Pinterest pins.
- Pinterest boards.
- LinkedIn posts.

## Video and audio platforms

- YouTube videos.
- YouTube Shorts.
- YouTube playlists.
- YouTube channels.
- Spotify links.
- SoundCloud.
- Podcast pages.
- Other publicly linkable content.

## Shopping

- Shopee.
- Lazada.
- Amazon.
- eBay.
- AliExpress.
- Taobao.
- Other shopping websites.

## General content

- News articles.
- Blogs.
- Documentation.
- GitHub repositories.
- GitHub issues and pull requests.
- Stack Overflow.
- Forums.
- Recipes.
- Maps and place links.
- Educational websites.
- Normal HTTPS websites.

The system must also accept unknown domains.

### Important rule

Platform support means the app can receive, store, organize, and reopen valid URLs.

It does NOT guarantee the ability to fetch metadata from that platform.

Private posts, deleted posts, authentication-required pages, expired URLs, and anti-bot restrictions must be handled gracefully.

Never make successful metadata retrieval a prerequisite for saving a link.

---

# 4. UNIVERSAL QUICK SAVE — MOST IMPORTANT FEATURE

This feature has the highest product priority.

The goal is to make saving a link from another app extremely fast.

## Android Native Share Target

Implement a native Android share receiver.

Support appropriate intents including:

- ACTION_SEND.
- Shared text.
- Shared URLs.
- Relevant ACTION_SEND_MULTIPLE cases where useful.

Register correct intent filters.

Handle:

- App launched from a share.
- App already running.
- App running in the background.
- Cold start.
- Multiple incoming intents.
- Duplicate intents.
- Shared text containing multiple URLs.
- Shared URLs containing surrounding text.
- URL without metadata.
- Malformed URL.
- Very long URL.
- Missing Internet.

Ensure the Android sharing activity integrates correctly with Flutter routing.

Avoid opening duplicate navigation stacks.

### One-Tap Save

Default behavior when receiving a valid URL:

1. Extract URL.
2. Normalize safely.
3. Check for exact or known equivalent duplicates.
4. Save into Inbox.
5. Show brief success feedback.
6. Offer optional Edit Details.

Do NOT require users to select a collection, tag, description, or category every time they save.

The fastest valid workflow should require only choosing Handy Bookmark from the system sharing interface.

If the platform opens Handy Bookmark through a share operation, persist the bookmark before initiating optional metadata work.

Do not block saving while waiting for a network request.

### Facebook-specific behavior

Facebook may show a proprietary internal Share menu.

Handy Bookmark cannot control where Facebook places external applications in that menu.

Do not use accessibility hacks, overlays, hidden APIs, or automation to modify Facebook's UI.

Implement the best supported native share integration and offer a clipboard-based fallback.

Document that Facebook may require selecting More, Custom, or the operating system Share Sheet before Handy Bookmark becomes available.

## iOS Share Extension

Implement a native iOS Share Extension capable of receiving URLs and text.

Requirements:

- Use a suitable App Group when transferring data between extension and host app.
- Do not assume shared Flutter application state is directly available inside the extension.
- Keep extension execution short.
- Avoid expensive metadata fetching inside the extension.
- Save or queue the shared URL safely.
- Prevent loss of incoming data.
- Avoid unnecessary launches of the host application.
- Follow iOS lifecycle and extension restrictions.
- Ensure correct behavior when the host app is closed.
- Do not show advertisements in the extension.

The share extension should provide a minimal and polished saving experience.

## Clipboard Quick Save

Implement clipboard-assisted quick saving.

When the user explicitly opens Handy Bookmark or activates an appropriate shortcut:

- Offer to inspect clipboard content where permitted.
- Detect valid URLs.
- Show a Quick Save suggestion.
- Allow Save, Edit, or Dismiss.
- Avoid repeated prompts for the same clipboard value.
- Prevent accidental duplicates.
- Respect privacy restrictions.

Never continuously monitor clipboard in the background.

Never bypass system clipboard permission behavior.

Do not claim automatic clipboard capture works on every operating system.

## Desktop Quick Save

On Windows support:

- Paste URL.
- Paste multiple URLs.
- Ctrl+V.
- Ctrl+N / quick-add shortcut.
- Window-level drag-and-drop where appropriate.
- Optional protocol/deep-link handling if reliably supported.

## Web Quick Save

Support:

- Paste URL.
- Multiple URL input.
- Add URL form.
- Web Share Target where supported by the browser/PWA.
- Browser-compatible clipboard flows.

Do not require a browser extension for the core product.

Treat a browser extension as a separate future project, not a release blocker.

---

# 5. BOOKMARK DATA MODEL

Design a versioned SQLite-backed data model.

Recommended bookmark fields:

```json
{
  "id": "uuid",
  "originalUrl": "string",
  "normalizedUrl": "string",
  "canonicalUrl": "string|null",
  "platform": "string",
  "contentType": "string",
  "title": "string",
  "description": "string|null",
  "thumbnailUrl": "string|null",
  "siteName": "string|null",
  "author": "string|null",
  "sourceDomain": "string",
  "collectionId": "uuid|null",
  "tags": [],
  "note": "string|null",
  "isFavorite": false,
  "isPinned": false,
  "isArchived": false,
  "isRead": false,
  "openedCount": 0,
  "savedAt": "ISO8601",
  "updatedAt": "ISO8601",
  "lastOpenedAt": null,
  "metadataStatus": "pending|complete|partial|failed|unavailable",
  "metadataSource": "share|html|user|fallback",
  "schemaVersion": 1
}
```

This is a reference model; normalize collections, tags, and their relationships into appropriate database tables.

Use safe migrations.

Add indexes for:

- Normalized URL.
- Source domain.
- Platform.
- Saved date.
- Updated date.
- Collection.
- Favorite state.
- Archived state.
- Read state.

Use full-text search where supported; create a suitable fallback for Web.

Preserve original URLs.

Avoid storing access tokens, cookies, social account credentials, or user sessions.

---

# 6. URL EXTRACTION AND NORMALIZATION

Implement a reliable URL processing engine.

## Extraction

Support:

- Plain URLs.
- URLs surrounded by descriptive text.
- Multiple URLs in shared text.
- Short URLs.
- Mobile and desktop domain variants.
- URLs with Unicode.
- Encoded URLs.
- Query parameters.
- Fragments.
- YouTube Shorts URLs.
- Facebook Reels URLs.
- Instagram Reels URLs.
- TikTok short links.
- X and Twitter domain aliases.

## Normalization

Normalize URLs conservatively.

Possible operations:

- Normalize scheme and hostname case.
- Remove default ports.
- Normalize safely encoded URL components.
- Remove known tracking parameters where safe.
- Identify equivalent hostname aliases.
- Resolve redirects only when network access is allowed and safe.

Do not blindly strip all query parameters.

Some applications use query parameters for essential content identity or access.

Do not assume two links represent the same content simply because their path resembles another URL.

Keep:

- Original URL.
- Normalized URL.
- Resolved/canonical URL when verifiable.

Maintain platform-specific normalization rules with automated test cases.

## Duplicate detection

Support:

- Exact duplicate.
- Known normalized equivalent.
- Known canonical equivalent.
- Possible duplicate.

When a duplicate is detected:

- Open existing bookmark.
- Add new bookmark anyway.
- Merge metadata when explicitly requested.
- Cancel.

Do not merge user notes or collections silently.

---

# 7. METADATA EXTRACTION

Implement an optional on-device metadata retrieval system.

The minimum guaranteed saved data is:

- URL.
- Host/domain.
- Detected platform.
- Timestamp.
- User-supplied information.

If public metadata is available, attempt to obtain:

- Title.
- Description.
- Site name.
- Thumbnail URL.
- Content type.
- Author where available.
- Canonical URL where reliable.

## Extraction order

1. Data explicitly provided by source sharing intent.
2. User-provided title/description.
3. Public HTML metadata where legally and technically accessible.
4. Open Graph metadata.
5. Twitter/X card HTML metadata when present.
6. Standard HTML title and description.
7. URL/domain fallback.

Do not implement unauthorized scraping, account session reuse, or CAPTCHA bypassing.

## Fetch requirements

- Short request timeout.
- Strict response-size limits.
- Redirect limits.
- MIME checks.
- Safe HTTP handling.
- Cancellation.
- Retry on user request.
- Network error handling.
- Rate limiting for metadata refresh.
- Avoid downloading full media files.
- Avoid fetching internal/private network destinations.
- Block localhost, loopback, link-local, private-network and metadata-service addresses, including after DNS resolution and redirects.
- Use allowlisted HTTP/HTTPS schemes.
- Handle IPv4/IPv6 safely.

Implement SSRF-resistant URL handling.

On Web, respect browser CORS restrictions.

Do not create a backend proxy.

## Thumbnail behavior

If a valid thumbnail can be retrieved:

- Display it.
- Cache a reasonably sized representation when permitted.
- Apply cache-size limits.
- Allow clearing cache.

If thumbnail retrieval fails:

- Show a platform-specific generic placeholder.
- Preserve the bookmark.
- Do not show a broken image indefinitely.

Do not fabricate thumbnails.

For Facebook, Instagram, TikTok, X, and other protected platforms, gracefully accept metadata unavailable.

Provide manual Edit Title and Edit Thumbnail options only using media the user has permission to use.

---

# 8. OPEN ORIGINAL CONTENT

This feature is essential.

Tapping a bookmark must open the original source.

Preferred behavior:

1. Validate URL.
2. Check supported scheme.
3. Delegate the original HTTPS URL to the operating system.
4. Allow compatible Universal Links/App Links to open the installed original app.
5. Fall back to external browser when necessary.

Avoid constructing undocumented deep-link schemes.

Do not assume the originating app is installed.

Use a verified platform URL launcher.

Opening modes:

- System default.
- External browser.
- Original application when supported by normal OS link handling.

Make opening mode configurable where practical.

Do not require embedded WebView browsing.

Do not intercept authentication credentials.

Do not store social network passwords.

If a link is unavailable, let the external platform show its actual result and provide Copy URL, Edit, or Remove Bookmark actions in Handy Bookmark.

Update `lastOpenedAt` and `openedCount` based on attempted opening, not a claim that the user successfully watched or read the content.

---

# 9. COLLECTIONS, SUBCOLLECTIONS, AND TAGS

Implement comprehensive local bookmark organization.

## Collections

- Create.
- Rename.
- Delete.
- Reorder.
- Select icon.
- Select color.
- Optional collection description.
- Nested subcollections.
- Move bookmarks.
- Multi-select operations.

Required default collections:

- Inbox.
- Favorites.
- Archive.

Favorites and Archive may be virtual views rather than physical folders.

Deleting a collection must not silently delete contained bookmarks.

Offer explicit options:

- Move bookmarks to Inbox.
- Move bookmarks to another collection.
- Delete bookmarks with confirmation.

## Tags

- Create.
- Rename.
- Delete.
- Apply multiple tags.
- Filter by tags.
- Bulk tag assignment.
- Tag autocomplete.

Tags must be independent of collections.

## Smart Collections — Pro

Implement rule-based collections using local data.

Example rules:

- Platform = TikTok.
- Platform = YouTube.
- Unread = true.
- Favorite = true.
- Tag contains Recipe.
- Saved within last 30 days.
- Collection = Learning.
- Domain contains github.com.

Support AND/OR rule combinations with a bounded, understandable rule builder.

Smart Collections must dynamically update when data changes.

No AI required.

---

# 10. SEARCH AND FILTER

Implement a fast, local search engine.

Search fields:

- Title.
- URL.
- Description.
- Notes.
- Tags.
- Collection names where appropriate.
- Site/domain.
- Platform.

Filters:

- Platform.
- Content type.
- Collection.
- Tags.
- Favorites.
- Archived.
- Unread.
- Saved date.
- Last opened date.

Sorting:

- Newest saved.
- Oldest saved.
- Recently opened.
- Alphabetical.
- Most opened.
- Manually arranged within collections when applicable.

Implement:

- Search suggestions.
- Recent searches.
- Clear search.
- Search within collection.
- Combined filters.
- Empty state.
- Saved searches for Pro.

Optimize for several thousand or tens of thousands of bookmarks.

Use pagination or virtualized rendering where appropriate.

---

# 11. BOOKMARK PRESENTATION

Provide two primary views.

## Card View

Each bookmark card may contain:

- Thumbnail or fallback graphic.
- Title.
- Domain/platform.
- Description preview.
- Tags.
- Collection indicator.
- Favorite state.
- Unread/read state.
- Save date.

## Compact List View

Optimized for dense browsing.

Show:

- Platform icon.
- Title.
- Domain.
- Save date.
- Bookmark state.

Include switching between views.

On tablets and Windows, support multi-column layouts.

## Detail Screen

Show:

- Title.
- URL.
- Platform.
- Description.
- Note.
- Tags.
- Collection.
- Date saved.
- Open history when available.
- Edit actions.
- Open Original button.

Actions:

- Open.
- Copy URL.
- Share URL.
- Edit.
- Move.
- Favorite.
- Pin.
- Archive.
- Delete.

Never require the user to navigate through several screens just to open a saved link.

---

# 12. HOME SCREEN DESIGN

Use the approved Handy Suite visual language:

**Modern Minimal Utility + Native Feel**

Handy Bookmark accent color: Indigo `#6366F1`.

Mobile Home structure:

### Header

- Handy Bookmark.
- Search.
- Quick Add.
- Settings.
- Optional Pro entry.

### Quick Actions

- Paste & Save.
- Add Link.
- Favorites.
- Recently Saved.

### Main Sections

- Inbox.
- Recently Saved.
- Continue Exploring.
- Collections.
- Pinned Bookmarks.

Do not overcrowd Home.

Make the most common actions accessible within one or two taps.

## Bottom Navigation

Recommended:

- Home.
- Library.
- Collections.
- Focus.

Settings can be accessed from the header rather than taking a permanent tab.

## Windows/Desktop

Adapt to:

- Sidebar.
- Search at top.
- Bookmark list/grid.
- Optional detail panel.
- Context menus.
- Keyboard shortcuts.
- Drag-and-drop URLs.

## Web

Responsive desktop/tablet/mobile layouts.

Do not simply stretch the mobile screen across the entire browser viewport.

---

# 13. FOCUS MODE

Implement a dedicated experience for rediscovering saved bookmarks.

Focus Mode should help users revisit content they intended to view later.

Provide:

- Unread bookmarks queue.
- One bookmark at a time.
- Open original.
- Mark as read.
- Keep unread.
- Archive.
- Favorite.
- Skip.
- Move to collection.

Optional filters:

- All unread.
- Specific collection.
- Platform.
- Random selection.
- Oldest first.

This is not an infinite-scroll social feed.

No AI recommendations are required.

Make Focus Mode fast, distraction-free, and useful.

---

# 14. REMINDERS

Use local notifications where supported.

Allow reminders on a bookmark:

- Later today.
- Tomorrow.
- This weekend.
- Custom date and time.

Support:

- Create.
- Edit.
- Cancel.
- Mark completed.
- Notification permission handling.

The notification should open the relevant bookmark when possible.

Do not depend on remote push servers.

Do not assume exact delivery times across all devices or platforms.

For Web, provide capability detection and an in-app reminders view if notification functionality is unsupported.

Avoid excessive notifications.

---

# 15. BATCH MANAGEMENT

Implement multi-select for bookmarks.

Supported bulk operations:

- Move to collection.
- Add tags.
- Remove tags.
- Mark as read.
- Mark as unread.
- Favorite.
- Archive.
- Delete.
- Export.
- Copy URLs.

Provide:

- Select all in current filtered results.
- Clear selection.
- Confirmation for destructive actions.
- Undo where safe.
- Progress for large operations.

Pro may unlock advanced batch rules and automated organization.

Do not place basic multi-select behind Pro if it harms fundamental usability.

---

# 16. IMPORT AND EXPORT — MANDATORY

Handy Bookmark must support portable user data.

## Import Formats

Implement reliable import for:

- Standard browser bookmark HTML.
- JSON Handy Bookmark backup.
- CSV.
- Plain text URL lists.
- Markdown link lists where parsing is unambiguous.

Where possible, support compatible exports from other bookmark services through documented mappings.

Do not assume third-party proprietary exports are universally compatible.

During import:

- Preview records.
- Detect invalid URLs.
- Detect duplicates.
- Map fields.
- Preserve collections/tags when available.
- Offer conflict strategies.
- Show success/failure counts.

## Export Formats

- JSON.
- CSV.
- HTML browser bookmarks.
- Markdown.
- TXT URL list.
- ZIP portable backup.

ZIP backup should include:

- Bookmarks.
- Collections.
- Tags.
- Notes.
- Smart Collection rules.
- Reminder data when portable.
- Thumbnail cache only when appropriate.
- Manifest with schema version.
- Checksums for integrity.

Provide:

- Full export.
- Selected collection export.
- Filtered bookmark export.
- Selected bookmark export.

Never export private application secrets or advertising identifiers.

## Restore

Validate backup before importing.

Support:

- Merge.
- Replace after explicit confirmation.
- Skip duplicates.
- Conflict preview.
- Recovery on partial failure.

Do not overwrite existing data silently.

Use transactions for database imports.

---

# 17. OFFLINE-FIRST DATABASE

Use local-first storage.

On native platforms, prefer SQLite through a stable cross-platform persistence library already compatible with the Handy monorepo.

On Web, use a compatible browser persistence implementation.

Do not assume browser storage is permanently guaranteed.

Implement:

- Schema migrations.
- Database indexes.
- Search optimization.
- Transactions.
- Backup.
- Restore.
- Corruption handling.
- Database integrity checks.
- Cache cleanup.

Do not introduce cloud sync.

Manual backup and restore are sufficient for the initial release.

Document clearly that separate installations do not automatically synchronize.

---

# 18. MONETIZATION

Use the approved Handy Suite model:

**Free + Ads + Pro Lifetime**

No subscription.

No mandatory registration.

## Free

Include:

- Unlimited basic bookmark saving.
- Collections.
- Tags.
- Search.
- Open original link.
- Favorites.
- Basic import/export.
- Notes.
- Focus Mode.
- Basic duplicate detection.

Do not limit total bookmarks merely to force purchases.

## Pro Lifetime

Suggested Pro features:

- Remove ads.
- Smart Collections.
- Advanced batch operations.
- Saved searches.
- Advanced organization rules.
- Enhanced import/export options.
- Customizable layouts and themes.
- Advanced bookmark filtering presets.

Do not claim Pro requires recurring cloud processing.

## Platform rules

### Android

- AdMob where supported.
- Google Play Billing for a non-consumable Pro Lifetime entitlement.

### iOS

- AdMob.
- Apple StoreKit non-consumable purchase.

### Windows

- Microsoft Store compatible purchase implementation when verified.
- Do not assume Android AdMob works on Windows.

### Web

- Free functionality must work without a payment backend.
- No insecure client-side fake purchase verification.
- Clearly document payment limitations if no secure purchase method is available.

A Pro purchase on one store is not automatically valid on other stores without a supported cross-store entitlement system.

## Ads placement

Allowed:

- Non-intrusive placement in the main application.
- Appropriate sections of library browsing.
- Clearly labeled advertising surfaces.

Do not show ads:

- In iOS Share Extension.
- During Quick Save.
- In critical confirmation dialogs.
- Over navigation buttons.
- While the user is opening a bookmark.
- In notifications.

Never force an interstitial ad before opening an original link.

---

# 19. PRIVACY AND SECURITY

Bookmarks can contain private links and sensitive URL parameters.

Treat all saved URLs as private user data.

Mandatory rules:

- No account required.
- No custom backend.
- No telemetry containing bookmark URLs.
- No advertising event payload containing private link contents.
- No unauthorized scraping.
- No third-party login token harvesting.
- No hidden clipboard monitoring.
- No uploading the bookmark database.
- No automatically sharing collections publicly.
- No storing social media session cookies.

Optional app lock:

- Device biometrics where supported.
- Local authentication fallback when appropriate.

Protect sensitive local data using platform-supported security where practical.

Metadata fetching sends the target URL to the target website. Explain this behavior and provide an option to disable automatic metadata fetching.

Never fetch private network URLs from untrusted bookmark input.

Avoid opening dangerous schemes such as `javascript:` or `file:` supplied by untrusted external content.

Provide a warning before opening suspicious URLs based on transparent local heuristics.

Do not claim comprehensive malware/phishing detection without a real detection service.

Provide user controls for:

- Clear metadata cache.
- Clear search history.
- Delete all bookmarks.
- Export all data.
- Reset app.

Implement a Privacy Policy screen and store-ready privacy disclosures.

---

# 20. ERROR HANDLING

Handle:

- Invalid URL.
- Empty share content.
- Multiple URLs.
- Unsupported scheme.
- Duplicate links.
- Failed metadata retrieval.
- No Internet.
- Timeout.
- Deleted post.
- Private post.
- Redirect failure.
- Missing thumbnail.
- Database error.
- Storage full.
- Permission denied.
- Corrupted import.
- Failed backup.
- Application restart during import.
- Large bookmark library.
- Browser storage limitations.
- Expired external link.

No bookmark should disappear because metadata extraction failed.

Use reliable local persistence before optional operations.

---

# 21. PERFORMANCE

The application must remain responsive with large bookmark collections.

Optimization requirements:

- Lazy loading.
- Paginated queries.
- Efficient indexes.
- Thumbnail caching.
- Bounded cache size.
- Background metadata queue where lifecycle permits.
- Controlled network concurrency.
- Debounced search.
- Virtualized lists.
- Avoid unnecessary widget rebuilds.
- Avoid downloading full videos/images.
- Avoid expensive computation in the UI isolate.

Provide performance tests using sample databases with:

- 100 bookmarks.
- 1,000 bookmarks.
- 10,000 bookmarks.
- 50,000 bookmarks.

Measure startup, search latency, scrolling smoothness, memory and import/export performance on available environments.

Do not claim exact performance guarantees without measurement.

---

# 22. LOCALIZATION AND ACCESSIBILITY

Support:

- English.
- Vietnamese.

All user-facing strings must be localized.

Support:

- Dynamic text scaling.
- Dark mode.
- Screen readers.
- Keyboard navigation.
- Accessible labels.
- Reduced motion.
- Appropriate touch targets.
- High contrast.
- Responsive layouts.

Date and time formatting must respect user locale and timezone.

---

# 23. TESTING STRATEGY

Implement comprehensive automated tests.

## Unit Tests

- URL extraction.
- URL normalization.
- Platform detection.
- Short-link handling.
- Duplicate detection.
- Collection rules.
- Search filters.
- Bookmark state updates.
- Import parsing.
- Export serialization.
- Backup integrity.

## Widget Tests

- Home.
- Add Bookmark.
- Quick Save.
- Bookmark detail.
- Collections.
- Search.
- Focus Mode.
- Settings.
- Pro screen.

## Integration Tests

- Android share receiving.
- iOS Share Extension.
- Clipboard Quick Save.
- Database persistence.
- Import/export round-trip.
- Reminder scheduling.
- External URL launching.
- Cold start share.
- Warm start share.
- Large dataset handling.

## Required Real-World Share Tests

Test where devices and installed apps are available:

- Facebook Reel.
- Facebook post.
- Instagram Reel.
- Instagram post.
- TikTok video.
- YouTube Short.
- YouTube video.
- X post.
- Reddit post.
- Browser webpage.

Test both successful native sharing and Copy Link fallback.

Do not mark these as verified unless actual tests were executed.

## External App Opening

Verify that:

- Links open with normal OS handling.
- Installed app behavior is correct where supported.
- Browser fallback works.
- Failed launch is handled.
- No unsupported private deep-link assumptions exist.

---

# 24. RELEASE PREPARATION

Prepare independently deployable builds for:

- Android App Bundle.
- iOS App Store.
- Windows MSIX / Microsoft Store.
- Flutter Web / PWA.

Each platform needs:

- Appropriate icon.
- App name.
- Package identifier.
- Version metadata.
- Permissions.
- Privacy disclosures.
- Release configuration.
- Localization.
- Appropriate monetization configuration.

Use the existing Handy Suite CI/CD patterns.

Do not embed production store credentials.

Prepare store descriptions and screenshots using real application screens, not misleading fabricated interface imagery.

Do not submit an app to stores without explicit authorization.

---

# 25. DOCUMENTATION

Create or update:

- `docs/HANDY_BOOKMARK_SPEC.md`
- `docs/HANDY_BOOKMARK_ARCHITECTURE.md`
- `docs/HANDY_BOOKMARK_FEATURE_MATRIX.md`
- `docs/HANDY_BOOKMARK_PLATFORM_SUPPORT.md`
- `docs/HANDY_BOOKMARK_SHARE_INTEGRATION.md`
- `docs/HANDY_BOOKMARK_DATABASE_SCHEMA.md`
- `docs/HANDY_BOOKMARK_IMPORT_EXPORT.md`
- `docs/HANDY_BOOKMARK_TEST_PLAN.md`
- `docs/HANDY_BOOKMARK_KNOWN_LIMITATIONS.md`
- `docs/HANDY_BOOKMARK_RELEASE_CHECKLIST.md`

Every feature must have a status:

- NOT_STARTED
- IN_PROGRESS
- IMPLEMENTED
- UNIT_TESTED
- INTEGRATION_TESTED
- PLATFORM_VERIFIED
- BLOCKED

Never mark a native feature as platform-verified without running it on that platform.

---

# 26. IMPLEMENTATION PHASES

Execute work in the following order.

## Phase 0 — Repository Inspection

Inspect existing Handy Suite code and shared modules.

Identify reusable infrastructure.

Choose compatible Flutter dependencies.

## Phase 1 — Core Application

Implement:

- App shell.
- Themes.
- Routing.
- Localization.
- Local database.
- Bookmark CRUD.
- Collections.
- Tags.
- Search.
- Favorites.
- Archive.

Verify these capabilities offline.

## Phase 2 — Native Quick Save

Implement:

- Android Share Target.
- iOS Share Extension.
- Clipboard Quick Save.
- Inbox automatic saving.
- Duplicate protection.
- External link opening.

This phase has the highest priority for product differentiation.

## Phase 3 — Metadata and Organization

Implement:

- Platform recognition.
- Optional metadata extraction.
- Thumbnails.
- Batch operations.
- Filters.
- Smart Collections.
- Focus Mode.

## Phase 4 — Portability

Implement:

- HTML import/export.
- CSV.
- JSON.
- Markdown.
- ZIP backup.
- Restore validation.
- Web browser storage support.

## Phase 5 — Monetization

Integrate:

- AdMob on supported mobile platforms.
- Pro Lifetime purchases.
- Restore purchase.
- Platform-specific monetization capability checks.

## Phase 6 — QA and Release

Run:

- Static analysis.
- Unit tests.
- Widget tests.
- Integration tests.
- Platform builds.
- Performance tests.
- Native share tests.
- Import/export round-trip tests.

Verify Android, iOS, Windows, and Web independently.

---

# 27. DEFINITION OF DONE

Handy Bookmark is complete only when:

1. Users can save a normal URL.
2. Users can save shared links from compatible apps.
3. Clipboard fallback works where supported.
4. Bookmarks remain saved after app restart.
5. Collections and tags work.
6. Search returns correct results.
7. Bookmark cards display valid available metadata.
8. Missing metadata does not break saving.
9. Opening original URLs works.
10. Duplicate protection works.
11. Import and export work.
12. Backup and restore work.
13. User data remains local.
14. Basic functionality works offline.
15. Ads and purchases are integrated where supported.
16. UI is responsive and accessible.
17. All implemented features have tests.
18. Platform-specific limitations are documented.
19. No fake buttons or placeholder functionality remain in release builds.
20. No release-blocking bugs remain on the intended release platform.

---

# 28. AGENT AUTONOMY AND SAFETY

You may:

- Inspect code.
- Modify existing files.
- Create the Handy Bookmark app.
- Add necessary packages.
- Implement native integrations.
- Create tests.
- Refactor shared packages carefully.
- Build and analyze the project.

Do not:

- Delete other Handy applications.
- Rewrite unrelated application functionality.
- Change published bundle identifiers without authorization.
- Delete user data.
- Introduce a backend.
- Introduce subscription payments.
- Add cloud AI.
- Bypass platform security.
- Claim unsupported functionality works.
- Fabricate test results.
- Submit releases without authorization.

Make implementation decisions autonomously when they are safe and consistent with the requirements.

If a dependency does not support all four platforms, implement an appropriate platform adapter or clearly document the limitation.

Do not reduce Android/iOS functionality merely to force uniformity with browser limitations.

Use production-quality code and maintain repository consistency.

---

# 29. START IMPLEMENTATION NOW

Begin by inspecting the existing Handy Suite Flutter monorepo.

Do not stop after generating an architecture document.

Create the complete Handy Bookmark application and integrate it into the repository.

Prioritize **Quick Save from external applications**, especially Facebook Reels, TikTok, Instagram, YouTube, and X.

The highest-value user journey is:

**See interesting content → Share to Handy Bookmark → Automatically save to Inbox → Find it later → Open in the original application.**

The app must be useful even with no Internet connection and even when external metadata cannot be retrieved.

Make bookmark creation fast, reliable, and privacy-conscious.

After each phase, run appropriate tests and record results. Continue implementing within the active session, and preserve clear progress notes for any subsequent session.

The final deliverable should be a genuinely functional, polished, maintainable Handy Bookmark application for Android, iOS, Windows, and Web, with the capabilities and limitations of each platform documented accurately.

**Implement real production code, not only specifications or demonstrations.**
