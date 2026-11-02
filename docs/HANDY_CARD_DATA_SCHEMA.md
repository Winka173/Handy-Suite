# Handy Card — data schema

## Design document (schema 1)

```json
{
  "schema": 1,
  "id": "a1b2c3…",
  "name": "Minimal",
  "kind": "business | portfolio | social | event | brand | invitation | document | custom",
  "unit": "mm | in | px | pt",
  "width": 255.118,
  "height": 153.071,
  "bleed": 8.504,
  "safe": 8.504,
  "profileId": "p1",
  "createdAt": "2026-11-02T09:00:00.000Z",
  "updatedAt": "…",
  "assets": [
    {
      "id": "<sha256>",
      "mime": "image/png",
      "width": 800,
      "height": 600,
      "size": 12345,
      "name": "logo.png"
    }
  ],
  "pages": [
    {
      "id": "…",
      "name": "Front",
      "background": "FFFFFF",
      "elements": [
        {
          "id": "…",
          "type": "text",
          "name": "",
          "frame": { "x": 17, "y": 22, "w": 200, "h": 24, "r": 0 },
          "opacity": 1,
          "visible": true,
          "locked": false,
          "props": {
            "text": "…",
            "font": "sans",
            "size": 15,
            "weight": 600,
            "color": "111111",
            "align": "left",
            "lineHeight": 1.25,
            "letterSpacing": 0,
            "upper": false,
            "italic": false,
            "overflow": "shrink"
          },
          "binding": { "field": "name", "mode": "live" },
          "children": []
        }
      ]
    }
  ]
}
```

All lengths are points. Colours are `RRGGBB` or `AARRGGBB`. Unknown keys at
document, page and element level are preserved.

Limits (checked on every read): 50 sides, 5,000 elements, group depth 16,
text 10,000 characters, QR content 2,900 characters, sizes up to 20,000 pt,
ids `[A-Za-z0-9_-]{1,64}`, every `props.asset` must be listed in `assets`.

Element props by type: `text`, `contact` (+ `prefix`), `rect` (fill, fill2,
angle, stroke, strokeWidth, radius), `ellipse`, `line` (stroke, strokeWidth,
dash), `polygon` (sides, star, inner), `image` (asset, fit, mask, radius,
cropX/Y/W/H as fractions), `icon` (glyph, color), `qr` (payload, ecc,
color, background, quiet), `group`, `badge` (label, fill, ink, size).

## Profile

`id, kind, displayName, legalName, role, organization, bio, phones[],
emails[], websites[], addresses[], socials[], custom[], photo, logo,
updatedAt`. Each list item is `{label, value, private}`; private values are
left out of every export and binding.

## Bindings

`{field, mode}`. Fields: `name, role, org, phone[:n], email[:n], website[:n],
address[:n], social[:n], bio, custom:<label>, vcard, url`. `live` shows the
profile's current value; `snapshot` shows the element's stored text (the
value when it was unlinked). Exports are immutable files: editing a profile
changes what the next render shows, never a file already exported.

## Storage

Native: SQLite (`handy-card.sqlite`, `user_version` 1) with `records(kind, id,
json)` and `assets(id, bytes)`; each record is written in its own transaction,
in a background isolate. Web: IndexedDB `handy-card` with `records`
(`kind/id`) and `assets` (raw bytes). Pictures are stored once by SHA-256 and
removed at start-up when no design, template or profile uses them.

## Project ZIP (format `handy-card-project`, version 1)

`manifest.json` (format, version, schema, createdAt, `files: {path: sha256}`),
`designs/<id>.json`, `templates/<id>.json`, `profiles/<id>.json`,
`assets/<sha256>.<png|jpg|webp>`. Fonts are referenced by family name only.
Reading checks: allowed paths only (no traversal), at most 1,000 entries,
12 MB per entry and 30 MB in total before inflating, every hash, every
picture's bytes against its name, every design migrated and validated.
Imported items never replace existing ones (ids are reassigned on clash).
