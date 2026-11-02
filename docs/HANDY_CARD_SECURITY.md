# Handy Card — security and privacy

- **No uploads.** Designs, profiles, pictures and QR content never leave the
  device except in files the person saves. No analytics; ads (mobile Free
  only) receive no design, profile or QR content and are off in the studio
  and export sheet.
- **Imports are data, never code.** Project ZIPs: path allowlist (no
  traversal, no unknown files), entry count and size caps checked before
  inflation, per-file SHA-256 against the manifest, picture bytes checked
  against their hash and sniffed as PNG/JPEG/WebP, every design migrated and
  validated before anything is written, nothing existing replaced. vCard
  import reads plain fields with a 200 KB cap.
- **Links.** Profile links become `https:` (no other scheme, no credentials,
  no spaces), `tel:` (digits) or `mailto:` (validated) or nothing. Invalid
  ones are flagged in the profile editor and left out of exports.
- **HTML profile and signature.** Every value is HTML-escaped; no scripts; a
  Content-Security-Policy of `default-src 'none'` with inline styles and
  `data:` images only; `rel="noopener noreferrer"`; no external requests.
  Tested against script, attribute and `javascript:` injection.
- **SVG.** Text is XML-escaped and control characters removed.
- **Private values** in a profile are excluded from bindings, vCard, QR, HTML
  and signatures.
- **File names** are sanitised (`safeCardFileName`).
- **Fonts and assets.** Only SIL Open Font License faces are bundled and
  embedded; templates and icons are original. Imported pictures are the
  person's own responsibility; the app never fetches remote images.
- **Not built:** app lock, encrypted storage. The SQLite and IndexedDB data
  are not encrypted, like the other Handy apps (see `KNOWN_ISSUES.md`).
