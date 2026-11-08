import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:handy_ui/kit.dart';
import '../design/looks.dart';
import '../design/theme.dart';
import '../platform/widget_styles.dart';
import 'entitlements.dart';

/// Each Pro part acted out by a tiny library made of the app's own pieces
/// (saved links, collections, its real themes and widget styles), drawn on
/// a fixed 320×180 stage and scaled to fit. `t` runs 0 to 1; t = 1 is the
/// still that explains the part by itself (reduced motion and the list's
/// thumbnails show only that frame). The drawing's text never follows the
/// system text size; the label is what is read aloud.
Widget bookmarkProDemo(BuildContext context, ProFeature f, double t) =>
    MediaQuery.withNoTextScaling(
      child: FittedBox(
        child: SizedBox(
          width: 320,
          height: 180,
          child: switch (f) {
            ProFeature.premiumThemes => _Themes(t),
            ProFeature.premiumLayouts => _Layouts(t),
            ProFeature.focusSkins => _Skins(t),
            ProFeature.widgets => _Widgets(t),
            ProFeature.autoOrganize => _AutoOrganize(t),
            ProFeature.smartCollections => _Smart(t),
            ProFeature.advancedBulk => _Bulk(t),
            ProFeature.readerHighlights => _Highlights(t),
            ProFeature.deepSearch => _Search(t),
            ProFeature.ocrOffline => _Ocr(t),
            ProFeature.premiumExport => _Export(t),
            ProFeature.folders => _Folders(t),
          },
        ),
      ),
    );

/// What each demo shows, read aloud in place of the drawing.
String bookmarkProDemoLabel(BuildContext context, ProFeature f) => switch (f) {
  ProFeature.premiumThemes => tr(
    context,
    'The library changes from theme to theme.',
    'Thư viện đổi qua từng giao diện.',
  ),
  ProFeature.premiumLayouts => tr(
    context,
    'A collection rearranges from a list to masonry, a film strip and a magazine.',
    'Một bộ sưu tập đổi từ danh sách sang xếp gạch, cuộn phim và tạp chí.',
  ),
  ProFeature.focusSkins => tr(
    context,
    'One saved item shown in Focus in four styles.',
    'Một mục đã lưu hiện trong Tập trung với bốn kiểu.',
  ),
  ProFeature.widgets => tr(
    context,
    'A home-screen widget of reading picks changes style.',
    'Widget gợi ý đọc trên màn hình chính đổi kiểu.',
  ),
  ProFeature.autoOrganize => tr(
    context,
    'New saves go to their collections by where they came from.',
    'Mục mới tự vào bộ sưu tập theo nguồn.',
  ),
  ProFeature.smartCollections => tr(
    context,
    'A collection fills itself from a rule.',
    'Một bộ sưu tập tự gom mục theo quy tắc.',
  ),
  ProFeature.advancedBulk => tr(
    context,
    'Several items are picked, their titles cleaned and filed at once.',
    'Chọn nhiều mục, dọn tiêu đề và xếp cùng lúc.',
  ),
  ProFeature.readerHighlights => tr(
    context,
    'Passages are highlighted in the reader and a note is added.',
    'Đánh dấu đoạn văn trong trình đọc và thêm ghi chú.',
  ),
  ProFeature.deepSearch => tr(
    context,
    'A search finds words inside articles, highlights and pictures.',
    'Tìm thấy chữ trong bài viết, đoạn đánh dấu và ảnh.',
  ),
  ProFeature.ocrOffline => tr(
    context,
    'The text in a picture is read on this device, ready to copy.',
    'Chữ trong ảnh được đọc ngay trên máy, sẵn để chép.',
  ),
  ProFeature.premiumExport => tr(
    context,
    'A collection becomes a designed PDF.',
    'Một bộ sưu tập thành tệp PDF có thiết kế.',
  ),
  ProFeature.folders => tr(
    context,
    'A Recipes collection sorted into two folders, Soups and Cakes.',
    'Bộ Công thức chia thành hai thư mục, Món canh và Bánh.',
  ),
};

double _seg(double t, double a, double b) =>
    Curves.easeInOutCubic.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

TextStyle _text(
  BuildContext context,
  double size, {
  Color? color,
  bool bold = false,
  bool serif = false,
}) {
  final base = serif
      ? bookmarkSerif(context, size)
      : TextStyle(
          fontSize: size,
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        );
  return base.copyWith(
    fontSize: size,
    height: 1.2,
    color: color ?? BookmarkPalette.of(context).ink,
    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
  );
}

Widget _fade(double v, Widget child, {double dy = 8, double dx = 0}) => Opacity(
  opacity: v,
  child: Transform.translate(
    offset: Offset(dx * (1 - v), dy * (1 - v)),
    child: child,
  ),
);

Text _line(
  BuildContext context,
  String s,
  double size, {
  Color? color,
  bool bold = false,
  bool serif = false,
}) => Text(
  s,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: _text(context, size, color: color, bold: bold, serif: serif),
);

/// A saved page's picture, drawn: a pale field of the item's hue with a
/// sun and a hill, so a picture reads as a picture at any size.
class _Pic extends StatelessWidget {
  final int hue;
  final double radius;
  const _Pic(this.hue, {this.radius = 6});
  @override
  Widget build(BuildContext context) {
    final h = HandyPalette.of(context, hue);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        painter: _PicPainter(h.tint, h.mark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PicPainter extends CustomPainter {
  final Color ground, mark;
  _PicPainter(this.ground, this.mark);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    final m = Paint()..color = mark.withValues(alpha: .55);
    canvas.drawCircle(
      Offset(size.width * .72, size.height * .32),
      size.shortestSide * .14,
      m,
    );
    final hill = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * .38, size.height * .5)
      ..lineTo(size.width * .7, size.height * .82)
      ..lineTo(size.width * .85, size.height * .68)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(hill, Paint()..color = mark.withValues(alpha: .8));
  }

  @override
  bool shouldRepaint(_PicPainter old) =>
      old.ground != ground || old.mark != mark;
}

/// Saved pages the demos share: title, site, hue of its picture.
List<(String, String, int)> _items(BuildContext context) => [
  (
    tr(
      context,
      'Sourdough for beginners',
      'Bánh mì men tự nhiên cho người mới',
    ),
    'theperfectloaf.com',
    1,
  ),
  (tr(context, 'A week in Đà Lạt', 'Một tuần ở Đà Lạt'), 'youtube.com', 2),
  (
    tr(context, 'Designing calm interfaces', 'Thiết kế giao diện tĩnh'),
    'medium.com',
    0,
  ),
  (
    tr(context, 'Linen curtains, sewn by hand', 'Rèm vải lanh tự may'),
    'pinterest.com',
    3,
  ),
  (
    tr(context, 'The best ramen in Tokyo', 'Ramen ngon nhất Tokyo'),
    'tiktok.com',
    5,
  ),
  (
    tr(context, 'Dart isolates explained', 'Giải thích isolate trong Dart'),
    'github.com',
    4,
  ),
];

/// A saved item as the library lists it: picture, title, site.
class _Row extends StatelessWidget {
  final (String, String, int) item;
  final double width;
  final Color? ink, muted, fill;
  const _Row(this.item, {this.width = 150, this.ink, this.muted, this.fill});
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: fill ?? BookmarkPalette.of(context).surface,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        SizedBox(width: 28, height: 22, child: _Pic(item.$3, radius: 4)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(context, item.$1, 8, bold: true, color: ink),
              _line(
                context,
                item.$2,
                6.5,
                color: muted ?? BookmarkPalette.of(context).muted,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Themes extends StatelessWidget {
  final double t;
  const _Themes(this.t);
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final picks = [libraryLook, ...premiumLooks.take(4)];
    final pos = t * (picks.length - 1);
    final i = math.min(picks.length - 2, pos.floor());
    final f = Curves.easeInOut.transform((pos - i).clamp(0.0, 1.0));
    final a = picks[i].palette(b), z = picks[i + 1].palette(b);
    Color mix(Color Function(BookmarkPalette) g) => Color.lerp(g(a), g(z), f)!;
    final name = picks[(pos + .5).floor().clamp(0, picks.length - 1)];
    final items = _items(context);
    return Container(
      color: mix((p) => p.canvas),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _line(
                  context,
                  tr(context, 'Library', 'Thư viện'),
                  16,
                  serif: true,
                  color: mix((p) => p.ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: mix((p) => p.primary),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: _line(
                  context,
                  tr(context, name.en, name.vi),
                  8,
                  color: mix((p) => p.onPrimary),
                  bold: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final it in items.take(4))
                _Row(
                  it,
                  width: 145,
                  fill: mix((p) => p.surface),
                  ink: mix((p) => p.ink),
                  muted: mix((p) => p.muted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Five saved items, each at a place in four layouts; the demo moves
/// them from one arrangement to the next.
class _Layouts extends StatelessWidget {
  final double t;
  const _Layouts(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final items = _items(context);
    final names = [
      tr(context, 'List', 'Danh sách'),
      tr(context, 'Masonry', 'Xếp gạch'),
      tr(context, 'Film strip', 'Cuộn phim'),
      tr(context, 'Magazine', 'Tạp chí'),
    ];
    // Rects as (left, top, width, height) in a 296×140 field.
    const layouts = <List<(double, double, double, double)>>[
      [
        (0, 0, 296, 24),
        (0, 28, 296, 24),
        (0, 56, 296, 24),
        (0, 84, 296, 24),
        (0, 112, 296, 24),
      ],
      [
        (0, 0, 145, 70),
        (151, 0, 145, 44),
        (0, 74, 145, 62),
        (151, 48, 145, 52),
        (151, 104, 145, 32),
      ],
      [
        (0, 20, 90, 100),
        (96, 20, 90, 100),
        (192, 20, 90, 100),
        (288, 20, 90, 100),
        (384, 20, 90, 100),
      ],
      [
        (0, 0, 190, 136),
        (196, 0, 100, 42),
        (196, 47, 100, 42),
        (196, 94, 100, 42),
        (296, 136, 0, 0),
      ],
    ];
    final pos = t * 3;
    final i = math.min(2, pos.floor());
    final f = Curves.easeInOutCubic.transform((pos - i).clamp(0.0, 1.0));
    final name = names[(pos + .5).floor().clamp(0, 3)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _line(
                  context,
                  tr(context, 'Weekend reads', 'Đọc cuối tuần'),
                  12,
                  serif: true,
                ),
              ),
              _line(context, name, 9, color: p.muted, bold: true),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 296,
            height: 140,
            child: ClipRect(
              child: Stack(
                children: [
                  for (var k = 0; k < 5; k++)
                    Builder(
                      builder: (context) {
                        final a = layouts[i][k], z = layouts[i + 1][k];
                        final w = lerpDouble(a.$3, z.$3, f)!;
                        final h = lerpDouble(a.$4, z.$4, f)!;
                        final tall = h > 34;
                        return Positioned(
                          left: lerpDouble(a.$1, z.$1, f),
                          top: lerpDouble(a.$2, z.$2, f),
                          width: w,
                          height: h,
                          child: w < 4 || h < 4
                              ? const SizedBox.shrink()
                              : Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: p.surface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: w < 60 || h < 16
                                      ? _Pic(items[k].$3, radius: 0)
                                      : tall
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _Pic(
                                                items[k].$3,
                                                radius: 0,
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(3),
                                              child: _line(
                                                context,
                                                items[k].$1,
                                                7,
                                                bold: true,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Padding(
                                          padding: const EdgeInsets.all(3),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 24,
                                                child: _Pic(
                                                  items[k].$3,
                                                  radius: 3,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: _line(
                                                  context,
                                                  items[k].$1,
                                                  7.5,
                                                  bold: true,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Skins extends StatelessWidget {
  final double t;
  const _Skins(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final item = _items(context)[1];
    final at = math.min(3, (t * 4).floor());
    final skins = [
      tr(context, 'Minimal', 'Tối giản'),
      tr(context, 'Film', 'Phim'),
      tr(context, 'Editorial', 'Tạp chí'),
      tr(context, 'Nocturne', 'Đêm'),
    ];
    final Widget body = switch (at) {
      0 => Container(
        color: p.canvas,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.$1,
                maxLines: 3,
                style: _text(context, 20, bold: true),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 60, height: 60, child: _Pic(item.$3)),
          ],
        ),
      ),
      1 => Container(
        color: const Color(0xFF111111),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: Colors.white.withValues(alpha: .5),
                      width: 3,
                    ),
                  ),
                ),
                child: _Pic(item.$3, radius: 0),
              ),
            ),
            const SizedBox(height: 6),
            _line(context, item.$1, 10, color: Colors.white, bold: true),
          ],
        ),
      ),
      2 => Container(
        color: const Color(0xFFFBFAF6),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(
                    context,
                    item.$2.toUpperCase(),
                    7,
                    color: const Color(0xFF6B6B6B),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$1,
                    maxLines: 3,
                    style: _text(
                      context,
                      18,
                      serif: true,
                      color: const Color(0xFF1F1F1F),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 90, height: 120, child: _Pic(item.$3, radius: 0)),
          ],
        ),
      ),
      _ => Container(
        color: const Color(0xFF0D1117),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(height: 56, width: 90, child: _Pic(item.$3)),
            const SizedBox(height: 10),
            _line(
              context,
              item.$1,
              16,
              color: const Color(0xFFE6EDF3),
              bold: true,
            ),
            _line(context, item.$2, 9, color: const Color(0xFF9DA7B3)),
          ],
        ),
      ),
    };
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: KeyedSubtree(key: ValueKey(at), child: body),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(99),
            ),
            child: _line(context, skins[at], 8, bold: true),
          ),
        ),
      ],
    );
  }
}

class _Widgets extends StatelessWidget {
  final double t;
  const _Widgets(this.t);
  @override
  Widget build(BuildContext context) {
    final styles = [
      for (final w in bookmarkWidgetStyles)
        if (w.pro) w,
    ];
    final at = math.min(styles.length - 1, (t * styles.length).floor());
    final s = styles[at];
    final items = _items(context);
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: 230,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: s.bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _line(
                    context,
                    tr(context, 'Reading picks', 'Gợi ý đọc'),
                    11,
                    bold: true,
                    color: s.ink,
                  ),
                ),
                _line(context, tr(context, s.en, s.vi), 8, color: s.muted),
              ],
            ),
            const SizedBox(height: 8),
            for (final it in items.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      height: 22,
                      child: _Pic(it.$3, radius: 4),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _line(context, it.$1, 8.5, bold: true, color: s.ink),
                          _line(context, it.$2, 7, color: s.muted),
                        ],
                      ),
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: s.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _collection(
  BuildContext context,
  String name,
  int hue,
  List<Widget> rows, {
  double width = 140,
  double height = 132,
}) {
  final p = BookmarkPalette.of(context);
  return Container(
    width: width,
    height: height,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: p.raised,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HandyDot(hue, size: 7),
            const SizedBox(width: 5),
            Expanded(child: _line(context, name, 9, bold: true)),
          ],
        ),
        const SizedBox(height: 5),
        for (final r in rows)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: r),
      ],
    ),
  );
}

class _AutoOrganize extends StatelessWidget {
  final double t;
  const _AutoOrganize(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final items = _items(context);
    final watch = items[1], code = items[5], read = items[2];
    // Each new save starts in "Not sorted" and moves to its collection.
    final moves = [_seg(t, .15, .4), _seg(t, .35, .6), _seg(t, .55, .8)];
    final from = [
      const Offset(10, 34),
      const Offset(10, 64),
      const Offset(10, 94),
    ];
    final to = [
      const Offset(166, 30),
      const Offset(166, 108),
      const Offset(166, 58),
    ];
    final saves = [watch, code, read];
    return Stack(
      children: [
        Positioned(
          left: 6,
          top: 8,
          child: Container(
            width: 146,
            height: 128,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: p.warningTint,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.topLeft,
            child: _line(
              context,
              tr(context, 'Not sorted', 'Chưa xếp'),
              9,
              bold: true,
            ),
          ),
        ),
        Positioned(
          left: 160,
          top: 8,
          child: Column(
            children: [
              _collection(
                context,
                tr(context, 'Watch later', 'Xem sau'),
                0,
                const [],
                width: 152,
                height: 48,
              ),
              const SizedBox(height: 4),
              _collection(
                context,
                tr(context, 'Code', 'Lập trình'),
                4,
                const [],
                width: 152,
                height: 76,
              ),
            ],
          ),
        ),
        for (var k = 0; k < 3; k++)
          Positioned(
            left: Offset.lerp(from[k], to[k], moves[k])!.dx,
            top: Offset.lerp(from[k], to[k], moves[k])!.dy,
            child: _Row(saves[k], width: 140),
          ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 8,
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_motion_outlined,
                size: 11,
                color: p.primary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _line(
                  context,
                  tr(
                    context,
                    'youtube.com → Watch later · github.com → Code',
                    'youtube.com → Xem sau · github.com → Lập trình',
                  ),
                  8.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A Recipes collection sorted into two folders: they appear beside it,
/// three saves slide into them and one stays in the collection. The still
/// shows the collection with its folders, one level deep.
class _Folders extends StatelessWidget {
  final double t;
  const _Folders(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final saves = [
      (tr(context, 'Sour fish soup', 'Canh chua cá lóc'), 'youtube.com', 2),
      (tr(context, 'Crème caramel', 'Bánh flan'), 'tiktok.com', 1),
      (tr(context, 'Pumpkin soup', 'Canh bí đỏ'), 'pinterest.com', 3),
      (tr(context, 'Beef stew', 'Bò kho'), 'facebook.com', 5),
    ];
    final folders = _seg(t, .05, .25);
    // Where each save ends: two soups, one cake; the stew stays.
    const from = [
      Offset(10, 26),
      Offset(10, 58),
      Offset(10, 90),
      Offset(10, 122),
    ];
    const to = [
      Offset(170, 26),
      Offset(170, 118),
      Offset(170, 58),
      Offset(10, 26),
    ];
    final moves = [
      _seg(t, .3, .5),
      _seg(t, .42, .62),
      _seg(t, .54, .74),
      _seg(t, .7, .88),
    ];
    Widget card(
      String name,
      int hue,
      double top,
      double height, {
      bool folder = false,
    }) => Positioned(
      left: folder ? 164 : 4,
      top: top,
      child: Container(
        width: 152,
        height: height,
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 0),
        alignment: Alignment.topLeft,
        decoration: BoxDecoration(
          color: folder ? p.surface : p.raised,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (folder)
              Icon(Icons.folder_outlined, size: 10, color: p.muted)
            else
              HandyDot(hue, size: 7),
            const SizedBox(width: 5),
            Expanded(child: _line(context, name, 9, bold: true)),
          ],
        ),
      ),
    );
    return Stack(
      children: [
        card(tr(context, 'Recipes', 'Công thức'), 0, 4, 152),
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          bottom: 0,
          child: _fade(
            folders,
            Stack(
              children: [
                card(tr(context, 'Soups', 'Món canh'), 0, 4, 86, folder: true),
                card(tr(context, 'Cakes', 'Bánh'), 0, 96, 60, folder: true),
              ],
            ),
            dx: 12,
            dy: 0,
          ),
        ),
        for (var k = 0; k < saves.length; k++)
          Positioned(
            left: Offset.lerp(from[k], to[k], moves[k])!.dx,
            top: Offset.lerp(from[k], to[k], moves[k])!.dy,
            child: _Row(saves[k], width: 140),
          ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 4,
          child: Row(
            children: [
              Icon(
                Icons.create_new_folder_outlined,
                size: 11,
                color: p.primary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _line(
                  context,
                  tr(
                    context,
                    'One level: a folder holds saves, never folders',
                    'Một cấp: thư mục chứa mục, không chứa thư mục',
                  ),
                  8.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Smart extends StatelessWidget {
  final double t;
  const _Smart(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final items = _items(context);
    final rule = _seg(t, .05, .2);
    final picks = [items[0], items[3], items[4]];
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: _fade(
              rule,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(
                    context,
                    tr(context, 'Fills itself when', 'Tự gom khi'),
                    9,
                    color: p.muted,
                  ),
                  const SizedBox(height: 5),
                  for (final c in [
                    tr(context, 'Has a picture', 'Có ảnh'),
                    tr(context, 'Not read yet', 'Chưa đọc'),
                    tr(context, 'Saved this month', 'Lưu trong tháng này'),
                  ])
                    Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: p.tint,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: _line(context, c, 8.5, bold: true),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _collection(
              context,
              tr(context, 'To try this month', 'Thử trong tháng'),
              3,
              [
                for (var k = 0; k < picks.length; k++)
                  _fade(
                    _seg(t, .3 + k * .15, .5 + k * .15),
                    _Row(picks[k], width: 150),
                    dx: 20,
                    dy: 0,
                  ),
              ],
              height: 150,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bulk extends StatelessWidget {
  final double t;
  const _Bulk(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final messy = [
      (
        'Sourdough for beginners!!! | The Perfect Loaf',
        tr(context, 'Sourdough for beginners', 'Bánh mì men tự nhiên'),
      ),
      (
        'Focaccia recipe - Easy - BEST EVER',
        tr(context, 'Focaccia recipe', 'Công thức focaccia'),
      ),
      (
        'How to feed a starter (2025 update) | Blog',
        tr(context, 'How to feed a starter', 'Cách nuôi men'),
      ),
    ];
    final clean = _seg(t, .45, .6);
    final filed = _seg(t, .7, .85);
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var k = 0; k < messy.length; k++)
            Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _check(context, _seg(t, .08 + k * .1, .16 + k * .1)),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 26,
                    height: 18,
                    child: _Pic(1 + k, radius: 3),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Stack(
                      children: [
                        Opacity(
                          opacity: 1 - clean,
                          child: _line(context, messy[k].$1, 8.5, bold: true),
                        ),
                        Opacity(
                          opacity: clean,
                          child: _line(context, messy[k].$2, 8.5, bold: true),
                        ),
                      ],
                    ),
                  ),
                  if (filed > 0) ...[
                    const SizedBox(width: 4),
                    Opacity(
                      opacity: filed,
                      child: Row(
                        children: [
                          const HandyDot(1, size: 6),
                          const SizedBox(width: 3),
                          _line(
                            context,
                            tr(context, 'Baking', 'Làm bánh'),
                            7.5,
                            color: p.muted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _line(
                  context,
                  filed > .5
                      ? tr(
                          context,
                          '3 filed in Baking · titles cleaned',
                          'Đã xếp 3 mục vào Làm bánh · đã dọn tiêu đề',
                        )
                      : tr(
                          context,
                          '3 picked · dry run first',
                          'Đã chọn 3 · chạy thử trước',
                        ),
                  9,
                ),
              ),
              Opacity(
                opacity: filed,
                child: _line(
                  context,
                  tr(context, 'Undo', 'Hoàn tác'),
                  9,
                  bold: true,
                  color: p.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _check(BuildContext context, double on) {
  final p = BookmarkPalette.of(context);
  return Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: Color.lerp(Colors.transparent, p.primary, on),
      border: Border.all(color: on > .5 ? p.primary : p.control),
      borderRadius: BorderRadius.circular(2),
    ),
    child: on > .5 ? Icon(Icons.check, size: 8, color: p.onPrimary) : null,
  );
}

class _Highlights extends StatelessWidget {
  final double t;
  const _Highlights(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final lines = tr(
      context,
      'Feed the starter twice a day at the same time.|Keep it somewhere warm, around 26°C.|When it doubles in four to six hours,|it is ready to bake with. A starter that|smells of nail varnish is hungry, not ruined.',
      'Cho men ăn hai lần mỗi ngày vào cùng giờ.|Để men ở chỗ ấm, khoảng 26°C.|Khi men nở gấp đôi sau bốn đến sáu giờ|là có thể làm bánh. Men có mùi như nước|rửa móng tay là đói, không phải hỏng.',
    ).split('|');
    final marks = [
      (1, _seg(t, .1, .35), const Color(0xFFFFE58A)),
      (2, _seg(t, .4, .65), const Color(0xFFBDEBC8)),
    ];
    final note = _seg(t, .7, .85);
    return Stack(
      children: [
        Positioned(
          left: 16,
          top: 10,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(
                context,
                tr(context, 'Sourdough for beginners', 'Bánh mì men tự nhiên'),
                13,
                serif: true,
              ),
              const SizedBox(height: 8),
              for (var k = 0; k < lines.length; k++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Stack(
                    children: [
                      for (final m in marks)
                        if (m.$1 == k)
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: m.$2,
                                child: Container(color: m.$3),
                              ),
                            ),
                          ),
                      _line(
                        context,
                        lines[k],
                        10,
                        color: marks.any((m) => m.$1 == k && m.$2 > .1)
                            ? const Color(0xFF1F1F1F)
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          right: 14,
          bottom: 10,
          child: _fade(
            note,
            Container(
              width: 150,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 11,
                    color: p.primary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _line(
                      context,
                      tr(context, 'Try 25°C in winter', 'Mùa đông thử 25°C'),
                      9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Search extends StatelessWidget {
  final double t;
  const _Search(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final word = tr(context, 'starter', 'men');
    final typed = word.substring(0, (word.length * _seg(t, .02, .3)).round());
    final results = [
      (
        _items(context)[0],
        tr(context, 'in the article', 'trong bài viết'),
        Icons.article_outlined,
      ),
      (
        (
          tr(context, 'Notes: feeding times', 'Ghi chú: giờ cho ăn'),
          'notes',
          4,
        ),
        tr(context, 'in a highlight', 'trong đoạn đánh dấu'),
        Icons.format_quote,
      ),
      (
        (tr(context, 'Bakery chalkboard', 'Bảng phấn tiệm bánh'), 'photo', 3),
        tr(context, 'in the picture', 'trong ảnh'),
        Icons.image_outlined,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 12, color: p.muted),
                const SizedBox(width: 6),
                Text(typed, style: _text(context, 10)),
                Container(width: 1, height: 11, color: p.primary),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (var k = 0; k < results.length; k++)
            _fade(
              _seg(t, .35 + k * .15, .5 + k * .15),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _Row(results[k].$1, width: double.infinity),
                    ),
                    const SizedBox(width: 8),
                    Icon(results[k].$3, size: 11, color: p.primary),
                    const SizedBox(width: 3),
                    SizedBox(
                      width: 92,
                      child: _line(context, results[k].$2, 8.5, color: p.ink),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Ocr extends StatelessWidget {
  final double t;
  const _Ocr(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final scan = _seg(t, .05, .45);
    final lines = [
      tr(context, 'Tiệm Bánh Mì Hòa', 'Tiệm Bánh Mì Hòa'),
      tr(context, 'Open 6:00 – 21:00', 'Mở cửa 6:00 – 21:00'),
      '12 Phan Đình Phùng',
      tr(context, 'Sourdough 45.000đ', 'Bánh men 45.000đ'),
    ];
    return Stack(
      children: [
        // The picture: a chalkboard sign.
        Positioned(
          left: 12,
          top: 12,
          child: Container(
            width: 130,
            height: 150,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2F3B33),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF8A6A45), width: 5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _line(context, l, 8, color: const Color(0xFFE9E4D6)),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 17,
          top: lerpDouble(16, 156, scan),
          child: Opacity(
            opacity: scan > 0 && scan < 1 ? 1 : 0,
            child: Container(width: 120, height: 2, color: p.primary),
          ),
        ),
        Positioned(
          left: 158,
          top: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.text_snippet_outlined, size: 11, color: p.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _line(
                      context,
                      tr(context, 'Text in the picture', 'Chữ trong ảnh'),
                      9,
                      bold: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (var k = 0; k < lines.length; k++)
                _fade(
                  _seg(t, .2 + k * .1, .35 + k * .1),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: _line(context, lines[k], 9.5),
                  ),
                  dy: 3,
                ),
              const SizedBox(height: 4),
              _fade(
                _seg(t, .7, .85),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: p.tint,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: _line(
                    context,
                    tr(context, 'Copy text', 'Chép chữ'),
                    9,
                    bold: true,
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

class _Export extends StatelessWidget {
  final double t;
  const _Export(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final items = _items(context);
    final fan = _seg(t, .2, .7);
    Widget page(int k) => Container(
      width: 96,
      height: 136,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (k == 0) ...[
            Expanded(child: _Pic(2, radius: 0)),
            const SizedBox(height: 5),
            Text(
              tr(context, 'A week in Đà Lạt', 'Một tuần ở Đà Lạt'),
              maxLines: 2,
              style: _text(
                context,
                10,
                serif: true,
                color: const Color(0xFF1F1F1F),
              ),
            ),
            _line(
              context,
              tr(context, '12 places · 3 days', '12 địa điểm · 3 ngày'),
              6.5,
              color: const Color(0xFF6B6B6B),
            ),
          ] else
            for (final it in items.skip(k * 2).take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 22,
                      width: double.infinity,
                      child: _Pic(it.$3, radius: 2),
                    ),
                    const SizedBox(height: 2),
                    _line(
                      context,
                      it.$1,
                      6.5,
                      bold: true,
                      color: const Color(0xFF1F1F1F),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        for (final k in [2, 1, 0])
          Transform.translate(
            offset: Offset((k - 1) * 92 * fan + (k == 0 ? -1 : 0), 0),
            child: Transform.rotate(angle: (k - 1) * .06 * fan, child: page(k)),
          ),
        Positioned(
          right: 10,
          bottom: 8,
          child: _fade(
            _seg(t, .75, .9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: p.tint,
                borderRadius: BorderRadius.circular(4),
              ),
              child: _line(context, 'PDF', 9, bold: true),
            ),
          ),
        ),
      ],
    );
  }
}
