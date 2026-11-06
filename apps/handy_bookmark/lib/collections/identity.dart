import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';

/// A collection's own look, chosen in its editor: one of the app's
/// identity colours and an icon or one emoji. Both live in the
/// collection's existing `color` and `icon` fields, so backups and sync
/// carry them and older versions simply ignore them:
///
/// - `color`: `hue:N` picks the Nth usable identity colour; anything else
///   (the old hex default) means Auto, the colour by position.
/// - `icon`: `emoji:X` for an emoji, a key of [collectionIcons] for an
///   icon; anything else (the old `folder` default) means none.

/// The icons a collection can wear: outlined, drawn in ink, never in the
/// collection's colour.
const collectionIcons = <String, IconData>{
  'restaurant': Icons.restaurant_outlined,
  'luggage': Icons.luggage_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'book': Icons.book_outlined,
  'play': Icons.play_circle_outline,
  'work': Icons.work_outline,
  'idea': Icons.lightbulb_outline,
  'gift': Icons.redeem_outlined,
  'home': Icons.home_outlined,
  'school': Icons.school_outlined,
  'fitness': Icons.fitness_center_outlined,
  'music': Icons.music_note_outlined,
  'art': Icons.palette_outlined,
  'code': Icons.code,
  'pets': Icons.pets_outlined,
  'money': Icons.savings_outlined,
};

/// An icon's name, for the screen reader and the tooltip.
String iconLabel(BuildContext context, String key) => switch (key) {
  'restaurant' => tr(context, 'Food', 'Đồ ăn'),
  'luggage' => tr(context, 'Travel', 'Du lịch'),
  'shopping' => tr(context, 'Shopping', 'Mua sắm'),
  'book' => tr(context, 'Reading', 'Đọc'),
  'play' => tr(context, 'Video', 'Video'),
  'work' => tr(context, 'Work', 'Công việc'),
  'idea' => tr(context, 'Ideas', 'Ý tưởng'),
  'gift' => tr(context, 'Gifts', 'Quà'),
  'home' => tr(context, 'Home', 'Nhà'),
  'school' => tr(context, 'Learning', 'Học'),
  'fitness' => tr(context, 'Fitness', 'Thể dục'),
  'music' => tr(context, 'Music', 'Âm nhạc'),
  'art' => tr(context, 'Art', 'Nghệ thuật'),
  'code' => tr(context, 'Code', 'Lập trình'),
  'pets' => tr(context, 'Pets', 'Thú cưng'),
  'money' => tr(context, 'Money', 'Tiền'),
  _ => key,
};

/// What a collection shows beside its name: an emoji or an icon.
sealed class CollectionMark {
  const CollectionMark();
}

class EmojiMark extends CollectionMark {
  final String emoji;
  const EmojiMark(this.emoji);
}

class IconMark extends CollectionMark {
  final String key;
  const IconMark(this.key);
  IconData get icon => collectionIcons[key]!;
}

/// The mark stored in an `icon` field, or null for none.
CollectionMark? markOf(String icon) {
  if (icon.startsWith('emoji:')) {
    final e = firstCharacter(icon.substring(6));
    return e.isEmpty ? null : EmojiMark(e);
  }
  return collectionIcons.containsKey(icon) ? IconMark(icon) : null;
}

/// How a mark is stored; none is the old default.
String storeMark(CollectionMark? mark) => switch (mark) {
  EmojiMark(:final emoji) => 'emoji:$emoji',
  IconMark(:final key) => key,
  null => 'folder',
};

/// The first user-perceived character of [text] (one emoji, flags and
/// joined families included), trimmed.
String firstCharacter(String text) {
  final t = text.trim();
  return t.isEmpty ? '' : t.characters.first;
}

/// The chosen colour stored in a `color` field, or null for Auto.
int? chosenHue(String color) =>
    color.startsWith('hue:') ? int.tryParse(color.substring(4)) : null;

String storeHue(int? hue) => hue == null ? 'auto' : 'hue:$hue';

/// How many identity colours this app can use (the ones near its own
/// colour are left out by [HandyPalette]).
int usableHues(BuildContext context) {
  final first = HandyPalette.of(context, 0).mark;
  for (var i = 1; i < HandyPalette.count; i++) {
    if (HandyPalette.of(context, i).mark == first) return i;
  }
  return HandyPalette.count;
}

/// A colour's name, for the screen reader and the tooltip.
String hueName(BuildContext context, int index) {
  final hue = HSVColor.fromColor(HandyPalette.of(context, index).mark).hue;
  const names = [
    (220.0, 'Blue', 'Xanh dương'),
    (42.0, 'Amber', 'Vàng hổ phách'),
    (128.0, 'Leaf', 'Xanh lá'),
    (338.0, 'Rose', 'Hồng'),
    (173.0, 'Teal', 'Xanh ngọc'),
    (8.0, 'Tomato', 'Đỏ cà chua'),
    (202.0, 'Sky', 'Xanh da trời'),
    (68.0, 'Olive', 'Xanh ô liu'),
  ];
  double gap(double a) {
    final d = (a - hue).abs() % 360;
    return d > 180 ? 360 - d : d;
  }

  final best = names.reduce((a, b) => gap(a.$1) <= gap(b.$1) ? a : b);
  return tr(context, best.$2, best.$3);
}

/// A ready start for a new collection.
typedef CollectionTemplate = ({String en, String vi, String icon, int hue});

const collectionTemplates = <CollectionTemplate>[
  (en: 'Recipes', vi: 'Công thức nấu ăn', icon: 'restaurant', hue: 1),
  (en: 'Trips', vi: 'Du lịch', icon: 'luggage', hue: 0),
  (en: 'To buy', vi: 'Cần mua', icon: 'shopping', hue: 2),
  (en: 'Read later', vi: 'Đọc sau', icon: 'book', hue: 3),
  (en: 'Watch later', vi: 'Xem sau', icon: 'play', hue: 4),
  (en: 'Work', vi: 'Công việc', icon: 'work', hue: 5),
  (en: 'Ideas', vi: 'Ý tưởng', icon: 'idea', hue: 1),
  (en: 'Gifts', vi: 'Quà tặng', icon: 'gift', hue: 3),
];

/// The colour a collection is shown in: its own choice, else its top
/// collection's choice, else its top collection's place among the top
/// ones (so neighbours differ and children match their parent).
int collectionHueIn(SaveLibrary l, String id) {
  final byId = {for (final c in l.collections) c.id: c};
  var at = byId[id];
  final own = at == null ? null : chosenHue(at.color);
  if (own != null) return own;
  for (var i = 0; at?.parentId != null && i < 32; i++) {
    at = byId[at!.parentId];
    final chosen = at == null ? null : chosenHue(at.color);
    if (chosen != null) return chosen;
  }
  final roots = [
    for (final c in l.collections)
      if (c.parentId == null) c,
  ]..sort((a, b) => a.position.compareTo(b.position));
  final index = roots.indexWhere((c) => c.id == at?.id);
  return index < 0 ? HandyPalette.forKey(id) : index;
}

/// The mark beside a collection's name: its icon or emoji on a pale wash
/// of its colour, or just the colour's dot when it has none.
class CollectionBadge extends StatelessWidget {
  final int hue;
  final CollectionMark? mark;

  /// The dot's size; a mark takes about two and a half times it.
  final double size;
  const CollectionBadge({
    super.key,
    required this.hue,
    this.mark,
    this.size = 9,
  });

  @override
  Widget build(BuildContext context) {
    final m = mark;
    if (m == null) return HandyDot(hue, size: size);
    final box = (size * 2.4).clamp(18.0, 40.0);
    final ink = BookmarkPalette.of(context).ink;
    return ExcludeSemantics(
      child: Container(
        width: box,
        height: box,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HandyPalette.of(context, hue).tint,
          shape: BoxShape.circle,
        ),
        child: switch (m) {
          EmojiMark(:final emoji) => Text(
            emoji,
            style: TextStyle(fontSize: box * .58, height: 1),
          ),
          IconMark(:final icon) => Icon(icon, size: box * .6, color: ink),
        },
      ),
    );
  }
}
