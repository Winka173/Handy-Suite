# Handy Bookmark: visual design

Written 2026-11-06 with `design-taste-frontend` (app-screen run) and `frontend-ui-engineering`.
The app keeps the brand fixed in `lib/design/identity.dart` (`bookmarkIdentity`): Newsreader
titles over Geist text, paper ground `#FAF8F3`, ink rules under headings (`HandyHeading.rule`),
open rows between hairlines, tight corners (2 px cards, 4 px controls), one hue `#0E7490`.

## The face: clippings on a front page

Every saved thing can be drawn as a newspaper clipping: its title in the title face over an ink
rule, its source in words below. The first-run guide is built from clippings
(`ONBOARDING_FLOW.md`), and collection covers set titles the same way when an item has no
picture, so a collection of plain links still has a cover that says what is in it. Sources are
words, never logos; pictures are the person's own (image items, chosen pictures) or fetched page
pictures when they turned page reading on.

## Home (phone, under 700 px)

Question: "What have I kept, and where does the new stuff go?"

1. Top bar: the name and Settings.
2. Search: "Find a link or picture". Under it, **All · Links · Pictures** with counts, shown
   only once the library holds both kinds. Choosing Links or Pictures turns the home into
   results, like typing does.
3. Share problems and link-check notices, when there are any.
4. **Not sorted** strip (the signature element): new saves as cards with the usual
   collections one tap away.
5. **Collections as covers**: a grid (2 columns on phones, up to 5 on wide panes; 180 px per
   column) of every collection in tree order. A cover is a mosaic of the collection's newest
   three items (pictures first; an item without a picture is its title set in Newsreader on a
   raised paper tint), then its colour dot and name, then "Parent · 3 links · 2 pictures".
   Tap opens it, long-press edits it, + makes a new one. Empty collections say so on the cover.
6. Places: Not sorted, All, Favourites, Not read yet, Archive, Focus, Recently Deleted, saved
   filters, tags.
7. One **Save** button across the bottom bar. Its sheet holds a link field, Paste a link,
   Several links, A picture, and on phones "Save from other apps with Share" (opens the guide).

## Wide (700 px and up)

The sidebar of places, the list, and on 1100 px+ the detail column stay as before; the three
add icons in the top bar are now the same single **Save** button and sheet. Keyboard: Ctrl/⌘ V
pastes, Ctrl/⌘ N adds, Ctrl/⌘ F searches, Esc clears the selection.

## Rejected

Coloured icon tiles per collection, a hero banner or greeting, a feature carousel, gradients,
shadows on resting cards, letter-in-a-box placeholders on covers, a floating action button
competing with the bottom bar, violet or indigo.

## States

- No collections: one sentence with examples under the Collections heading.
- Collection with nothing in it: the cover says "Empty".
- No pictures in the library: the kind chips are hidden.
- Kind filter with no match: the results view's empty state with Clear filters.
- Large text: covers keep their 4:3 picture and cut the name to one line; the grid stays
  two columns down to 320 px.

## Checked

Widget tests: `test/home_test.dart` (kind chips narrow and restore, hidden without pictures,
covers open their collection, the Save sheet holds every way to add) and the existing suite.
Screens rendered with `tool/screens_test.dart` (phone, tablet, desktop) and reviewed; not run
on a device.
