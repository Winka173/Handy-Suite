import 'package:handy_ui/kit.dart';
import 'motion.dart';
import 'samples.dart';

/// Finding it again, drawn as the app's own search: its bar, the round
/// field, the results' heading and count, and the rows in one card. The
/// search types "pho bo" without accents and the list narrows to the saved
/// video.
class FindScene extends StatelessWidget {
  /// [bare]: the real-size screen of a phone guide, with [top] left clear.
  final bool bare;
  final double top;
  const FindScene({super.key, this.bare = false, this.top = 48});
  @override
  Widget build(BuildContext context) {
    final clock = Beat.of(context);
    const query = 'pho bo';
    // Three saves on screen, so the keyboard fits under them.
    final all = [samples[0], pho, samples[1]];
    return PhoneFrame(
      bare: bare,
      // Bar, field, heading, three rows and the keyboard.
      minHeight: top + 560,
      screen: ColoredBox(
        color: GuideColors.paper,
        child: AnimatedBuilder(
          animation: clock,
          builder: (context, _) {
            final typed = ((clock.value - .15) / .4).clamp(0.0, 1.0);
            final shown = query.substring(0, (query.length * typed).round());
            final narrowed = clock.value > .62;
            final focus = Curves.easeOut.transform(
              ((clock.value - .7) / .25).clamp(0.0, 1.0),
            );
            final rows = [
              for (final s in all)
                if (!narrowed || s == pho) s,
            ];
            return Padding(
              padding: EdgeInsets.fromLTRB(16, top, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.arrow_back, color: GuideColors.ink),
                      const SizedBox(width: 20),
                      Text(
                        tr(context, 'Search', 'Tìm'),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: GuideColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: GuideColors.card,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: GuideColors.teal, width: 2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: GuideColors.muted),
                        const SizedBox(width: 12),
                        Text(
                          shown,
                          style: const TextStyle(
                            fontSize: 16,
                            color: GuideColors.ink,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 20,
                          color: GuideColors.teal,
                        ),
                        const Spacer(),
                        if (shown.isNotEmpty)
                          const Icon(
                            Icons.close,
                            size: 20,
                            color: GuideColors.muted,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr(context, 'All items', 'Tất cả mục'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: GuideColors.ink,
                    ),
                  ),
                  Text(
                    tr(
                      context,
                      rows.length == 1 ? '1 result' : '${rows.length} results',
                      '${rows.length} kết quả',
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: GuideColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSize(
                    duration: moves(context)
                        ? const Duration(milliseconds: 260)
                        : Duration.zero,
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: Container(
                      decoration: BoxDecoration(
                        color: GuideColors.card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (final (i, s) in rows.indexed) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                indent: 76,
                                color: Color(0xFFE8ECEF),
                              ),
                            _Row(sample: s, focus: s == pho ? focus : 0),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _Keyboard(
                    pressed: shown.isEmpty || typed >= 1
                        ? null
                        : shown[shown.length - 1],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A plain keyboard under the search, the key just typed lit.
class _Keyboard extends StatelessWidget {
  final String? pressed;
  const _Keyboard({required this.pressed});
  @override
  Widget build(BuildContext context) {
    Widget key(String k, {double flex = 1}) => Expanded(
      flex: (flex * 10).round(),
      child: Container(
        margin: const EdgeInsets.all(2.5),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pressed == k || (k == '␣' && pressed == ' ')
              ? GuideColors.teal
              : GuideColors.card,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          k == '␣' ? '' : k,
          style: TextStyle(
            fontSize: 16,
            color: pressed == k ? Colors.white : GuideColors.ink,
          ),
        ),
      ),
    );
    Widget row(String keys, {double inset = 0}) => Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Row(children: [for (final k in keys.split('')) key(k)]),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(3, 6, 3, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE4E6E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          row('qwertyuiop'),
          row('asdfghjkl', inset: 14),
          row('zxcvbnm', inset: 36),
          Row(
            children: [
              key('?123', flex: 1.5),
              key('␣', flex: 6),
              key('↵', flex: 1.5),
            ],
          ),
        ],
      ),
    );
  }
}

/// A result as the app lists it: picture, title, the collection's dot with
/// its name and the site, and the row's menu. [focus] lights the match.
class _Row extends StatelessWidget {
  final Sample sample;
  final double focus;
  const _Row({required this.sample, required this.focus});
  @override
  Widget build(BuildContext context) {
    final travel = sample.source == 'Facebook';
    final (place, color) = travel
        ? (tr(context, 'Trips', 'Du lịch'), const Color(0xFF2B8A3E))
        : (tr(context, 'Good food', 'Món ngon'), const Color(0xFFD9480F));
    final site = '${sample.source.toLowerCase()}.com';
    return ColoredBox(
      color: Color.lerp(GuideColors.card, GuideColors.tint, focus * .7)!,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                sample.asset,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sample.title(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: GuideColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$place · $site',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: GuideColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: 40,
              child: Icon(Icons.more_horiz, color: GuideColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
