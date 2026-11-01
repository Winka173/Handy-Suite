import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';

String _clock(int ms) {
  final sign = ms < 0 ? '−' : '';
  ms = ms.abs();
  final h = ms ~/ 3600000, m = ms ~/ 60000 % 60, s = ms ~/ 1000 % 60;
  final rest = (ms % 1000).toString().padLeft(3, '0');
  String two(int n) => n.toString().padLeft(2, '0');
  return '$sign${h > 0 ? '${two(h)}:' : ''}${two(m)}:${two(s)}.$rest';
}

/// The first lines, when they appear now and after the shift. The answer
/// to "does the timing fit yet?".
class CuePreview extends StatelessWidget {
  final List<SubtitleCue> cues;
  final int offset;
  final String? problem;
  const CuePreview({
    super.key,
    required this.cues,
    required this.offset,
    this.problem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    if (problem != null) {
      return HandyNotice(
        problem!,
        tone: HandyTone.error,
        key: const Key('subtitle-problem'),
      );
    }
    if (cues.isEmpty) {
      return Text(
        tr(
          context,
          'Open an SRT or WebVTT file, or paste one, to see its lines here. Up to 1 MB and 10,000 lines.',
          'Mở hoặc dán một tệp SRT hay WebVTT để xem các câu ở đây. Tối đa 1 MB và 10.000 câu.',
        ),
        style: theme.textTheme.bodyMedium,
      );
    }
    final figures = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            context,
            '${cues.length} lines · first at ${_clock(cues.first.startMs + offset)}',
            '${cues.length} câu · câu đầu lúc ${_clock(cues.first.startMs + offset)}',
          ),
          key: const Key('subtitle-summary'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: HandySpace.s),
        for (final cue in cues.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: HandySpace.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_clock(cue.startMs + offset), style: figures),
                      if (offset != 0)
                        Text(
                          tr(
                            context,
                            'was ${_clock(cue.startMs)}',
                            'trước ${_clock(cue.startMs)}',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: c.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    cue.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        if (cues.first.startMs + offset < 0)
          HandyNotice(
            tr(
              context,
              'The first line would start before zero; the file will be refused.',
              'Câu đầu sẽ bắt đầu trước 0; tệp sẽ bị từ chối.',
            ),
            tone: HandyTone.warning,
          ),
      ],
    );
  }
}
