import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_ui/kit.dart';
import 'cue_preview.dart';

/// Shifting and converting subtitles. The first lines show before and
/// after as the shift changes; Save checks the whole file, then writes it.
class SubtitlePage extends StatefulWidget {
  final HandyFiles files;
  final ExportHistory? history;
  final String format;
  const SubtitlePage({
    super.key,
    required this.files,
    this.history,
    this.format = 'srt',
  });
  @override
  State<SubtitlePage> createState() => _SubtitlePageState();
}

class _SubtitlePageState extends State<SubtitlePage> {
  final input = TextEditingController(),
      shift = TextEditingController(text: '0');
  late String format = widget.format == 'vtt' ? 'vtt' : 'srt';
  late final history = widget.history ?? ExportHistory('media');
  List<SubtitleCue> cues = const [];
  int? offset = 0;
  String? problem, output;
  bool busy = false;
  Timer? _wait;

  @override
  void dispose() {
    _wait?.cancel();
    input.dispose();
    shift.dispose();
    super.dispose();
  }

  void changed() {
    _wait?.cancel();
    setState(() => output = null);
    _wait = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(_read);
    });
  }

  /// Reads the source and renders it shifted; any fault is one sentence.
  void _read() {
    offset = int.tryParse(shift.text.trim());
    output = null;
    if (input.text.trim().isEmpty) {
      cues = const [];
      problem = null;
      return;
    }
    try {
      if (offset == null) {
        throw const FormatException(
          'Offset must be an integer number of milliseconds',
        );
      }
      cues = parseSubtitles(input.text);
      final text = renderSubtitles(
        cues,
        vtt: format == 'vtt',
        offsetMs: offset!,
      );
      if (parseSubtitles(text).length != cues.length) {
        throw const FormatException('Subtitle output could not be verified');
      }
      output = text;
      problem = null;
    } on FormatException catch (e) {
      problem = e.message;
    } catch (e) {
      problem = errorText(context, e);
    }
  }

  void nudge(int by) {
    shift.text = '${(int.tryParse(shift.text.trim()) ?? 0) + by}';
    changed();
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
          '${e is FormatException ? e.message : errorText(context, e)}. ${tr(context, 'The subtitles are unchanged.', 'Phụ đề vẫn giữ nguyên.')}',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open() => run(() async {
    final file = await widget.files.importText(maxBytes: 1000000);
    if (file == null || !mounted) return;
    input.text = file.text;
    setState(_read);
  });

  Future<void> save() => run(() async {
    _wait?.cancel();
    setState(_read);
    final text = output;
    if (text == null) throw FormatException(problem ?? 'Nothing to save');
    final uri = await widget.files.exportText('handy-subtitles.$format', text);
    var noted = true;
    if (uri != null) {
      try {
        await history.record(
          tool: 'subtitle-$format',
          uri: uri,
          mime: format == 'vtt' ? 'text/vtt' : 'application/x-subrip',
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
          ? tr(context, 'Export canceled', 'Đã hủy xuất')
          : noted
          ? tr(context, 'Subtitles exported', 'Đã xuất phụ đề')
          : tr(
              context,
              'Subtitles exported; history could not be saved.',
              'Đã xuất phụ đề; chưa lưu được lịch sử.',
            ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final source = TextField(
      key: const Key('subtitle-input'),
      controller: input,
      enabled: !busy,
      expands: true,
      maxLines: null,
      maxLength: 1000000,
      textAlignVertical: TextAlignVertical.top,
      // Show `-->` as typed, not as an arrow: it is the file's syntax.
      style: const TextStyle(
        fontFeatures: [
          FontFeature.disable('calt'),
          FontFeature.disable('liga'),
        ],
      ),
      onChanged: (_) => changed(),
      decoration: InputDecoration(
        hintText:
            '1\n00:00:01,000 --> 00:00:03,500\n${tr(context, 'First line of dialogue', 'Câu thoại đầu tiên')}',
        hintMaxLines: 4,
        counterText: '',
        alignLabelWithHint: true,
      ),
    );
    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          key: const Key('subtitle-format'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'srt', label: Text('SRT')),
            ButtonSegment(value: 'vtt', label: Text('WebVTT')),
          ],
          selected: {format},
          onSelectionChanged: busy
              ? null
              : (v) {
                  format = v.single;
                  changed();
                },
        ),
        const SizedBox(height: HandySpace.l),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton.outlined(
              key: const Key('subtitle-earlier'),
              tooltip: tr(context, 'Half a second earlier', 'Sớm hơn nửa giây'),
              onPressed: busy ? null : () => nudge(-500),
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: HandySpace.s),
            Expanded(
              child: TextField(
                key: const Key('subtitle-offset'),
                controller: shift,
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                onChanged: (_) => changed(),
                decoration: InputDecoration(
                  labelText: tr(context, 'Shift (ms)', 'Dời (ms)'),
                  helperText: tr(
                    context,
                    'More shows them later',
                    'Số dương hiện muộn hơn',
                  ),
                ),
              ),
            ),
            const SizedBox(width: HandySpace.s),
            IconButton.outlined(
              key: const Key('subtitle-later'),
              tooltip: tr(context, 'Half a second later', 'Muộn hơn nửa giây'),
              onPressed: busy ? null : () => nudge(500),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: HandySpace.l),
        CuePreview(cues: cues, offset: offset ?? 0, problem: problem),
        const SizedBox(height: HandySpace.l),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('subtitle-export'),
                onPressed: busy || output == null ? null : save,
                icon: const Icon(Icons.save_alt),
                label: Text(tr(context, 'Save .$format', 'Lưu .$format')),
              ),
            ),
            const SizedBox(width: HandySpace.s),
            HandyShareButton(
              name: 'handy-subtitles.$format',
              mimeType: format == 'vtt' ? 'text/vtt' : 'application/x-subrip',
              bytes: output == null
                  ? null
                  : () => Uint8List.fromList(utf8.encode(output!)),
            ),
          ],
        ),
      ],
    );
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'Subtitles', 'Phụ đề')),
          actions: [
            TextButton.icon(
              key: const Key('subtitle-import'),
              onPressed: busy ? null : open,
              icon: const Icon(Icons.file_open_outlined),
              label: Text(tr(context, 'Open file', 'Mở tệp')),
            ),
            const SizedBox(width: HandySpace.xs),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(HandySpace.l),
                      child: source,
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: HandyColors.of(context).rule,
                  ),
                  SizedBox(
                    width: 440,
                    child: ListView(
                      padding: const EdgeInsets.all(HandySpace.xl),
                      children: [panel],
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(HandySpace.l),
              children: [
                SizedBox(height: 220, child: source),
                const SizedBox(height: HandySpace.l),
                panel,
              ],
            );
          },
        ),
      ),
    );
  }
}
