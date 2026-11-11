# Handy Habit: website kit

Everything the studio repo (`winka-studio`, site winka.top) needs to build Handy Habit's **product page, Privacy Policy page, Terms page** (and the data-deletion and support pages the Play guide asks for), the same way as Handy Boards and Handy Bookmark. Same layout as `Handy-Website-Kit/handy-boards`.

## Facts

- App: **Handy Habit**, slug `handy-habit`, Android package `com.apps.winka.handyhabit`, version 1.0.0 (build 5), Google Play **closed testing** (draft). Android only; no iOS, Windows or web.
- Maker: Winka Studio · contact apps.winka.studio@gmail.com · category Productivity.
- Languages: English, Vietnamese. Light and dark.
- Price: free; optional one-time Pro (no subscription). Owner-reported 99,000 VND; confirm before printing a figure. Ads are not enabled in this version.
- URLs the app and Play Console already use (they must exist before the owner submits for review):
  - `https://winka.top/{en|vi}/apps/handy-habit/privacy/`
  - `https://winka.top/{en|vi}/apps/handy-habit/terms/`
  - `https://winka.top/{en|vi}/apps/handy-habit/data-deletion/`
  - `https://winka.top/{en|vi}/support/handy-habit/`
  - product page `https://winka.top/{en|vi}/apps/handy-habit/`

## Folder

| Path | What |
|---|---|
| `legal/privacy.{md,html}`, `terms.{md,html}` | Final bilingual legal text (EN section, then VI). Use word for word; do not paraphrase. Source of truth: `apps/handy_habit/PRIVACY.md`, `TERMS.md`. |
| `copy/{en,vi}/` | features, highlights (six landing blocks), taglines (hero, SEO), faq (+ `faq.jsonld`), press, store-listing |
| `copy/pro-vs-free.md`, `platforms-and-links.md`, `changelog.md`, `why-handy-habit.md` | Bilingual tables and links |
| `brand/` | `brand.md`, `colors.json`, `icon/`, `favicon/`, `feature-graphic/`, `social/` (OG 1200x630 and square, EN/VI), `fonts/` (Nunito, OFL) |
| `screenshots/{mobile,desktop}/` | 184 PNGs `<form>[-dark]-<lang>-<NN>-<scene>.png`; mobile 1170x2532, desktop 2880x1800 |
| `highlights/` | 40 phone-framed transparent PNGs (10 scenes, light/dark, EN/VI) for hero and feature blocks |
| `store-listing/` | Play screenshots (7 per language) and the 512 icon |
| `data/captions.json` | alt text EN/VI for every screenshot, with `pro`, `theme`, `lang` flags |
| `data/sample-data.md` | What the demo data is |

No `clips/` and no tablet shots exist yet; do not link them.

## Ground rules

1. Never invent reviews, ratings, user counts, awards, press quotes or customer logos.
2. Android only. Store button stays "Coming soon" until the owner says otherwise; link the Play URL only for testers.
3. Screenshots are host renders of the real UI with demo data (fixed date Mon 2 Nov 2026), not device captures. Scenes `30-pro` and `31-studio` show Pro; say "Pro" near them. Widgets (`23-widgets`) are in-app previews, not a launcher.
4. Nothing about Habit is collected or sent to the developer. Drive sync is optional, goes to the user's own Drive and is not end-to-end encrypted; say so exactly as the legal text does.
5. Mood and notes never appear in widgets or notifications.
6. Tone: short, kind, plain. Never "streak lost", "failed", "you missed". A missed day is a hollow bead.
7. Dark and light images should follow the site theme (`*-dark-*` files); localise by `en`/`vi`.
8. `store-listing.md` was updated 2026-11-11 (widgets, sharing); Play shows it after the next metadata upload.

## Regenerating

From `apps/handy_habit`: `KIT_DIR=../../website-kit/handy-habit/screenshots flutter test --no-pub --timeout 900s tool/website_shots_test.dart` (the Pro page crop and the brand/highlight composites are post-processing, so ask before regenerating).
