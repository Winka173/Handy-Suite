import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_ui/kit.dart';
import 'subtitle_controller.dart';

/// Subtitles on the bench: paste or open an SRT/WebVTT file, pick the
/// format, shift the timing, check the first lines before and after, save.
class SubtitlePanel extends StatefulWidget {
  final HandyFiles files;
  final ExportHistory? history;
  final Duration wait;

  /// Builds the bench header around this panel's own actions.
  final Widget Function(BuildContext, List<Widget>)? header;
  const SubtitlePanel({
    super.key,
    required this.files,
    this.history,
    this.header,
    this.wait = const Duration(milliseconds: 250),
  });
  @override
  State<SubtitlePanel> createState() => _SubtitlePanelState();
}

class _SubtitlePanelState extends State<SubtitlePanel> {
  late final subtitles = SubtitleController(wait: widget.wait)
    ..addListener(_changed);
  final source = TextEditingController(),
      shift = TextEditingController(text: '0');
  late final history = widget.history ?? ExportHistory('tools');
  bool busy = false;

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    subtitles
      ..removeListener(_changed)
      ..dispose();
    source.dispose();
    shift.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() task) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) {
        showHandyMessage(
          context,
          '${e is FormatException ? e.message : errorText(context, e)}. ${tr(context, 'Nothing was saved.', 'Chưa lưu gì.')}',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void fill(String text) {
    source.text = text;
    subtitles.load(text);
  }

  Future<void> open() => run(() async {
    final file = await widget.files.importText(maxBytes: 1000000);
    if (file != null && mounted) fill(file.text);
  });

  Future<void> paste() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && mounted) fill(data!.text!);
  }

  void nudge(int by) {
    subtitles.nudge(by);
    shift.text = subtitles.shift;
  }

  Future<void> save() => run(() async {
    final text = subtitles.verified();
    final uri = await widget.files.exportText(subtitles.fileName, text);
    var noted = true;
    if (uri != null) {
      try {
        await history.record(
          tool: 'subtitle-${subtitles.extension}',
          uri: uri,
          mime: subtitles.mimeType,
          data: Uint8List.fromList(utf8.encode(text)),
        );
      } catch (_) {
        noted = false;
      }
    }
    if (!mounted) return;
    showHandyMessage(
      context,
      uri == null
          ? tr(context, 'Not saved.', 'Chưa lưu.')
          : noted
          ? tr(context, 'Subtitles saved', 'Đã lưu phụ đề')
          : tr(
              context,
              'Subtitles saved; export history could not be updated.',
              'Đã lưu phụ đề; chưa cập nhật được lịch sử xuất.',
            ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = subtitles;
    final ready = s.output != null && !busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null)
          widget.header!(context, [
            IconButton(
              key: const Key('subtitle-import'),
              tooltip: tr(context, 'Open a file', 'Mở tệp'),
              icon: const Icon(Icons.file_open_outlined),
              onPressed: busy ? null : open,
            ),
          ]),
        Row(
          children: [
            Expanded(
              child: Text(
                tr(context, 'Subtitle file', 'Tệp phụ đề'),
                style: theme.textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              key: const Key('subtitle-paste'),
              onPressed: busy ? null : paste,
              icon: const Icon(Icons.content_paste, size: 16),
              label: Text(tr(context, 'Paste', 'Dán')),
            ),
          ],
        ),
        const SizedBox(height: HandySpace.xs),
        TextField(
          key: const Key('subtitle-input'),
          controller: source,
          enabled: !busy,
          minLines: 5,
          maxLines: 8,
          maxLength: 1000000,
          // `-->` is the file's syntax; keep it from becoming an arrow.
          style: const TextStyle(
            fontFeatures: [
              FontFeature.disable('calt'),
              FontFeature.disable('liga'),
            ],
          ),
          onChanged: s.setSource,
          decoration: InputDecoration(
            hintText:
                '1\n00:00:01,000 --> 00:00:03,500\n${tr(context, 'First line of dialogue', 'Câu thoại đầu tiên')}',
            hintMaxLines: 4,
            counterText: '',
          ),
        ),
        const SizedBox(height: HandySpace.l),
        LayoutBuilder(
          builder: (context, box) {
            final format = HandyField(
              label: tr(context, 'Save as', 'Lưu dạng'),
              child: SegmentedButton<String>(
                key: const Key('subtitle-format'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'srt', label: Text('SRT')),
                  ButtonSegment(value: 'vtt', label: Text('WebVTT')),
                ],
                selected: {s.format},
                onSelectionChanged: busy ? null : (v) => s.setFormat(v.single),
              ),
            );
            final offset = HandyField(
              label: tr(context, 'Shift (milliseconds)', 'Dời (mili giây)'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.outlined(
                    key: const Key('subtitle-earlier'),
                    tooltip: tr(
                      context,
                      'Half a second earlier',
                      'Sớm hơn nửa giây',
                    ),
                    onPressed: busy ? null : () => nudge(-500),
                    icon: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: HandySpace.s),
                  Expanded(
                    child: TextField(
                      key: const Key('subtitle-offset'),
                      controller: shift,
                      enabled: !busy,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                      ],
                      style: const TextStyle(fontFeatures: tabular),
                      onChanged: s.setShift,
                      decoration: InputDecoration(
                        hintText: '0',
                        helperMaxLines: 2,
                        helperText: tr(
                          context,
                          'Positive: lines show later',
                          'Số dương: hiện muộn hơn',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: HandySpace.s),
                  IconButton.outlined(
                    key: const Key('subtitle-later'),
                    tooltip: tr(
                      context,
                      'Half a second later',
                      'Muộn hơn nửa giây',
                    ),
                    onPressed: busy ? null : () => nudge(500),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            );
            // Side by side when there is room, so the preview stays
            // on the first screen.
            if (box.maxWidth < 560) {
              return Column(children: [format, offset]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: format),
                const SizedBox(width: HandySpace.l),
                Expanded(flex: 3, child: offset),
              ],
            );
          },
        ),
        const SizedBox(height: HandySpace.s),
        HandySwap(
          child: KeyedSubtree(
            key: ValueKey(
              s.problem != null
                  ? 'problem'
                  : s.cues.isEmpty
                  ? 'empty'
                  : 'cues',
            ),
            child: CuePreview(controller: s),
          ),
        ),
        const SizedBox(height: HandySpace.m),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: [
            FilledButton.icon(
              key: const Key('subtitle-export'),
              onPressed: ready ? save : null,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(
                tr(context, 'Save .${s.extension}', 'Lưu .${s.extension}'),
              ),
            ),
            HandyShareButton(
              name: s.fileName,
              mimeType: s.mimeType,
              bytes: ready
                  ? () => Uint8List.fromList(utf8.encode(s.verified()))
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// The first five lines, when they appear now and after the shift: the
/// answer to "does the timing fit yet?".
class CuePreview extends StatelessWidget {
  final SubtitleController controller;
  const CuePreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final s = controller;
    if (s.problem != null) {
      return HandyNotice(
        tr(context, s.problem!.$1, s.problem!.$2),
        tone: HandyTone.error,
        key: const Key('subtitle-problem'),
      );
    }
    if (s.cues.isEmpty) {
      return HandyEmpty(
        title: tr(
          context,
          'Paste or open an SRT or WebVTT file to see its first lines here. Up to 1 MB and 10,000 lines.',
          'Dán hoặc mở một tệp SRT hay WebVTT để xem các câu đầu ở đây. Tối đa 1 MB và 10.000 câu.',
        ),
      );
    }
    final figures = theme.textTheme.bodyMedium?.copyWith(fontFeatures: tabular);
    final from = s.sourceFormat == 'vtt' ? 'WebVTT' : 'SRT',
        to = s.format == 'vtt' ? 'WebVTT' : 'SRT';
    final count = formatFigure(context, '${s.cues.length}');
    return Card(
      color: c.lead,
      child: Padding(
        padding: const EdgeInsets.all(HandySpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(
                context,
                '$count lines · first at ${subtitleClock(s.cues.first.startMs + s.offset)}',
                '$count câu · câu đầu lúc ${subtitleClock(s.cues.first.startMs + s.offset)}',
              ),
              key: const Key('subtitle-summary'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: c.accent,
                fontFeatures: tabular,
              ),
            ),
            Text(
              from == to
                  ? tr(context, 'Stays $to', 'Giữ dạng $to')
                  : '$from → $to',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: HandySpace.s),
            for (final cue in s.cues.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: HandySpace.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subtitleClock(cue.startMs + s.offset),
                            style: figures,
                          ),
                          if (s.offset != 0)
                            Text(
                              tr(
                                context,
                                'was ${subtitleClock(cue.startMs)}',
                                'trước ${subtitleClock(cue.startMs)}',
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: c.muted,
                                fontFeatures: tabular,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: HandySpace.s),
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
          ],
        ),
      ),
    );
  }
}
