import 'dart:math' as math;
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../bookmark/item_menu.dart';
import '../controller.dart';
import '../design/theme.dart';
import '../ui/visual.dart';
import '../ui/words.dart';

/// What a gallery layout needs: the saves in order and what tapping does.
class LayoutData {
  final SaveController controller;
  final List<Bookmark> rows;
  final ValueChanged<Bookmark> onOpen, onDetails, onToggle;
  final Set<String> selected;
  const LayoutData({
    required this.controller,
    required this.rows,
    required this.onOpen,
    required this.onDetails,
    required this.onToggle,
    this.selected = const {},
  });
}

/// A Pro way to show a collection. Each changes hierarchy, crop, density
/// and rhythm, not only colour; the same builder draws the preview and
/// the real screen.
class GalleryLayout {
  final String id, en, vi, tagEn, tagVi;
  final Widget Function(BuildContext, LayoutData) build;
  const GalleryLayout({
    required this.id,
    required this.en,
    required this.vi,
    required this.tagEn,
    required this.tagVi,
    required this.build,
  });
}

final galleryLayouts = <GalleryLayout>[
  GalleryLayout(
    id: 'magazine',
    en: 'Magazine',
    vi: 'Tạp chí',
    tagEn: 'A cover story, then features with a lead line',
    tagVi: 'Một bài trang bìa, rồi các bài có câu dẫn',
    build: (c, d) => _Magazine(d),
  ),
  GalleryLayout(
    id: 'masonry',
    en: 'Masonry',
    vi: 'Xếp gạch',
    tagEn: 'Two staggered columns, pictures at their own height',
    tagVi: 'Hai cột so le, ảnh cao thấp tự nhiên',
    build: (c, d) => _Masonry(d),
  ),
  GalleryLayout(
    id: 'filmstrip',
    en: 'Film strip',
    vi: 'Cuộn phim',
    tagEn: 'Tall frames to swipe through, newest first',
    tagVi: 'Khung dọc để vuốt qua, mới nhất trước',
    build: (c, d) => _FilmStrip(d),
  ),
  GalleryLayout(
    id: 'scrapbook',
    en: 'Scrapbook',
    vi: 'Sổ dán',
    tagEn: 'Photos taped in at a slight angle, captions below',
    tagVi: 'Ảnh dán hơi nghiêng, chú thích bên dưới',
    build: (c, d) => _Scrapbook(d),
  ),
  GalleryLayout(
    id: 'lookbook',
    en: 'Lookbook',
    vi: 'Lookbook',
    tagEn: 'One big picture at a time, lots of air',
    tagVi: 'Mỗi lần một ảnh lớn, nhiều khoảng thở',
    build: (c, d) => _Lookbook(d),
  ),
  GalleryLayout(
    id: 'board',
    en: 'Research board',
    vi: 'Bảng nghiên cứu',
    tagEn: 'Dense rows: source, title, note, date',
    tagVi: 'Dòng dày: nguồn, tiêu đề, ghi chú, ngày',
    build: (c, d) => _Board(d),
  ),
  GalleryLayout(
    id: 'timeline',
    en: 'Timeline journal',
    vi: 'Nhật ký thời gian',
    tagEn: 'Grouped by the day you saved them',
    tagVi: 'Gom theo ngày bạn lưu',
    build: (c, d) => _Timeline(d),
  ),
  GalleryLayout(
    id: 'moodboard',
    en: 'Moodboard',
    vi: 'Bảng cảm hứng',
    tagEn: 'A quilt of pictures, a large one every few',
    tagVi: 'Ghép ảnh như chăn, cứ vài ảnh có một ảnh lớn',
    build: (c, d) => _Moodboard(d),
  ),
];

GalleryLayout? layoutById(String? id) =>
    galleryLayouts.where((l) => l.id == id).firstOrNull;

String _month(BuildContext context, int m) => tr(
  context,
  const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m - 1],
  'Th $m',
);

String _title(Bookmark b) => b.title.isEmpty ? b.sourceDomain : b.title;

String _meta(BuildContext context, Bookmark b) => b.isImage
    ? ago(context, b.savedAt)
    : '${sourceLine(b)} · ${ago(context, b.savedAt)}';

/// Tap opens, long-press selects; a selected save carries a tick.
Widget _tap(LayoutData d, Bookmark b, Widget child, {double radius = 0}) =>
    Builder(
      builder: (context) {
        final p = BookmarkPalette.of(context);
        final on = d.selected.contains(b.id);
        return Semantics(
          button: true,
          selected: on,
          label: _title(b),
          child: Material(
            key: ValueKey('layout-${b.id}'),
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => d.selected.isEmpty ? d.onOpen(b) : d.onToggle(b),
              onLongPress: () => d.onToggle(b),
              child: Stack(
                children: [
                  child,
                  if (on)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: CircleAvatar(
                        radius: 13,
                        backgroundColor: p.primary,
                        child: Icon(Icons.check, size: 16, color: p.onPrimary),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

class _Magazine extends StatelessWidget {
  final LayoutData d;
  const _Magazine(this.d);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    if (d.rows.isEmpty) return const SizedBox.shrink();
    final lead = d.rows.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tap(
          d,
          lead,
          radius: BookmarkRadii.collection,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: ItemPicture(
                  d.controller,
                  lead,
                  radius: BookmarkRadii.collection,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _title(lead),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: bookmarkSerif(context, 28),
              ),
              const SizedBox(height: 6),
              if ((lead.description ?? lead.note).isNotEmpty)
                Text(
                  (lead.description ?? lead.note),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(color: p.muted),
                ),
              Text(_meta(context, lead), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final b in d.rows.skip(1)) ...[
          Divider(color: p.line, height: 1),
          _tap(
            d,
            b,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title(b),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: bookmarkSerif(context, 19),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _meta(context, b),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 96,
                    height: 72,
                    child: ItemPicture(d.controller, b, compact: true),
                  ),
                  ItemMenuButton(
                    bookmark: b,
                    onDetails: () => d.onDetails(b),
                    width: 40,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A stable height for a picture: varied, but the same on every visit.
double _ratio(Bookmark b) =>
    const [1.35, 0.8, 1.1, 1.5, 0.95][b.id.hashCode.abs() % 5];

class _Masonry extends StatelessWidget {
  final LayoutData d;
  const _Masonry(this.d);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cols = [<Bookmark>[], <Bookmark>[]];
    final heights = [0.0, 0.0];
    for (final b in d.rows) {
      final i = heights[0] <= heights[1] ? 0 : 1;
      cols[i].add(b);
      heights[i] += _ratio(b) + .35;
    }
    Widget column(List<Bookmark> list) => Column(
      children: [
        for (final b in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _tap(
              d,
              b,
              radius: BookmarkRadii.item,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1 / _ratio(b),
                    child: ItemPicture(
                      d.controller,
                      b,
                      radius: BookmarkRadii.item,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
                    child: Text(
                      _title(b),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column(cols[0])),
        const SizedBox(width: 12),
        Expanded(child: column(cols[1])),
      ],
    );
  }
}

class _FilmStrip extends StatelessWidget {
  final LayoutData d;
  const _FilmStrip(this.d);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const film = Color(0xFF15120F);
    Widget holes() => Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < 7; i++)
          Container(
            width: 9,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE6DA),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return SizedBox(
      height: 420 + 40 * (scale - 1).clamp(0.0, 1.2),
      child: ListView.separated(
        key: const Key('filmstrip'),
        scrollDirection: Axis.horizontal,
        itemCount: d.rows.length,
        separatorBuilder: (_, _) => const SizedBox(width: 2),
        itemBuilder: (context, i) {
          final b = d.rows[i];
          return SizedBox(
            width: 240,
            child: _tap(
              d,
              b,
              ColoredBox(
                color: film,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    holes(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        child: ItemPicture(d.controller, b, radius: 2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      child: Text(
                        _title(b),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFFF3ECE0),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Text(
                        '${i + 1}/${d.rows.length} · ${ago(context, b.savedAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFBDB3A6),
                        ),
                      ),
                    ),
                    holes(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Scrapbook extends StatelessWidget {
  final LayoutData d;
  const _Scrapbook(this.d);
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 22,
          children: [
            for (final (i, b) in d.rows.indexed)
              SizedBox(
                width: width,
                child: Transform.rotate(
                  angle: (i.isEven ? -1.6 : 1.4) * math.pi / 180,
                  child: _tap(
                    d,
                    b,
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                          decoration: BoxDecoration(
                            color: p.surface,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 1,
                                child: ItemPicture(d.controller, b, radius: 0),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _title(b),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: bookmarkSerif(context, 15),
                              ),
                            ],
                          ),
                        ),
                        // A strip of tape across the top edge.
                        Positioned(
                          top: -8,
                          left: width / 2 - 28,
                          child: Transform.rotate(
                            angle: (i.isEven ? 4 : -3) * math.pi / 180,
                            child: Container(
                              width: 56,
                              height: 16,
                              color: p.warm.withValues(alpha: .35),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Lookbook extends StatelessWidget {
  final LayoutData d;
  const _Lookbook(this.d);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final b in d.rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: _tap(
              d,
              b,
              radius: BookmarkRadii.focus,
              Column(
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 5,
                    child: ItemPicture(
                      d.controller,
                      b,
                      radius: BookmarkRadii.focus,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _title(b),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: bookmarkSerif(context, 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _meta(context, b),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  final LayoutData d;
  const _Board(this.d);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(BookmarkRadii.item),
      ),
      child: Column(
        children: [
          for (final (i, b) in d.rows.indexed) ...[
            if (i > 0) Divider(color: p.line, height: 1, indent: 52),
            _tap(
              d,
              b,
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: SourceFace(b, compact: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title(b),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            [
                              b.isImage
                                  ? tr(context, 'Picture', 'Ảnh')
                                  : b.sourceDomain,
                              formatDay(context, b.savedAt.substring(0, 10)),
                              if (b.note.isNotEmpty) b.note.split('\n').first,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    ItemMenuButton(
                      bookmark: b,
                      onDetails: () => d.onDetails(b),
                      width: 40,
                      height: 40,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final LayoutData d;
  const _Timeline(this.d);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final days = <String, List<Bookmark>>{};
    for (final b in d.rows) {
      final day = (DateTime.tryParse(b.savedAt)?.toLocal() ?? DateTime(1970))
          .toIso8601String()
          .substring(0, 10);
      (days[day] ??= []).add(b);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in days.entries)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 58,
                  child: Column(
                    children: [
                      Text(
                        e.key.substring(8, 10),
                        style: bookmarkSerif(context, 30).copyWith(height: 1),
                      ),
                      Text(
                        _month(context, int.parse(e.key.substring(5, 7))),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      Expanded(
                        child: VerticalDivider(
                          color: p.line,
                          width: 20,
                          thickness: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      children: [
                        for (final b in e.value)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _tap(
                              d,
                              b,
                              radius: BookmarkRadii.item,
                              Container(
                                padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                                decoration: BoxDecoration(
                                  color: p.surface,
                                  borderRadius: BorderRadius.circular(
                                    BookmarkRadii.item,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 54,
                                      height: 54,
                                      child: ItemPicture(
                                        d.controller,
                                        b,
                                        compact: true,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _title(b),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    ItemMenuButton(
                                      bookmark: b,
                                      onDetails: () => d.onDetails(b),
                                      width: 40,
                                      height: 40,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Moodboard extends StatelessWidget {
  final LayoutData d;
  const _Moodboard(this.d);
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 6.0;
        final unit = (box.maxWidth - gap * 2) / 3;
        // Every sixth tile (from the first) is two-by-two; the rest fill.
        final tiles = <Widget>[];
        for (final (i, b) in d.rows.indexed) {
          final big = i % 6 == 0;
          final side = big ? unit * 2 + gap : unit;
          tiles.add(
            SizedBox(
              width: side,
              height: side,
              child: _tap(
                d,
                b,
                radius: 10,
                Stack(
                  fit: StackFit.expand,
                  children: [
                    ItemPicture(d.controller, b, radius: 10, compact: !big),
                    if (big)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Color(0x8A000000),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                            child: Text(
                              _title(b),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }
        // A big tile takes the left two columns; small ones flow around
        // it in a 1-wide column, then rows of three.
        final rows = <Widget>[];
        var i = 0;
        while (i < tiles.length) {
          if (i % 6 == 0) {
            final side = [for (final t in tiles.skip(i + 1).take(2)) t];
            rows.add(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tiles[i],
                  const SizedBox(width: gap),
                  Column(
                    children: [
                      for (final (k, t) in side.indexed) ...[
                        if (k > 0) const SizedBox(height: gap),
                        t,
                      ],
                    ],
                  ),
                ],
              ),
            );
            i += 1 + side.length;
          } else {
            final row = tiles.skip(i).take(3).toList();
            rows.add(
              Row(
                children: [
                  for (final (k, t) in row.indexed) ...[
                    if (k > 0) const SizedBox(width: gap),
                    t,
                  ],
                ],
              ),
            );
            i += row.length;
          }
          rows.add(const SizedBox(height: gap));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        );
      },
    );
  }
}
