import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../covers/cover_art.dart';
import '../design/theme.dart';

/// A category's identity colour; null (Uncategorised) is neutral.
HandyHue categoryHue(BuildContext context, BoardRecord? category) {
  if (category == null) {
    final p = BoardsPalette.of(context);
    return HandyHue(p.control, p.raised);
  }
  return HandyPalette.of(context, category.number('color'));
}

/// The dark of a category's own hue, for its name on its pale field (a
/// light of the hue on the dark theme).
Color categoryInk(BuildContext context, BoardRecord? category) {
  if (category == null) return BoardsPalette.of(context).ink;
  final mark = categoryHue(context, category).mark;
  return Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(mark, Colors.white, .7)!
      : Color.lerp(mark, Colors.black, .6)!;
}

String categoryName(BuildContext context, BoardRecord? category) =>
    category?.str('title') ?? tr(context, 'Uncategorised', 'Chưa phân nhóm');

/// A category as a small chip: its dot and its name on a pale tint, so the
/// colour never stands alone.
class CategoryChip extends StatelessWidget {
  final BoardRecord? category;
  final bool dense;
  const CategoryChip(this.category, {super.key, this.dense = true});
  @override
  Widget build(BuildContext context) {
    final hue = categoryHue(context, category);
    final style = Theme.of(context).textTheme.labelMedium;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: dense ? 2 : 5),
      decoration: BoxDecoration(
        color: hue.tint,
        borderRadius: BorderRadius.circular(BoardsRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: hue.mark, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              categoryName(context, category),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// A card's category as a strip of paper tape holding it to the board:
/// the category's colour, a little crooked, torn ends, its name in ink.
/// The board's one signature; the colour never stands alone.
class CategoryTape extends StatelessWidget {
  final BoardRecord? category;
  const CategoryTape(this.category, {super.key});
  @override
  Widget build(BuildContext context) {
    final hue = categoryHue(context, category);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Transform.rotate(
      angle: -.03,
      alignment: Alignment.centerLeft,
      child: ClipPath(
        clipper: const _TornEnds(),
        child: Container(
          constraints: const BoxConstraints(minHeight: 22),
          padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
          color: Color.lerp(hue.tint, hue.mark, dark ? .12 : .1),
          child: Text(
            categoryName(context, category),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: categoryInk(context, category),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Both short ends cut in small teeth, as tape torn off a roll.
class _TornEnds extends CustomClipper<Path> {
  const _TornEnds();
  @override
  Path getClip(Size s) {
    const tooth = 3.0;
    final n = (s.height / 4).floor().clamp(3, 12);
    final step = s.height / n;
    final path = Path()..moveTo(0, 0);
    path.lineTo(s.width, 0);
    for (var i = 0; i < n; i++) {
      path
        ..lineTo(s.width - tooth, step * i + step / 2)
        ..lineTo(s.width, step * (i + 1));
    }
    path.lineTo(0, s.height);
    for (var i = n; i > 0; i--) {
      path
        ..lineTo(tooth, step * i - step / 2)
        ..lineTo(0, step * (i - 1));
    }
    return path..close();
  }

  @override
  bool shouldReclip(_TornEnds old) => false;
}

/// A card's cover as stored: built-in art, one of the identity colours, or
/// the person's photo (its preview). Null when the card has none.
Widget? cardCover(BuildContext context, BoardsState s, BoardRecord card) {
  final photo = card.data['coverPhoto'] as String?;
  if (photo != null) {
    final a = s.maybe('attachments', photo);
    final path = a?.data['preview'] as String? ?? a?.data['path'] as String?;
    if (path != null && s.hasFile(path)) return StoredPhoto(s, path);
  }
  final cover = card.data['cover'] as String?;
  if (cover == null) return null;
  if (cover.startsWith('color:'))
    return ColoredBox(
      color: HandyPalette.of(context, int.parse(cover.substring(6))).mark,
    );
  return CoverArt(cover.substring(4));
}

/// The cover a board shows: its own, or a stable free default picked from
/// its id, so every board has a face (and a colour).
String boardCoverId(BoardRecord board) {
  final id = board.data['cover'] as String?;
  if (id != null && coverById(id) != null) return id;
  final free = coverCatalog.where((c) => !c.pro).toList();
  if (free.isEmpty) return id ?? '';
  var h = 0;
  for (final u in board.id.codeUnits) h = (h * 31 + u) & 0x7fffffff;
  return free[h % free.length].id;
}

/// The board's cover art.
/// A board's cover: the person's own photo when the board has one (and
/// [state] is given to read it), else its drawn cover.
Widget boardCover(BoardRecord board, [BoardsState? state]) {
  final photo = board.data['coverPreview'] as String?;
  if (state != null && photo != null && state.files.containsKey(photo))
    return StoredPhoto(state, photo);
  return CoverArt(boardCoverId(board));
}

/// A photo kept in the app's own storage, read once and kept while shown.
class StoredPhoto extends StatefulWidget {
  final BoardsState state;
  final String path;
  const StoredPhoto(this.state, this.path, {super.key});
  @override
  State<StoredPhoto> createState() => _StoredPhotoState();
}

class _StoredPhotoState extends State<StoredPhoto> {
  static final _cache = <String, Uint8List>{};
  late Future<Uint8List> bytes = _read();
  Future<Uint8List> _read() async =>
      _cache[widget.path] ??= await widget.state.readFile(widget.path);
  @override
  void didUpdateWidget(StoredPhoto old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) bytes = _read();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: bytes,
    builder: (context, snap) {
      final p = BoardsPalette.of(context);
      if (!snap.hasData) return ColoredBox(color: p.raised);
      return Image.memory(
        snap.data!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => ColoredBox(color: p.raised),
      );
    },
  );
}

/// Today, Yesterday, or a short date, for "changed …" lines.
String whenLabel(BuildContext context, DateTime? at, DateTime now) {
  if (at == null) return '';
  final local = at.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return tr(context, 'today', 'hôm nay');
  if (days == 1) return tr(context, 'yesterday', 'hôm qua');
  if (days < 7) return tr(context, '$days days ago', '$days ngày trước');
  return tr(
    context,
    '${local.day}/${local.month}/${local.year}',
    '${local.day}/${local.month}/${local.year}',
  );
}

/// A due day in words: today, tomorrow, a weekday this week, or a date.
String dueLabel(BuildContext context, DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  // Calendar days, so a clock change never makes "tomorrow" today.
  final d = daysBetween(today, day);
  if (d == 0) return tr(context, 'Today', 'Hôm nay');
  if (d == 1) return tr(context, 'Tomorrow', 'Ngày mai');
  if (d == -1) return tr(context, 'Yesterday', 'Hôm qua');
  if (d > 1 && d < 7) {
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const vi = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ nhật',
    ];
    return tr(context, en[day.weekday - 1], vi[day.weekday - 1]);
  }
  return '${day.day}/${day.month}';
}

/// Light haptics when allowed; nothing on platforms without them.
void tick() {
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS)
    HapticFeedback.selectionClick();
}
