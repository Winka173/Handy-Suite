# Handy Card — product spec

Design anything, share anywhere. An offline card studio for business cards,
portfolio and creator cards, event badges, shop cards and fully custom
designs. A card is not assumed to be a business contact: any design can be
made from a blank canvas.

## Principles

- **The editor is the product.** The canvas is a layered, freeform editor
  (select, move, resize, rotate, group, layer, undo); forms only inspect it.
- **Local-first.** No account, backend, cloud database, AI service or
  subscription. Designs, profiles and pictures stay on the device.
- **Three separate systems.** Identity and contacts (profiles), the design
  document (scene graph), export and delivery (renderers and adapters). A
  saved design is the scene graph, never a screenshot.

## Users and jobs

| Job                                         | Where                                     |
| ------------------------------------------- | ----------------------------------------- |
| Make a two-sided business card from scratch | New design → Studio                       |
| Start from a layout and change it           | Home → Start from a layout                |
| Keep one identity in many cards             | Profiles, live bindings                   |
| Hand the card to a printer                  | Export → PDF (bleed, crop marks)          |
| Print at home                               | Export → Print sheet (A4/Letter)          |
| Share a contact                             | Export → vCard, contact QR                |
| A profile page or email signature           | Export → Profile page, Signature          |
| Move to another device                      | Settings → Backup, Home → Add from a file |

## Scope of this release (statuses in `HANDY_CARD_TEST_MATRIX.md`)

Built: the editor (all tools below), 11 original templates (wedding and
party invitations and a one-page CV added 2026-11-03), 10 size presets (A5
and A4 included)
plus custom sizes, profiles with live/snapshot bindings, PNG, JPEG, SVG, PDF,
print sheet, vCard 3.0/4.0, contact QR, HTML profile page, email signature,
portable project ZIP backup and restore, user templates, Vietnamese and
English, light and dark.

Engine only (no screen yet): batch rows from CSV (`batchRows`); the batch
wizard is not built.

Not started: NFC writing, Apple/Google Wallet passes, brand kits (palettes,
logo sets), XLSX import, SVG import, custom font import. None of these is
offered in the interface.

## Free and Pro

Everything above is free in this build: no store product exists yet, so a
Pro gate would lock it for everyone (see `docs/STORE_SETUP.md`). Planned Pro
when products exist: the batch generator, print sheets, the HTML profile
page and email signature, SVG export. Creating, editing, saving, PNG/JPEG
export, vCard/QR and backup/restore stay free. Ads never appear in the
studio or the export sheet (the studio turns the banner off while open).
