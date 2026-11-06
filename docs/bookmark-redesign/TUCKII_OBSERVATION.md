# Tuckii: what was observed and what was only read

Status (2026-11-06): **NOT DIRECTLY OBSERVED yet.** No device here has Google Play and no
Mac/iPhone is available; the owner is preparing BlueStacks with Play so the real first run
can be watched over adb. Until then this file records public sources only. Nothing below
describes Tuckii's onboarding pages, because no source shows them.

Sources read on 2026-11-06:

- https://tuckii.app/ (read as text)
- App Store (VN storefront), id6776568114 (read as text; version history 1.3.1 → 1.7.1)
- Google Play `com.myCku.tuckii`: **not readable** without JavaScript; no data taken from it.

| Behaviour | Evidence | User benefit | Handy Bookmark now | Handy adaptation | Status |
| --- | --- | --- | --- | --- | --- |
| Share from any app, links and screenshots | Site and store text | One gesture to keep anything | Android/iOS share for text and links; pictures added in-app | Android image share (`ACTION_SEND` / `SEND_MULTIPLE image/*`) into the same durable queue | Links: existing. Images in app: done. Android image share: CODE ONLY + unit tests (APK compiles; not run on a device). iOS: BLOCKED (no Mac) |
| Screenshots with a name or note so search finds them | Site text; store 1.3.1 notes | Pictures are findable | Image items with title from file name, search by title, note and file name, accents ignored | Same, plus All / Links / Images filter | Done (engine, stores) |
| Collections incl. Unsorted, sub-collections (Pro) | Site, store | Light organisation | Collections with parents, Not sorted inbox (free) | Visual covers from real pictures; nesting stays free | Covers: Phase 3 |
| One search box, filter links / images / pinned | Site | Find fast | Search over all fields; kind filter in engine and stores | Filter chips in the redesigned search | UI: Phase 2 |
| Focus as a swipe deck of unseen saves | Site, store 1.4.0 | Clear the backlog | Focus with buttons, one link at a time | Original 2D swipe deck with labelled actions, buttons kept, Undo | Phase 3 |
| Gentle reminders "your saves are waiting" | Site | Come back to saves | Per-link reminders | Opt-in weekly revisit, quiet hours | Phase 3 |
| Import from Pocket, Raindrop, browsers, CSV/HTML/JSON | Site | Easy switch | Pocket, browsers, six formats | Raindrop CSV/HTML importer | Phase 3 |
| Sync via the person's own iCloud / Google Drive (Pro) | Site, store 1.5.0 | Devices agree | None | Approved; built on tombstones and revisions now in the data model | Phase 4 |
| Backup / export JSON | Store | Data ownership | JSON and ZIP (ZIP with pictures), free | Kept free | Done |
| "Smoother first run" | Store 1.4.0 notes only | Quick start | Empty-state hint only | Original interactive guide that teaches a real first save | Phase 2, after observation |
| No account, no ads | Site, store | Trust | No account; ads removed 2026-11-06 | Same | Done |
| Link previews: "the app sends each saved link's URL to our preview service" | Site disclosure | Previews without setup | Page info is opt-in and fetched directly from the site, never through a third-party service | Keep: no URL leaves the device unless the person turns page reading on | Kept (difference on purpose) |
| Pricing: monthly, yearly or lifetime Pro; limited free images | Store, site | — | Lifetime only | No subscriptions; no picture cap in Free | Decided |

Nothing from Tuckii (name, mascot, art, wording, screen composition) is used in Handy
Bookmark. The table guides behaviour only.
