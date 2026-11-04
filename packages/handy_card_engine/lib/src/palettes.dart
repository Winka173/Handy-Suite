part of '../handy_card_engine.dart';

/// A card's five colour roles: ground, text, quiet text, accent, and text
/// on the accent. The template looks are palettes; so are a few more the
/// person can switch a design to in one tap.
class CardPalette {
  final String id, en, vi, bg, ink, muted, accent, onAccent;
  const CardPalette(
    this.id,
    this.en,
    this.vi, {
    required this.bg,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.onAccent,
  });

  String role(String r) => switch (r) {
    'bg' => bg,
    'ink' => ink,
    'muted' => muted,
    'accent' => accent,
    _ => onAccent,
  };
}

/// The template looks first (their colours exactly), then the rest. No
/// violet or indigo: they read as the default of every generated design.
const cardPalettes = [
  CardPalette(
    'paper',
    'Paper',
    'Giấy trắng',
    bg: 'FFFFFF',
    ink: '1E1E1E',
    muted: '6B6F76',
    accent: '1F4E79',
    onAccent: 'FFFFFF',
  ),
  CardPalette(
    'kraft',
    'Kraft',
    'Giấy kraft',
    bg: 'EFE6D8',
    ink: '3B2F2F',
    muted: '7A6A5C',
    accent: 'A0522D',
    onAccent: 'FFF8EE',
  ),
  CardPalette(
    'night',
    'Night',
    'Đêm',
    bg: '15181D',
    ink: 'F3F1EC',
    muted: 'A5A9B0',
    accent: 'E0B45C',
    onAccent: '15181D',
  ),
  CardPalette(
    'sage',
    'Sage',
    'Xanh xô thơm',
    bg: 'F3F5EF',
    ink: '22302A',
    muted: '66756D',
    accent: '3E6B57',
    onAccent: 'FFFFFF',
  ),
  CardPalette(
    'coral',
    'Coral',
    'San hô',
    bg: 'FFF6F2',
    ink: '2B1D1A',
    muted: '85706B',
    accent: 'D9573B',
    onAccent: 'FFFFFF',
  ),
  CardPalette(
    'ocean',
    'Ocean',
    'Biển',
    bg: 'F2F7FA',
    ink: '12303F',
    muted: '5E7682',
    accent: '1F6F8B',
    onAccent: 'FFFFFF',
  ),
  CardPalette(
    'mono',
    'Ink',
    'Mực đen',
    bg: 'FAFAF8',
    ink: '111111',
    muted: '6E6E6E',
    accent: '111111',
    onAccent: 'FAFAF8',
  ),
  CardPalette(
    'forest',
    'Forest',
    'Rừng đêm',
    bg: '1D2A23',
    ink: 'EEF2EA',
    muted: 'A9B8AE',
    accent: '9BC59D',
    onAccent: '1D2A23',
  ),
  CardPalette(
    'sun',
    'Sun',
    'Nắng',
    bg: 'FFF9E8',
    ink: '2B2620',
    muted: '7A6F5C',
    accent: 'C77A00',
    onAccent: 'FFFFFF',
  ),
  CardPalette(
    'rose',
    'Rose',
    'Hồng đất',
    bg: 'FBF1F2',
    ink: '3A2328',
    muted: '80656B',
    accent: 'B23A5B',
    onAccent: 'FFFFFF',
  ),
];

const _colourKeys = {'color', 'fill', 'stroke', 'background'};

/// Which role a colour plays, by where it sits: a page or shape ground
/// is most likely the background, a text colour most likely ink, and a
/// text colour equal to the ground can only be text on the accent.
const _priority = {
  'background': ['bg', 'accent', 'muted', 'ink', 'onAccent'],
  'fill': ['bg', 'accent', 'muted', 'ink', 'onAccent'],
  'stroke': ['accent', 'ink', 'muted', 'bg', 'onAccent'],
  'color': ['ink', 'muted', 'accent', 'onAccent', 'bg'],
};

Iterable<String> _colours(Object? v, [String? key]) sync* {
  if (v is Map) {
    for (final e in v.entries) {
      yield* _colours(e.value, e.key as String?);
    }
  } else if (v is List) {
    for (final x in v) {
      yield* _colours(x, key);
    }
  } else if (v is String && _colourKeys.contains(key) && _isHex(v)) {
    yield v.toUpperCase();
  }
}

bool _isHex(String v) => RegExp(r'^([0-9A-Fa-f]{6})$').hasMatch(v);

Iterable<String> _documentColours(CardDocument d) sync* {
  for (final p in d.pages) {
    if (p.background != null && _isHex(p.background!)) {
      yield p.background!.toUpperCase();
    }
    for (final e in p.elements) {
      yield* _colours(e.toJson());
    }
  }
}

/// The palette the design is drawn in: the one sharing the most of its
/// five colours with it, if at least three match. Null for a design with
/// colours of its own.
CardPalette? paletteOf(CardDocument d) {
  final used = _documentColours(d).toSet();
  CardPalette? best;
  var score = 2;
  for (final p in cardPalettes) {
    final s = {
      p.bg,
      p.ink,
      p.muted,
      p.accent,
      p.onAccent,
    }.where(used.contains).length;
    if (s > score) {
      score = s;
      best = p;
    }
  }
  return best;
}

/// [d] redrawn in [to]: every colour that belongs to its current palette
/// moves to the same role in [to]; colours the person chose themselves
/// stay. Null when the design is not in a known palette.
CardDocument? recolorDocument(CardDocument d, CardPalette to) {
  final from = paletteOf(d);
  if (from == null) return null;
  String map(String hex, String key) {
    final h = hex.toUpperCase();
    for (final r in _priority[key]!) {
      if (from.role(r) == h) return to.role(r);
    }
    return hex;
  }

  Object? walk(Object? v, [String? key]) {
    if (v is Map) {
      return <String, Object?>{
        for (final e in v.entries)
          e.key as String: walk(e.value, e.key as String?),
      };
    }
    if (v is List) return [for (final x in v) walk(x, key)];
    if (v is String && _colourKeys.contains(key) && _isHex(v)) {
      return map(v, key!);
    }
    return v;
  }

  CardElement element(CardElement e) => e.copyWith(
    props: walk(e.props) as Map<String, Object?>,
    children: [for (final c in e.children) element(c)],
  );

  return d.copyWith(
    pages: [
      for (final p in d.pages)
        p.copyWith(
          background: p.background == null
              ? null
              : map(p.background!, 'background'),
          elements: [for (final e in p.elements) element(e)],
        ),
    ],
  );
}
