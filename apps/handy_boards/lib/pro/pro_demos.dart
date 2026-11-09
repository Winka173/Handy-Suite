import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:handy_ui/kit.dart';
import '../covers/cover_art.dart';
import '../design/looks.dart';
import '../design/theme.dart';
import '../design/widget_styles.dart';
import 'pro.dart';

/// Each Pro part acted out by a tiny board made of the app's own pieces
/// (its cards, columns, covers, looks and widget styles), drawn on a fixed
/// 320×180 stage and scaled to fit. `t` runs 0 to 1; t = 1 is the still
/// that explains the part by itself (reduced motion and the list's
/// thumbnails show only that frame).
///
/// The drawing's own text never follows the system text size (it is a
/// picture, scaled as a whole); the demo's label is what is read aloud.
Widget boardsProDemo(BuildContext context, ProFeature f, double t) =>
    MediaQuery.withNoTextScaling(child: _demo(context, f, t));

Widget _demo(BuildContext context, ProFeature f, double t) => FittedBox(
  child: SizedBox(
    width: 320,
    height: 180,
    child: switch (f) {
      ProFeature.templates => _Templates(t),
      ProFeature.covers => _Covers(t),
      ProFeature.looks => _Looks(t),
      ProFeature.automation => _Rule(t),
      ProFeature.export => _Export(t),
      ProFeature.cardTemplates => _CardTemplate(t),
      ProFeature.myWork => _MyWork(t),
      ProFeature.carryOver => _CarryOver(t),
      ProFeature.history => _History(t),
      ProFeature.fields => _Fields(t),
      ProFeature.insights => _Insights(t),
      ProFeature.savedFilters => _SavedFilters(t),
      ProFeature.repeat => _Repeat(t),
      ProFeature.digest => _Digest(t),
      ProFeature.widgetStyles => _WidgetStyles(t),
    },
  ),
);

/// What each demo shows, read aloud in place of the drawing.
String boardsProDemoLabel(BuildContext context, ProFeature f) => switch (f) {
  ProFeature.templates => tr(
    context,
    'A template is picked and its board opens with example cards.',
    'Chọn một mẫu, bảng mở ra kèm thẻ ví dụ.',
  ),
  ProFeature.covers => tr(
    context,
    'A card tries one cover after another.',
    'Một thẻ thử lần lượt từng ảnh bìa.',
  ),
  ProFeature.looks => tr(
    context,
    'A board changes its ground from look to look.',
    'Một bảng đổi nền qua từng giao diện.',
  ),
  ProFeature.automation => tr(
    context,
    'The last subtask is ticked and the card moves to Done by itself.',
    'Tick việc con cuối, thẻ tự chuyển sang cột Xong.',
  ),
  ProFeature.export => tr(
    context,
    'A board becomes a poster saved as a picture or PDF.',
    'Bảng thành một tấm poster, lưu thành ảnh hoặc PDF.',
  ),
  ProFeature.cardTemplates => tr(
    context,
    'A saved card template makes a new card with its subtasks.',
    'Một mẫu thẻ đã lưu tạo thẻ mới kèm việc con.',
  ),
  ProFeature.myWork => tr(
    context,
    'Cards from three boards gather in one Today list.',
    'Thẻ của ba bảng gom vào một danh sách Hôm nay.',
  ),
  ProFeature.carryOver => tr(
    context,
    'Yesterday\'s unfinished card moves to today; its due date stays.',
    'Thẻ chưa xong hôm qua chuyển về hôm nay; hạn nộp giữ nguyên.',
  ),
  ProFeature.history => tr(
    context,
    'What happened on a board appears line by line, newest first.',
    'Những gì đã xảy ra trên bảng hiện từng dòng, mới nhất trước.',
  ),
  ProFeature.fields => tr(
    context,
    'A card gains fields of its own: budget, link, paid, visit day.',
    'Thẻ có thêm trường riêng: ngân sách, link, đã trả, ngày đến.',
  ),
  ProFeature.insights => tr(
    context,
    'Bars grow for what each category finished and what is late.',
    'Thanh của từng nhóm dài ra theo số việc xong và trễ.',
  ),
  ProFeature.savedFilters => tr(
    context,
    'A saved filter is tapped and only matching cards stay.',
    'Chạm một bộ lọc đã lưu, chỉ còn thẻ khớp.',
  ),
  ProFeature.repeat => tr(
    context,
    'A finished monthly card comes back for next month.',
    'Thẻ hằng tháng đã xong tự quay lại cho tháng sau.',
  ),
  ProFeature.digest => tr(
    context,
    'A morning notification sums up every board.',
    'Thông báo buổi sáng tóm tắt mọi bảng.',
  ),
  ProFeature.widgetStyles => tr(
    context,
    'A home-screen widget changes style.',
    'Widget màn hình chính đổi kiểu.',
  ),
};

/// 0 before [a], 1 after [b], eased between.
double _seg(double t, double a, double b) =>
    Curves.easeInOutCubic.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

TextStyle _text(
  BuildContext context,
  double size, {
  Color? color,
  bool bold = false,
}) => TextStyle(
  fontSize: size,
  height: 1.2,
  color: color ?? BoardsPalette.of(context).ink,
  fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
  fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
);

/// A card as the board draws it: white, a category dot, its title, and
/// whatever else the demo needs under it.
class _Card extends StatelessWidget {
  final String title;
  final int? hue;
  final List<Widget> under;
  final double width;
  final Color? fill;
  const _Card(
    this.title, {
    this.hue,
    this.under = const [],
    this.width = 82,
    this.fill,
  });
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    return Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fill ?? p.surface,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (hue != null) ...[
                      HandyDot(hue!, size: 6),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _text(context, 8.5, bold: true),
                      ),
                    ),
                  ],
                ),
                ...under,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  final String title;
  final List<Widget> cards;
  final double width;
  final Color? color;
  const _Column(this.title, this.cards, {this.width = 92, this.color});
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: color ?? p.raised,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
            child: Text(
              title,
              maxLines: 1,
              style: _text(context, 8, color: p.muted, bold: true),
            ),
          ),
          for (final c in cards) ...[c, const SizedBox(height: 4)],
        ],
      ),
    );
  }
}

/// A small line of muted text under a card title.
Widget _sub(BuildContext context, String s, {Color? color}) => Padding(
  padding: const EdgeInsets.only(top: 3),
  child: Text(
    s,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: _text(context, 7.5, color: color ?? BoardsPalette.of(context).muted),
  ),
);

Widget _fade(double v, Widget child, {double dy = 8, double dx = 0}) => Opacity(
  opacity: v,
  child: Transform.translate(
    offset: Offset(dx * (1 - v), dy * (1 - v)),
    child: child,
  ),
);

/// A caption along the stage's foot, saying the rule the demo plays.
Widget _caption(BuildContext context, IconData icon, String s) {
  final p = BoardsPalette.of(context);
  return Positioned(
    left: 10,
    right: 10,
    bottom: 8,
    child: Row(
      children: [
        Icon(icon, size: 11, color: p.primary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            s,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(context, 8.5, color: p.ink),
          ),
        ),
      ],
    ),
  );
}

class _Templates extends StatelessWidget {
  final double t;
  const _Templates(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    const covers = [
      'study.notebook-grid',
      'work.sticky-plan',
      'travel.coastal-route',
    ];
    final names = [
      tr(context, 'Thesis', 'Luận văn'),
      tr(context, 'Sprint', 'Sprint'),
      tr(context, 'Trip', 'Chuyến đi'),
    ];
    final pick = _seg(t, .08, .3);
    final open = [
      for (var i = 0; i < 5; i++) _seg(t, .38 + i * .08, .55 + i * .08),
    ];
    return Stack(
      children: [
        for (var i = 0; i < 3; i++)
          Positioned(
            left: 10 + i * 104.0,
            top: 8,
            child: SizedBox(
              width: 92,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 40,
                      width: 92,
                      child: CoverArt(covers[i]),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(names[i], style: _text(context, 8, bold: true)),
                ],
              ),
            ),
          ),
        // The selection ring hops from the first template to the second.
        Positioned(
          left: lerpDouble(8, 112, pick),
          top: 6,
          child: Container(
            width: 96,
            height: 44,
            decoration: BoxDecoration(
              border: Border.all(color: p.primary, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        Positioned(
          left: 10,
          top: 70,
          right: 10,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fade(
                open[0],
                _Column(tr(context, 'Backlog', 'Việc chờ'), [
                  _fade(
                    open[1],
                    _Card(tr(context, 'User interviews', 'Phỏng vấn'), hue: 0),
                  ),
                  _fade(
                    open[2],
                    _Card(tr(context, 'Pricing page', 'Trang giá'), hue: 3),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              _fade(
                open[1],
                _Column(tr(context, 'This sprint', 'Sprint này'), [
                  _fade(
                    open[3],
                    _Card(tr(context, 'Sign-up flow', 'Luồng đăng ký'), hue: 0),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              _fade(
                open[2],
                _Column(tr(context, 'Done', 'Xong'), [
                  _fade(
                    open[4],
                    _Card(tr(context, 'Kick-off', 'Họp khởi động'), hue: 5),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Covers extends StatelessWidget {
  final double t;
  const _Covers(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    const ids = [
      'home.arched-window',
      'creative.paint-palette',
      'travel.night-train',
      'wellness.morning-leaves',
    ];
    final at = math.min(3, (t * 4).floor());
    return Stack(
      children: [
        Positioned(
          left: 14,
          top: 14,
          child: Container(
            width: 150,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 92,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: SizedBox.expand(
                      key: ValueKey(at),
                      child: CoverArt(ids[at]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    tr(context, 'Living room ideas', 'Ý tưởng phòng khách'),
                    style: _text(context, 10, bold: true),
                  ),
                ),
              ],
            ),
          ),
        ),
        for (var i = 0; i < 4; i++)
          Positioned(
            left: 182 + (i % 2) * 66.0,
            top: 14 + (i ~/ 2) * 50.0,
            child: Container(
              width: 60,
              height: 42,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: i == at ? p.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: CoverArt(ids[i]),
            ),
          ),
        Positioned(
          left: 182,
          top: 118,
          child: Text(
            tr(context, 'Every cover family', 'Mọi bộ ảnh bìa'),
            style: _text(context, 8.5, color: p.muted),
          ),
        ),
      ],
    );
  }
}

class _Looks extends StatelessWidget {
  final double t;
  const _Looks(this.t);
  @override
  Widget build(BuildContext context) {
    final picks = [
      for (final id in ['paper', 'sage', 'blueprint', 'blush'])
        boardLooks.firstWhere(
          (l) => l.id == id,
          orElse: () => boardLooks.first,
        ),
    ];
    final pos = t * (picks.length - 1);
    final i = math.min(picks.length - 2, pos.floor());
    final f = Curves.easeInOut.transform((pos - i).clamp(0.0, 1.0));
    final page = Color.lerp(
      picks[i].page(context),
      picks[i + 1].page(context),
      f,
    )!;
    final column = Color.lerp(
      picks[i].column(context),
      picks[i + 1].column(context),
      f,
    )!;
    final name = picks[(pos + .5).floor().clamp(0, picks.length - 1)];
    return Container(
      color: page,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tr(context, 'Garden plan', 'Kế hoạch vườn'),
                style: _text(context, 11, bold: true),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BoardsPalette.of(context).surface,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  tr(context, name.nameEn, name.nameVi),
                  style: _text(context, 8.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Column(tr(context, 'To sow', 'Cần gieo'), [
                _Card(tr(context, 'Basil', 'Húng quế'), hue: 2),
                _Card(tr(context, 'Tomatoes', 'Cà chua'), hue: 0),
              ], color: column),
              const SizedBox(width: 8),
              _Column(tr(context, 'Growing', 'Đang lớn'), [
                _Card(tr(context, 'Mint', 'Bạc hà'), hue: 2),
              ], color: column),
              const SizedBox(width: 8),
              _Column(tr(context, 'Picked', 'Đã hái'), [
                _Card(tr(context, 'Chillies', 'Ớt'), hue: 0),
              ], color: column),
            ],
          ),
        ],
      ),
    );
  }
}

/// A subtask's checkbox, filled as [on] goes to 1.
Widget _box(BuildContext context, double on) {
  final p = BoardsPalette.of(context);
  return Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      color: Color.lerp(Colors.transparent, p.primary, on),
      border: Border.all(color: on > .5 ? p.primary : p.control, width: 1),
      borderRadius: BorderRadius.circular(2),
    ),
    child: on > .5 ? Icon(Icons.check, size: 7, color: p.onPrimary) : null,
  );
}

Widget _tick(BuildContext context, String s, double on) => Padding(
  padding: const EdgeInsets.only(top: 3),
  child: Row(
    children: [
      _box(context, on),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          s,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _text(context, 7.5, color: BoardsPalette.of(context).muted),
        ),
      ),
    ],
  ),
);

class _Rule extends StatelessWidget {
  final double t;
  const _Rule(this.t);
  @override
  Widget build(BuildContext context) {
    final ticks = [_seg(t, .08, .14), _seg(t, .22, .28), _seg(t, .36, .42)];
    final move = _seg(t, .52, .78);
    final card = _Card(
      tr(context, 'Book the venue', 'Đặt địa điểm'),
      hue: 4,
      width: 128,
      under: [
        _tick(
          context,
          tr(context, 'Call three places', 'Gọi ba nơi'),
          ticks[0],
        ),
        _tick(context, tr(context, 'Compare prices', 'So giá'), ticks[1]),
        _tick(context, tr(context, 'Pay the deposit', 'Đặt cọc'), ticks[2]),
      ],
    );
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 10,
          child: SizedBox(
            height: 138,
            child: _Column(
              tr(context, 'Doing', 'Đang làm'),
              const [],
              width: 140,
            ),
          ),
        ),
        Positioned(
          left: 166,
          top: 10,
          child: SizedBox(
            height: 138,
            child: _Column(tr(context, 'Done', 'Xong'), [
              _Card(
                tr(context, 'Guest list', 'Danh sách khách'),
                hue: 4,
                width: 128,
              ),
            ], width: 140),
          ),
        ),
        Positioned(
          left: lerpDouble(18, 172, move),
          top: lerpDouble(30, 58, move),
          child: card,
        ),
        _caption(
          context,
          Icons.bolt_outlined,
          tr(
            context,
            'Last subtask ticked → move to Done',
            'Tick việc con cuối → chuyển sang Xong',
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
    final p = BoardsPalette.of(context);
    final rise = _seg(t, .15, .55);
    final tags = _seg(t, .65, .85);
    Widget bar(double w, int hue) => Container(
      margin: const EdgeInsets.only(bottom: 3),
      height: 8,
      width: w,
      decoration: BoxDecoration(
        color: HandyPalette.of(context, hue).tint,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 16,
          child: Opacity(
            opacity: 1 - rise * .5,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Column(tr(context, 'Plan', 'Lên ý'), [
                  _Card(tr(context, 'Teaser', 'Teaser'), hue: 1, width: 54),
                ], width: 64),
                const SizedBox(width: 5),
                _Column(tr(context, 'Make', 'Làm'), [
                  _Card(tr(context, 'Trailer', 'Trailer'), hue: 3, width: 54),
                ], width: 64),
              ],
            ),
          ),
        ),
        Positioned(
          left: 160,
          top: 8,
          child: Opacity(
            opacity: rise,
            child: Transform.scale(
              scale: lerpDouble(.7, 1, rise),
              child: Container(
                width: 112,
                height: 162,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 34,
                      width: double.infinity,
                      child: CoverArt('events.stage-curtain'),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(context, 'Spring launch', 'Ra mắt mùa xuân'),
                              style: _text(
                                context,
                                10,
                                bold: true,
                                color: const Color(0xFF1F2329),
                              ),
                            ),
                            Text(
                              tr(
                                context,
                                '12 cards · 5 done',
                                '12 thẻ · 5 xong',
                              ),
                              style: _text(
                                context,
                                7,
                                color: const Color(0xFF555B66),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    bar(28, 1),
                                    bar(28, 3),
                                    bar(28, 1),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                Column(children: [bar(28, 3), bar(28, 5)]),
                                const SizedBox(width: 4),
                                Column(children: [bar(28, 5)]),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr(context, 'Done each week', 'Xong mỗi tuần'),
                              style: _text(
                                context,
                                6.5,
                                color: const Color(0xFF555B66),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (final h in <double>[
                                  6,
                                  10,
                                  8,
                                  14,
                                  12,
                                  18,
                                  16,
                                  22,
                                ])
                                  Container(
                                    margin: const EdgeInsets.only(right: 3),
                                    width: 9,
                                    height: h,
                                    color: const Color(0xFFB53C0A),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 282,
          top: 30,
          child: _fade(
            tags,
            Column(
              children: [
                for (final s in ['PNG', 'PDF'])
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: p.tint,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      s,
                      style: _text(context, 8, color: p.ink, bold: true),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CardTemplate extends StatelessWidget {
  final double t;
  const _CardTemplate(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final press = _seg(t, .1, .2) - _seg(t, .22, .3);
    final drop = _seg(t, .32, .55);
    final subs = [
      for (var i = 0; i < 3; i++) _seg(t, .58 + i * .08, .68 + i * .08),
    ];
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 10,
          child: Transform.scale(
            scale: 1 - press * .06,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Color.lerp(p.surface, p.tint, _seg(t, .1, .2)),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                children: [
                  Icon(Icons.content_copy_outlined, size: 10, color: p.primary),
                  const SizedBox(width: 4),
                  Text(
                    tr(context, 'Weekly review', 'Xem lại tuần'),
                    style: _text(context, 9, bold: true),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: 40,
          child: SizedBox(
            height: 132,
            child: _Column(tr(context, 'This week', 'Tuần này'), [
              _Card(tr(context, 'Gym plan', 'Lịch tập'), hue: 2, width: 160),
              _fade(
                drop,
                _Card(
                  tr(context, 'Weekly review', 'Xem lại tuần'),
                  hue: 6,
                  width: 160,
                  under: [
                    _fade(
                      subs[0],
                      _tick(
                        context,
                        tr(context, 'Clear the inbox', 'Dọn hộp thư'),
                        0,
                      ),
                      dy: 3,
                    ),
                    _fade(
                      subs[1],
                      _tick(
                        context,
                        tr(context, 'Check the budget', 'Xem ngân sách'),
                        0,
                      ),
                      dy: 3,
                    ),
                    _fade(
                      subs[2],
                      _tick(
                        context,
                        tr(context, 'Plan next week', 'Lên kế hoạch tuần sau'),
                        0,
                      ),
                      dy: 3,
                    ),
                  ],
                ),
                dy: -16,
              ),
            ], width: 172),
          ),
        ),
        Positioned(
          left: 200,
          top: 46,
          right: 10,
          child: Text(
            tr(
              context,
              'One tap makes the card with its subtasks, note and category.',
              'Một chạm tạo thẻ kèm việc con, ghi chú và nhóm.',
            ),
            style: _text(context, 9, color: p.muted),
          ),
        ),
      ],
    );
  }
}

class _MyWork extends StatelessWidget {
  final double t;
  const _MyWork(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final boards = [
      (
        tr(context, 'Thesis', 'Luận văn'),
        tr(context, 'Read chapter 3', 'Đọc chương 3'),
        0,
      ),
      (
        tr(context, 'Home', 'Nhà'),
        tr(context, 'Fix the tap', 'Sửa vòi nước'),
        2,
      ),
      (
        tr(context, 'Launch', 'Ra mắt'),
        tr(context, 'Send the email', 'Gửi email'),
        5,
      ),
    ];
    return Stack(
      children: [
        for (var i = 0; i < 3; i++)
          Positioned(
            left: 10,
            top: 8 + i * 54.0,
            child: Opacity(
              opacity: 1 - _seg(t, .15 + i * .15, .35 + i * .15) * .55,
              child: SizedBox(
                width: 112,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HandyDot(boards[i].$3, size: 6),
                        const SizedBox(width: 4),
                        Text(
                          boards[i].$1,
                          style: _text(context, 8, color: p.muted, bold: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _Card(boards[i].$2, width: 112),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: 138,
          top: 8,
          right: 10,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'Today', 'Hôm nay'),
                  style: _text(context, 11, bold: true),
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < 3; i++)
                  _fade(
                    _seg(t, .15 + i * .15, .35 + i * .15),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        children: [
                          _box(context, 0),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  boards[i].$2,
                                  style: _text(context, 9, bold: true),
                                ),
                                Text(
                                  boards[i].$1,
                                  style: _text(context, 7.5, color: p.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    dx: -24,
                    dy: 0,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CarryOver extends StatelessWidget {
  final double t;
  const _CarryOver(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final days = tr(
      context,
      'Mon Tue Wed Thu Fri Sat Sun',
      'T2 T3 T4 T5 T6 T7 CN',
    ).split(' ');
    const today = 2, due = 4;
    final move = _seg(t, .3, .65);
    const cell = 42.0, left = 13.0;
    return Stack(
      children: [
        for (var i = 0; i < 7; i++)
          Positioned(
            left: left + i * cell,
            top: 10,
            child: Container(
              width: cell - 4,
              height: 112,
              decoration: BoxDecoration(
                color: i == today ? p.tint : p.raised,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.only(top: 5),
              alignment: Alignment.topCenter,
              child: Text(
                days[i],
                style: _text(
                  context,
                  8,
                  bold: i == today,
                  color: i == today ? p.ink : p.muted,
                ),
              ),
            ),
          ),
        Positioned(
          left: left + due * cell + 4,
          top: 90,
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 10, color: p.ink),
              const SizedBox(width: 2),
              Text(
                tr(context, 'Due', 'Hạn'),
                style: _text(context, 8, bold: true),
              ),
            ],
          ),
        ),
        Positioned(
          left: lerpDouble(left + 1 * cell - 6, left + today * cell - 6, move),
          top: 34,
          child: _Card(
            tr(context, 'Draft intro', 'Viết mở bài'),
            hue: 0,
            width: 50,
            fill: Color.lerp(p.warningTint, p.surface, move),
          ),
        ),
        _caption(
          context,
          Icons.event_repeat_outlined,
          tr(
            context,
            'Left behind → today. The due date stays.',
            'Việc còn tồn → hôm nay. Hạn nộp giữ nguyên.',
          ),
        ),
      ],
    );
  }
}

class _History extends StatelessWidget {
  final double t;
  const _History(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final rows = [
      (
        '09:12',
        tr(context, 'Draft intro → Done', 'Viết mở bài → Xong'),
        Icons.check_circle_outline,
      ),
      (
        '08:40',
        tr(context, 'Due date set: Fri', 'Đặt hạn: T6'),
        Icons.flag_outlined,
      ),
      (
        tr(context, 'Yesterday', 'Hôm qua'),
        tr(context, 'Category: Writing', 'Nhóm: Viết'),
        Icons.label_outline,
      ),
      (
        tr(context, 'Yesterday', 'Hôm qua'),
        tr(context, 'Card made: Draft intro', 'Tạo thẻ: Viết mở bài'),
        Icons.add_circle_outline,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++)
            _fade(
              _seg(t, .08 + i * .14, .28 + i * .14),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 58,
                      child: Text(
                        rows[i].$1,
                        style: _text(context, 8.5, color: p.muted),
                      ),
                    ),
                    Icon(
                      rows[i].$3,
                      size: 13,
                      color: i == 0 ? p.primary : p.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rows[i].$2,
                        style: _text(context, 10, bold: i == 0),
                      ),
                    ),
                  ],
                ),
              ),
              dy: -8,
            ),
        ],
      ),
    );
  }
}

class _Fields extends StatelessWidget {
  final double t;
  const _Fields(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final rows = [
      (
        Icons.payments_outlined,
        tr(context, 'Budget', 'Ngân sách'),
        '2.000.000đ',
      ),
      (Icons.link, 'Link', 'nhahang.vn'),
      (
        Icons.check_box_outlined,
        tr(context, 'Paid', 'Đã trả'),
        tr(context, 'Yes', 'Có'),
      ),
      (
        Icons.event_outlined,
        tr(context, 'Visit', 'Ngày đến'),
        tr(context, 'Fri 14/11', 'T6 14/11'),
      ),
    ];
    return Center(
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const HandyDot(4, size: 7),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    tr(context, 'Book the restaurant', 'Đặt nhà hàng'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(context, 11, bold: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < rows.length; i++)
              _fade(
                _seg(t, .1 + i * .15, .3 + i * .15),
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(
                    children: [
                      Icon(rows[i].$1, size: 11, color: p.muted),
                      const SizedBox(width: 5),
                      SizedBox(
                        width: 64,
                        child: Text(
                          rows[i].$2,
                          style: _text(context, 9, color: p.muted),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          rows[i].$3,
                          textAlign: TextAlign.end,
                          style: _text(context, 9, bold: true),
                        ),
                      ),
                    ],
                  ),
                ),
                dy: 4,
              ),
          ],
        ),
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  final double t;
  const _Insights(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final rows = [
      (tr(context, 'Writing', 'Viết'), 0, 9, 1),
      (tr(context, 'Research', 'Nghiên cứu'), 3, 6, 0),
      (tr(context, 'Admin', 'Giấy tờ'), 5, 3, 2),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'This week', 'Tuần này'),
            style: _text(context, 11, bold: true),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              children: [
                HandyDot(rows[i].$2, size: 7),
                const SizedBox(width: 5),
                SizedBox(
                  width: 70,
                  child: Text(rows[i].$1, style: _text(context, 9, bold: true)),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: math.max(
                        .02,
                        rows[i].$3 / 10 * _seg(t, .1 + i * .12, .55 + i * .12),
                      ),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: HandyPalette.of(context, rows[i].$2).mark,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 82,
                  child: Text(
                    rows[i].$4 == 0
                        ? tr(
                            context,
                            '${rows[i].$3} done',
                            '${rows[i].$3} xong',
                          )
                        : tr(
                            context,
                            '${rows[i].$3} done · ${rows[i].$4} late',
                            '${rows[i].$3} xong · ${rows[i].$4} trễ',
                          ),
                    textAlign: TextAlign.end,
                    style: _text(
                      context,
                      8.5,
                      color: rows[i].$4 > 0 ? p.danger : p.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SavedFilters extends StatelessWidget {
  final double t;
  const _SavedFilters(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final on = _seg(t, .25, .5);
    final cards = [
      (tr(context, 'Quarterly report', 'Báo cáo quý'), 0, true),
      (tr(context, 'Buy a gift', 'Mua quà'), 2, false),
      (tr(context, 'Team 1:1s', 'Gặp 1:1'), 0, true),
      (tr(context, 'Dentist', 'Nha sĩ'), 5, false),
      (tr(context, 'Budget review', 'Duyệt ngân sách'), 0, true),
    ];
    Widget chip(String s, bool lit) => Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: lit ? Color.lerp(p.surface, p.tint, on) : p.surface,
        border: Border.all(color: lit && on > .5 ? p.primary : p.line),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        s,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _text(context, 8.5, bold: lit),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, size: 12, color: p.muted),
              const SizedBox(width: 5),
              Flexible(
                child: chip(
                  tr(context, 'Work, due this week', 'Công việc, hạn tuần này'),
                  true,
                ),
              ),
              Flexible(child: chip(tr(context, 'Errands', 'Việc vặt'), false)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in cards)
                Opacity(
                  opacity: c.$3 ? 1 : 1 - on,
                  child: _Card(c.$1, hue: c.$2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Repeat extends StatelessWidget {
  final double t;
  const _Repeat(this.t);
  @override
  Widget build(BuildContext context) {
    final back = _seg(t, .3, .62);
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 10,
          child: SizedBox(
            height: 120,
            child: _Column(tr(context, 'To do', 'Cần làm'), [
              _fade(
                back,
                _Card(
                  tr(context, 'Pay rent', 'Trả tiền nhà'),
                  hue: 1,
                  width: 128,
                  under: [
                    _sub(
                      context,
                      tr(
                        context,
                        'Do: 1/12 · every month',
                        'Làm: 1/12 · hằng tháng',
                      ),
                    ),
                  ],
                ),
                dy: 0,
                dx: 60,
              ),
            ], width: 140),
          ),
        ),
        Positioned(
          left: 166,
          top: 10,
          child: SizedBox(
            height: 120,
            child: _Column(tr(context, 'Done', 'Xong'), [
              _Card(
                tr(context, 'Pay rent', 'Trả tiền nhà'),
                hue: 1,
                width: 128,
                under: [_sub(context, tr(context, 'Done 1/11', 'Xong 1/11'))],
              ),
            ], width: 140),
          ),
        ),
        _caption(
          context,
          Icons.repeat,
          tr(
            context,
            'Every month on the 1st, or any rhythm you set',
            'Mùng 1 hằng tháng, hoặc nhịp bạn tự đặt',
          ),
        ),
      ],
    );
  }
}

class _Digest extends StatelessWidget {
  final double t;
  const _Digest(this.t);
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final drop = _seg(t, .05, .25);
    final lines = [
      tr(
        context,
        'Thesis: 2 due today, 1 late',
        'Luận văn: 2 hạn hôm nay, 1 trễ',
      ),
      tr(context, 'Home: fix the tap', 'Nhà: sửa vòi nước'),
      tr(context, 'Launch: 3 this week', 'Ra mắt: 3 việc tuần này'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _fade(
        drop,
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: p.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Handy Boards · 8:00',
                    style: _text(context, 8, color: p.muted),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                tr(context, 'Today on your boards', 'Hôm nay trên các bảng'),
                style: _text(context, 11, bold: true),
              ),
              for (var i = 0; i < lines.length; i++)
                _fade(
                  _seg(t, .3 + i * .12, .45 + i * .12),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(lines[i], style: _text(context, 9.5)),
                  ),
                  dy: 4,
                ),
            ],
          ),
        ),
        dy: -20,
      ),
    );
  }
}

class _WidgetStyles extends StatelessWidget {
  final double t;
  const _WidgetStyles(this.t);
  @override
  Widget build(BuildContext context) {
    final styles = [
      for (final w in widgetStyles)
        if (w.pro) w,
    ];
    final at = math.min(styles.length - 1, (t * styles.length).floor());
    final s = styles[at];
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: s.bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: s.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  tr(context, 'Today', 'Hôm nay'),
                  style: _text(context, 11, bold: true, color: s.ink),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(context, s.nameEn, s.nameVi),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: _text(context, 8, color: s.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            for (final line in [
              tr(context, 'Read chapter 3', 'Đọc chương 3'),
              tr(context, 'Fix the tap', 'Sửa vòi nước'),
              tr(context, 'Send the email', 'Gửi email'),
            ])
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(line, style: _text(context, 9.5, color: s.ink)),
              ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: .4,
                minHeight: 3,
                color: s.accent,
                backgroundColor: s.muted?.withValues(alpha: .25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
