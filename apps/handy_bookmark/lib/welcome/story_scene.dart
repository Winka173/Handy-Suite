import 'package:handy_ui/kit.dart';
import 'motion.dart';
import 'samples.dart';
import '../ui/app_mark.dart';

/// Steps one and two in one picture, so the cards themselves travel:
/// scattered across apps and lost to a search ([gathered] false), then
/// flown into one library, sorted and in colour ([gathered] true).
/// Drawn on a 400 × 560 canvas and scaled to fit.
class StoryScene extends StatelessWidget {
  final bool gathered;
  const StoryScene({super.key, required this.gathered});

  // Where each card rests: scattered (left, top, turn) and gathered.
  static const _scattered = [
    (8.0, 92.0, -.09),
    (196.0, 70.0, .07),
    (24.0, 300.0, .05),
    (204.0, 286.0, -.06),
  ];
  static const _gathered = [
    (28.0, 150.0, 0.0),
    (210.0, 150.0, 0.0),
    (28.0, 352.0, 0.0),
    (210.0, 352.0, 0.0),
  ];

  @override
  Widget build(BuildContext context) {
    final time = moves(context)
        ? const Duration(milliseconds: 780)
        : Duration.zero;
    return ExcludeSemantics(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: FittedBox(
          child: SizedBox(
            width: 400,
            height: 560,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The library the cards gather into.
                AnimatedOpacity(
                  duration: time,
                  opacity: gathered ? 1 : 0,
                  child: AnimatedScale(
                    duration: time,
                    curve: Curves.easeOutBack,
                    scale: gathered ? 1 : .92,
                    child: _Library(gathered: gathered),
                  ),
                ),
                if (!gathered)
                  Positioned(
                    left: 40,
                    right: 40,
                    top: 8,
                    child: Reveal(from: .55, to: .8, child: _LostSearch()),
                  ),
                for (var i = 0; i < samples.length; i++)
                  AnimatedPositioned(
                    duration: time,
                    curve: Curves.easeOutBack,
                    left: (gathered ? _gathered : _scattered)[i].$1,
                    top: (gathered ? _gathered : _scattered)[i].$2,
                    child: AnimatedRotation(
                      duration: time,
                      curve: Curves.easeOut,
                      turns: (gathered ? _gathered : _scattered)[i].$3 / 6.283,
                      child: gathered
                          ? SampleCard(samples[i], width: 162)
                          : Reveal(
                              from: i * .08,
                              to: .3 + i * .08,
                              rise: 60,
                              scale: .7,
                              child: _FadeWhenLost(
                                lost: true,
                                child: SampleCard(samples[i], width: 176),
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Late in step one the scattered cards go grey: saved, then lost.
class _FadeWhenLost extends StatelessWidget {
  final bool lost;
  final Widget child;
  const _FadeWhenLost({required this.lost, required this.child});
  @override
  Widget build(BuildContext context) {
    final clock = Beat.of(context);
    return AnimatedBuilder(
      animation: clock,
      builder: (context, child) {
        final t = lost
            ? Curves.easeInOut.transform(
                ((clock.value - .62) / .3).clamp(0.0, 1.0),
              )
            : 0.0;
        return Opacity(
          opacity: 1 - .45 * t,
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(_grey(t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  static List<double> _grey(double t) {
    // Blend from the identity matrix to greyscale.
    const g = [
      .33, .59, .11, 0, 0, //
      .33, .59, .11, 0, 0,
      .33, .59, .11, 0, 0,
      0, 0, 0, 1, 0,
    ];
    const id = [
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ];
    return [for (var i = 0; i < 20; i++) id[i] + (g[i] - id[i]) * t];
  }
}

/// A search that finds nothing: the cost of saving everywhere.
class _LostSearch extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: GuideColors.card,
      borderRadius: BorderRadius.circular(999),
      boxShadow: const [
        BoxShadow(
          color: GuideColors.shadow,
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        const Icon(Icons.search, size: 18, color: GuideColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tr(context, 'train timetable…', 'lịch tàu…'),
            style: const TextStyle(fontSize: 15, color: GuideColors.ink),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFCE8E6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            tr(context, '0 results', '0 kết quả'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9F1C12),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The library the cards fly into: the app's name, its kind chips and
/// two collections the cards sort into.
class _Library extends StatelessWidget {
  final bool gathered;
  const _Library({required this.gathered});
  @override
  Widget build(BuildContext context) => Container(
    width: 400,
    height: 560,
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    decoration: BoxDecoration(
      color: GuideColors.card,
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(
          color: GuideColors.shadow,
          blurRadius: 30,
          offset: Offset(0, 14),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const AppMark(size: 30, radius: 8),
            const SizedBox(width: 10),
            Text(
              'Handy Bookmark',
              style: TextStyle(
                fontFamily: handyFontFamily('Newsreader'),
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: GuideColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, label) in [
              tr(context, 'All 4', 'Tất cả 4'),
              tr(context, 'Links 3', 'Link 3'),
              tr(context, 'Pictures 1', 'Ảnh 1'),
            ].indexed) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: i == 0 ? GuideColors.teal : GuideColors.paper,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: i == 0 ? Colors.white : GuideColors.ink,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        _shelf(tr(context, 'Good food · Trips', 'Món ngon · Du lịch')),
        const Spacer(),
      ],
    ),
  );

  Widget _shelf(String text) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: GuideColors.teal,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: GuideColors.muted,
        ),
      ),
    ],
  );
}
