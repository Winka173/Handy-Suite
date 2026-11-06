import 'package:handy_ui/kit.dart';
import 'motion.dart';
import 'samples.dart';

/// Finding it again: the search types "pho bo" without accents and the
/// list narrows to the saved video, which offers to open the original.
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
      // Search, three saves and the keyboard.
      minHeight: top + 540,
      screen: ColoredBox(
        color: GuideColors.paper,
        child: AnimatedBuilder(
          animation: clock,
          builder: (context, _) {
            final typed = ((clock.value - .15) / .4).clamp(0.0, 1.0);
            final shown = query.substring(0, (query.length * typed).round());
            final narrowed = clock.value > .62;
            final focus = Curves.easeOutBack.transform(
              ((clock.value - .7) / .25).clamp(0.0, 1.0),
            );
            return Padding(
              padding: EdgeInsets.fromLTRB(16, top, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: GuideColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: GuideColors.teal, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: GuideColors.teal),
                        const SizedBox(width: 10),
                        Text(
                          shown,
                          style: const TextStyle(
                            fontSize: 17,
                            color: GuideColors.ink,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 20,
                          color: GuideColors.teal,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final s in all)
                    AnimatedSize(
                      duration: moves(context)
                          ? const Duration(milliseconds: 260)
                          : Duration.zero,
                      curve: Curves.easeOut,
                      child: narrowed && s != pho
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _Row(
                                sample: s,
                                focus: s == pho ? focus : 0,
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

class _Row extends StatelessWidget {
  final Sample sample;
  final double focus;
  const _Row({required this.sample, required this.focus});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: GuideColors.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Color.lerp(
          const Color(0xFFE6E8EA),
          GuideColors.teal,
          focus.clamp(0, 1),
        )!,
        width: 1.5,
      ),
      boxShadow: const [
        BoxShadow(
          color: GuideColors.shadow,
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                sample.asset,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sample.title(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: GuideColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SourcePill(sample),
                ],
              ),
            ),
          ],
        ),
        if (focus > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Transform.scale(
              scale: focus.clamp(0, 1.2),
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: GuideColors.teal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.open_in_new,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr(context, 'Open in TikTok', 'Mở trong TikTok'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// The weekly nudge as it would arrive: a count, never a title.
class NudgeScene extends StatelessWidget {
  final bool bare;
  final double top;
  const NudgeScene({super.key, this.bare = false, this.top = 48});
  @override
  Widget build(BuildContext context) => PhoneFrame(
    bare: bare,
    minHeight: 480,
    screen: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/welcome/hoi-an.jpg', fit: BoxFit.cover),
        const ColoredBox(color: Color(0x73000000)),
        Positioned(
          top: top + 22,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                tr(context, 'Sunday', 'Chủ Nhật'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Text(
                '19:00',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.w300,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: top + 182,
          left: 14,
          right: 14,
          child: Reveal(
            from: .35,
            to: .75,
            rise: -40,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xF2FFFFFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: GuideColors.teal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bookmark,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Handy Bookmark',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              tr(context, 'now', 'bây giờ'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: GuideColors.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(
                            context,
                            '5 things you saved recently are still waiting.',
                            '5 mục bạn lưu gần đây còn chưa xem.',
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: GuideColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
