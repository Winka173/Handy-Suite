# Handy Bookmark: the first-run guide

Contract written 2026-11-06, before code, following `design-taste-frontend`
(`references/app-screens.md`) and `frontend-ui-engineering`. What was learned from Tuckii is in
`TUCKII_OBSERVATION.md`; nothing of its look or wording is used.

## Inventory (data and jobs)

- **Who:** one person who has just installed the app, on a phone (Android or iPhone), sometimes
  on Windows or the web. They give a first run about a minute.
- **What they have:** nothing yet (0 items, 0 collections), or, when replaying from Settings, a
  library of 50–3,000 links.
- **What they will save:** links shared from TikTok, YouTube, Facebook, Shopee, Zalo and the
  browser; screenshots and photos; a link copied to the clipboard.
- **The jobs, in order:** learn the one gesture that matters (Share → Handy Bookmark); make a
  first save that **stays**; know where it went (Not sorted); optionally give it a place.
  Switchers: bring links from another app (import).
- **The product's own things:** the newspaper ledger face (Newsreader titles, paper ground
  `#FAF8F3`, ink rules), the hue `#0E7490`, the **Not sorted strip** (the app's signature
  element), sources written as words, never logos.

## The question and the finding

- Question: "How do I keep things here, and where do they go?"
- Finding, shown on the last step: "Your first save is waiting in Not sorted."

## Face and signature

- Face: **the clipping.** Every saved thing in the guide is a newspaper clipping: a headline
  in Newsreader, a source line under an ink rule ("TikTok · 3 weeks ago"). The guide opens
  with today's real date as a dateline, like a front page.
- Signature: the person's **real** first save becomes a clipping that drops into the Not
  sorted strip, and filing it slides it under a collection's name.

## Flow

A single route `/welcome` with four steps and a four-segment progress line ("Step 2 of 4"
for screen readers). Skip is in the top bar on every step.

1. **Keep it once. Find it again.** Four sample clippings (a recipe from TikTok, running shoes
   on Shopee, a guitar lesson on YouTube, a train timetable screenshot) lie scattered, then
   settle into one ledger column. One sentence: links from any app and screenshots, kept
   together on this device. Primary **Show me how**; secondary **I have links in another
   app** (opens import).
2. **Save from any app.** A drawn share row (Copy link · Messages · Handy Bookmark, ours
   ringed in the hue) and a clipping sliding from it into a small Not sorted tray. The
   sentence depends on the platform: Android "Tap Share, then Handy Bookmark"; iOS adds
   "if it isn't in the row, look under More"; Windows and web "Copy a link anywhere, then
   press Ctrl V here" with key caps instead of the share row. Primary **Try it now**.
3. **Save your first one.** Real controls: a link field with Save, **Paste** (reads the
   clipboard only when tapped), **Choose a picture**. On Android and iOS a quiet line: "Or
   share from another app now; this page will notice." The step watches the library: the
   first item that was not there when the step opened (pasted, picked or shared) moves the
   guide to step 4 with that item. Secondary **Later**.
4. **Saved. It's in Not sorted.** The person's item as a clipping (its picture when it has
   one, its title, source · domain) at the head of a Not sorted strip. One sentence:
   everything lands here first; give it a place now or whenever you like. Chips: the
   person's usual collections, or four suggestions (Recipes, To buy, Read later, Trips) that
   create the collection on tap and file the item; the clipping slides under the chosen
   name and the line reads "Filed in Recipes". Primary **Go to my library**.

Finishing, skipping or leaving marks the guide done (`guideDone` in the library's
preferences, so a restored backup does not show it again). Settings → Help → **How to save**
replays it.

## When it shows

On start, only when the library has no items and nothing in Recently Deleted, and the guide
was never finished. A person who upgrades with links never sees it unasked.

## States

- Saving fails: the existing "Not saved … Nothing changed." message; the step stays.
- Link already saved: the duplicate dialog as usual; choosing the old link counts as the
  first save and goes to step 4 with it.
- Picture already saved: "This picture is already saved." and the step stays.
- A share that could not be read: the Not sorted issues line appears on step 3.
- Web: no share line; pictures through the browser's file picker.
- Filing fails: the chip stays unselected and the message says nothing changed.
- Large text (200 %): every step scrolls; the illustration shrinks first; buttons never clip.

## Layout (320–1440)

- Under 700 px: one column. Progress and Skip on top, illustration (max 280 px tall, 200 px
  at 320 px wide), title, sentence, then the actions in the bottom bar.
- 700 px and wider: content centred at most 1040 px; text and actions on the left (max
  440 px), illustration on the right, both top-aligned to the title's line.
- Margins 16 px on phones, 24 px from 700 px.

## Platform behaviour

- Android back and Esc: previous step; on step 1 they leave (marked done).
- Enter on desktop: the step's primary action (not while typing in the link field, where
  Enter saves the link).
- iOS swipe back leaves the route (marked done); the home is underneath.
- Web URL `#/welcome`; replay works by URL too.
- A light haptic tick when the first save lands (phones only).

## Motion (continuity only, zero under reduced motion)

- Step 1: the pile settles into the column (stagger 70 ms, 520 ms each, ease-out).
- Step 2: one clipping slides from the share row into the tray, once.
- Step 4: the clipping drops into the strip (320 ms); filing slides it under the name.
- Between steps: `HandySwap`. Buttons are visible and active from the first frame; nothing
  waits for an animation.

## Accessibility

- Each step's title is a header in semantics; the progress line reads "Step n of 4".
- The illustrations are decorative and excluded from semantics, except the person's own
  clipping on step 4, which reads its title and source.
- All controls are 44 px or taller, keyboard-reachable in reading order; focus moves to the
  title when the step changes.
- Contrast 4.5:1 for every word, including the clipping's source line.

## Rejected

A mascot; sticker outlines and hard offset shadows; marker highlights under words; a carousel
of feature slides with dots; a paywall or Pro mention; asking for notifications (no revisit
reminder exists yet); a practice that throws away what the person did; a demo hand cursor;
Skip hidden on early screens; buttons held back until an animation ends; confetti or a
full-screen tick.
