import 'package:handy_ui/kit.dart';

/// This product owns its visual configuration. Shared UI is a compatibility
/// renderer, not the authority for this app's typography or component shapes.
///
/// Warm Modern Library (2026-11-06): soft corners that step down from the
/// largest surface, surfaces that part by tone rather than by lines, one
/// sans-serif for the work, and the serif kept for a few editorial moments
/// (see `design/theme.dart`, which finishes the kit theme).
const bookmarkIdentity = HandyBrand(
  text: 'Manrope',
  card: 20,
  control: 12,
  title: 26,
  tileMark: false,
  edgeless: true,
  ground: Color(0xFFF3F5F7),
  groundDark: Color(0xFF141516),
  surfaceDark: Color(0xFF1E2022),
  heading: HandyHeading.large,
  rows: HandyRows.card,
);
