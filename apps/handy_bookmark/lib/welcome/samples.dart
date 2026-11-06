import 'package:handy_ui/kit.dart';
import 'motion.dart';

/// A thing someone might have saved, for the guide's pictures. Never
/// written to the library. Photos: assets/welcome/CREDITS.txt.
class Sample {
  final String asset, source;
  final Color sourceColor;
  final String Function(BuildContext) title;
  const Sample(this.asset, this.source, this.sourceColor, this.title);
}

final samples = <Sample>[
  Sample(
    'assets/welcome/bun-cha.jpg',
    'TikTok',
    const Color(0xFF111111),
    (c) => tr(c, 'Hanoi bún chả, 15 minutes', 'Bún chả Hà Nội 15 phút'),
  ),
  Sample(
    'assets/welcome/hoi-an.jpg',
    'Facebook',
    const Color(0xFF1877F2),
    (c) => tr(c, 'Hội An in three days', 'Hội An 3 ngày 2 đêm'),
  ),
  Sample(
    'assets/welcome/guitars.jpg',
    'YouTube',
    const Color(0xFFD9251D),
    (c) => tr(c, 'Your first guitar chords', 'Học guitar: hợp âm đầu tiên'),
  ),
  Sample(
    'assets/welcome/ga-ha-noi.jpg',
    'Ảnh chụp',
    const Color(0xFF5B5E63),
    (c) => tr(c, 'Night train timetable', 'Lịch tàu đêm Hà Nội – Huế'),
  ),
];

/// The practice video.
final pho = Sample(
  'assets/welcome/pho.jpg',
  'TikTok',
  const Color(0xFF111111),
  (c) => tr(c, 'Family-recipe beef phở', 'Phở bò gia truyền'),
);

/// The source in its own colour, by name (never a logo).
class SourcePill extends StatelessWidget {
  final Sample sample;
  final double size;
  const SourcePill(this.sample, {super.key, this.size = 11});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: size * .7, vertical: size * .25),
    decoration: BoxDecoration(
      color: sample.sourceColor,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      sample.source,
      style: TextStyle(
        color: Colors.white,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    ),
  );
}

/// A saved thing as a card: its photo, the source pill, its title.
class SampleCard extends StatelessWidget {
  final Sample sample;
  final double width;
  final bool faded;
  const SampleCard(
    this.sample, {
    super.key,
    this.width = 196,
    this.faded = false,
  });
  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: GuideColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: GuideColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.asset(sample.asset, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 8),
          SourcePill(sample),
          const SizedBox(height: 6),
          Text(
            sample.title(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: handyFontFamily('Newsreader'),
              fontSize: 16,
              height: 1.15,
              fontWeight: FontWeight.w500,
              color: GuideColors.ink,
            ),
          ),
        ],
      ),
    );
    return faded
        ? ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              .5, .3, .1, 0, 40, //
              .2, .55, .1, 0, 40,
              .2, .3, .35, 0, 40,
              0, 0, 0, .55, 0,
            ]),
            child: card,
          )
        : card;
  }
}
