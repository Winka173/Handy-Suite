import 'package:handy_ui/kit.dart';

/// This product owns its visual configuration. Shared UI is a compatibility
/// renderer, not the authority for this app's typography or component shapes.
const bookmarkIdentity = HandyBrand(
  display: 'Newsreader',
  displayWeight: FontWeight.w500,
  card: 2,
  control: 4,
  title: 32,
  tileMark: false,
  ground: Color(0xFFFAF8F3),
  heading: HandyHeading.rule,
  rows: HandyRows.open,
);
