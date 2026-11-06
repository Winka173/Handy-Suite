# Handy Bookmark: visual design (Warm Modern Library)

Written 2026-11-06. This replaces the "clippings on a front page" direction: square 2 px cards, ink
rules above every section, and a serif on every title. Next to the first-run guide that direction
read as an older, different product. The owner asked for the app to match the guide: warm,
image-first, softly rounded and uncluttered.

The guide (`lib/welcome/`, `ONBOARDING_FLOW.md`) is unchanged. The app now continues it: the same
teal, the same warm paper ground, the same 16 px floating cards and the same photographs.

## Contract

- **Job:** keep things found anywhere (links, screenshots, photos) and get them back by sight.
- **The question on home:** "What did I save, where is it, and how do I save more?"
- **The finding:** how many saves still have no place ("4 not sorted yet"), next to the one
  action that fixes it ("Put in…").
- **Primary action:** Save, a single full-width button at the foot of the home.
- **Signature element:** the "Recently saved" shelf, with the person's own pictures large. Saves
  without a collection come first with one "Put in…" button.
- **Patterns rejected:**
  - ink rules above sections;
  - chip clouds on every card;
  - 1 px outlines around every row;
  - serif in controls and lists;
  - pure-black dark theme;
  - flat geometric picture stand-ins;
  - a different look after onboarding.

## Tokens (`apps/handy_bookmark/lib/design/theme.dart`)

| Role                | Light     | Dark      | Use                                       |
| ------------------- | --------- | --------- | ----------------------------------------- |
| canvas              | `#F6F4EE` | `#171D1C` | page ground (warm ivory / warm charcoal)  |
| surface             | `#FFFFFF` | `#222A29` | cards, sheets, dialogs                    |
| raised              | `#EFEDE6` | `#2B3432` | chips, quiet fills                        |
| primary             | `#0E7490` | `#7CC8D8` | the one action, links, selection          |
| pressed / tint      | `#0B5A70` / `#D9EEF2` | `#9AD6E3` / `#21424A` | pressed state; selected fill, "Put in…" |
| ink / muted         | `#1C2627` / `#5B6767` | `#EEF2EF` / `#B0BEBA` | text (muted holds 4.5:1 on canvas and surface) |
| line / control      | `#E3E2DA` / `#C9CCC4` | `#34403E` / `#4A5856` | rare dividers; field and switch edges |
| sage / warm         | `#557A66` / `#C97A5B` | `#9CC2AC` / `#E2A188` | categorisation; the favourite star |
| danger / warning    | `#B03A36` / `#8A5A14` | `#F0A29C` / `#E8C07A` | with their pale tints, for notices only |

The app keeps its own teal `#0E7490` (from `docs/UX_REDESIGN.md`, and the guide's). The supplement
proposed `#176F6B` as a starting point. It was not taken: it would have put the app and the guide
in two different teals.

**Shapes** (`BookmarkRadii`). Larger surfaces get rounder corners:

| Thing                      | Radius |
| -------------------------- | ------ |
| sheet                      | 26     |
| dialog, Focus card         | 22     |
| collection cover           | 20     |
| item card                  | 16     |
| field, button              | 14     |
| list thumbnail             | 12     |
| chip and search            | pill   |
| icon actions               | round  |

**Type.**
- Geist for all the work: section titles 19/600, item titles 14–15.5/600, meta 12.5 muted.
- Newsreader only for editorial moments: the library's name (28), a collection's name (26),
  empty-state headlines, and the guide.

**Surfaces** part by tone: white on ivory, or a lighter charcoal on charcoal. Only things that
float get a shadow: sheets, menus, the empty-state photo stack. Dividers appear only inside a
grouped list.

**Pictures.** A save shows its stored preview. Without one it shows a `SourceFace`: a pale field of
its source's identity colour, the content type's icon (play for video, bag for a shop item, pin for
a place), and the source's name. Never a fake photograph. Only previews are decoded in lists.

## Screens

- **Home (phone):**
  - library name (serif), dateline, pill search;
  - "Recently saved" shelf (168 px picture cards; unsorted first, each with "Put in…" opening a
    sheet of the usual collections, then "Another collection…"; sorted ones show their collection);
  - collections as 20 px covers made of their pictures, an empty collection as its colour and a
    folder;
  - places; Save at the foot.
  - Empty library: the guide's three photos stacked, "Save something worth keeping", Save, and
    "See how saving works".
- **Results / collection:**
  - a collection opens with its newest picture beside its name (serif) and the count;
  - tools (filter, view, more) share the row on wide screens and sit under the name on phones;
  - a search says "n found", not the place's total.
  - Gallery: two cards a row at 390 px, one at 320 px or large text, 1.28 photos, two-line title,
    one source line, a "…" button for details.
  - List: 60 px thumbnails, titles bolder when unread, rows grouped on one rounded surface.
- **Wide (700 px and up):**
  - serif library name in the bar; places on the canvas;
  - no vertical rules; the open item sits on its own rounded raised sheet.

## States

Empty library, empty collection, all sorted ("All sorted"), no-match search ("0 found"), no picture
(source face), unreadable picture (source face), loading (progress bar), list error (notice with
Try again), large text (cards go to one column; the shelf grows), 320 px (tools wrap under the
title).

## Checked

- Rendered and reviewed, light and dark:
  - home and collection at 320, 390, 900 and 1440 px;
  - home and collection at 200 % text;
  - search with matches and with none.
- The review shots use the guide's licensed photos as fixture pictures and leave the other saves
  without pictures, so both faces are seen. These are host renders, not device evidence.
