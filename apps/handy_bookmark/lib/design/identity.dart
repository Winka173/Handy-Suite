import 'package:handy_ui/kit.dart';

/// This product owns its visual configuration. Shared UI is a compatibility
/// renderer, not the authority for this app's typography or component shapes.
///
/// Warm Modern Library (2026-11-06): soft corners that step down from the
/// largest surface, surfaces that part by tone rather than by lines, one
/// sans-serif for the work, and the serif kept for a few editorial moments
/// (see `design/theme.dart`, which finishes the kit theme).
const bookmarkIdentity = HandyBrand(
  card: 16,
  control: 14,
  title: 26,
  tileMark: false,
  edgeless: true,
  ground: Color(0xFFF6F4EE),
  groundDark: Color(0xFF171D1C),
  surfaceDark: Color(0xFF222A29),
  heading: HandyHeading.large,
  rows: HandyRows.card,
);
