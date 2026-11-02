import 'package:handy_files/handy_files.dart';
import 'package:handy_ocr/handy_ocr.dart';
import 'package:handy_ui/kit.dart';
import '../text/text_opener.dart';
import 'ocr_job.dart';

/// "What does this page say?": the words read on this device, ready to
/// edit, copy and save, beside the page with the lines it read marked.
class OcrPage extends StatefulWidget {
  final OcrJob job;
  final HandyFiles files;
  final TextOpener opener;
  const OcrPage({
    super.key,
    required this.job,
    required this.files,
    required this.opener,
  });
  @override
  State<OcrPage> createState() => _OcrPageState();
}

String languageName(BuildContext context, String tag) {
  final code = tag.split('-').first.toLowerCase();
  final name = switch (code) {
    'vi' => tr(context, 'Vietnamese', 'Tiếng Việt'),
    'en' => tr(context, 'English', 'Tiếng Anh'),
    'fr' => tr(context, 'French', 'Tiếng Pháp'),
    'de' => tr(context, 'German', 'Tiếng Đức'),
    'ja' => tr(context, 'Japanese', 'Tiếng Nhật'),
    'zh' => tr(context, 'Chinese', 'Tiếng Trung'),
    'ko' => tr(context, 'Korean', 'Tiếng Hàn'),
    _ => tag,
  };
  return name == tag ? tag : '$name ($tag)';
}

class _OcrPageState extends State<OcrPage> {
  bool showPage = false, busy = false;
  OcrJob get job => widget.job;

  @override
  void initState() {
    super.initState();
    job.start();
  }

  Future<void> guard(Future<String?> Function() task) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final done = await task();
      if (done != null && mounted) showHandyMessage(context, done);
    } catch (e) {
      if (mounted) {
        showHandyMessage(
          context,
          e is FormatException ? e.message : errorText(context, e),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save(String kind) => guard(() async {
    final (name, bytes, mime) = job.file(kind);
    final uri = await widget.files.exportBytes(name, bytes, mimeType: mime);
    if (!mounted) return null;
    return uri == null
        ? tr(context, 'Export canceled', 'Đã hủy xuất')
        : tr(context, 'Saved $name', 'Đã lưu $name');
  });

  Future<void> toWriter() => guard(() async {
    if (!await widget.opener.toWriter(context, job.text.text) || !mounted) {
      return null;
    }
    Navigator.pushNamed(context, '/write');
    return null;
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: job,
    builder: (context, _) {
      final done = job.state == OcrState.done && job.result?.isEmpty == false;
      return PopScope(
        canPop: job.state != OcrState.reading,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'Read the text', 'Nhận dạng chữ')),
            actions: [
              if (done) ...[
                FilledButton.icon(
                  key: const Key('ocr-copy'),
                  onPressed: () => copyToClipboard(context, job.text.text),
                  icon: const Icon(Icons.copy),
                  label: Text(tr(context, 'Copy text', 'Chép chữ')),
                ),
                HandyMenuButton(
                  items: [
                    HandyMenuItem(
                      Icons.edit_note,
                      tr(context, 'Open in the writer', 'Mở trong trình viết'),
                      busy ? null : toWriter,
                      key: const Key('ocr-writer'),
                    ),
                    HandyMenuItem(
                      Icons.description_outlined,
                      tr(
                        context,
                        'Save as Word (.docx)',
                        'Lưu thành Word (.docx)',
                      ),
                      busy ? null : () => save('docx'),
                      key: const Key('ocr-save-docx'),
                    ),
                    HandyMenuItem(
                      Icons.save_alt,
                      tr(context, 'Save as text (.txt)', 'Lưu thành .txt'),
                      busy ? null : () => save('txt'),
                      key: const Key('ocr-save-txt'),
                    ),
                    HandyMenuItem(
                      Icons.save_alt,
                      tr(context, 'Save as Markdown (.md)', 'Lưu thành .md'),
                      busy ? null : () => save('md'),
                      key: const Key('ocr-save-md'),
                    ),
                    for (final tag in job.support.languages)
                      if (tag != job.language)
                        HandyMenuItem(
                          Icons.translate,
                          tr(
                            context,
                            'Read again in ${languageName(context, tag)}',
                            'Đọc lại bằng ${languageName(context, tag)}',
                          ),
                          () => job.read(tag),
                        ),
                  ],
                ),
              ],
              const SizedBox(width: HandySpace.s),
            ],
          ),
          body: LayoutBuilder(builder: _layout),
        ),
      );
    },
  );

  Widget _layout(BuildContext context, BoxConstraints box) {
    final wide = box.maxWidth >= 900;
    final c = HandyColors.of(context);
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: _words(context)),
          VerticalDivider(width: 1, color: c.rule),
          Expanded(
            flex: 4,
            child: ColoredBox(
              color: c.ground,
              child: LayoutBuilder(
                builder: (context, area) => _sheet(context, area),
              ),
            ),
          ),
        ],
      );
    }
    final hasPage = job.state == OcrState.done;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPage)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HandySpace.l,
              HandySpace.s,
              HandySpace.l,
              0,
            ),
            child: SegmentedButton<bool>(
              key: const Key('ocr-view'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(tr(context, 'Text', 'Chữ')),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(tr(context, 'Page', 'Trang')),
                ),
              ],
              selected: {showPage},
              onSelectionChanged: (v) => setState(() => showPage = v.single),
            ),
          ),
        Expanded(
          child: HandySwap(
            child: hasPage && showPage
                ? ColoredBox(
                    key: const ValueKey('page'),
                    color: c.ground,
                    child: LayoutBuilder(
                      builder: (context, area) => _sheet(context, area),
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('words'),
                    child: _words(context),
                  ),
          ),
        ),
      ],
    );
  }

  /// The page on a sheet with each line it read marked in the app's tint.
  Widget _sheet(BuildContext context, BoxConstraints area) {
    final aspect = job.aspect;
    final width = ((area.maxHeight - 2 * HandySpace.l) * aspect)
        .clamp(120.0, area.maxWidth - 2 * HandySpace.l)
        .toDouble();
    final height = width / aspect;
    final r = job.result;
    final tint = Theme.of(context).colorScheme.primary.withValues(alpha: .24);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HandySpace.l),
      child: Center(
        child: Container(
          key: const Key('ocr-page'),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: HandyColors.of(context).border),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.memory(
                  job.source.image,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  semanticLabel: job.source.label,
                ),
              ),
              if (r != null && r.width > 0)
                for (final line in r.lines)
                  Positioned(
                    left: line.box.left / r.width * width - 2,
                    top: line.box.top / r.height * height - 1,
                    width: line.box.width / r.width * width + 4,
                    height: line.box.height / r.height * height + 2,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tint,
                          borderRadius: BorderRadius.circular(2),
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

  Widget _words(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    Widget pad(Widget child) => ListView(
      padding: const EdgeInsets.all(HandySpace.l),
      children: [HandyContent(maxWidth: 720, child: child)],
    );
    switch (job.state) {
      case OcrState.checking:
      case OcrState.reading:
        return pad(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(context, 'Reading the page…', 'Đang đọc trang…'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: HandySpace.m),
              const LinearProgressIndicator(),
              const SizedBox(height: HandySpace.m),
              Text(
                tr(
                  context,
                  'On this device; nothing is uploaded.',
                  'Trên máy này; không tải gì lên mạng.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('ocr-cancel'),
                  onPressed: job.state == OcrState.reading ? job.cancel : null,
                  child: Text(tr(context, 'Cancel', 'Hủy')),
                ),
              ),
            ],
          ),
        );
      case OcrState.unavailable:
        return HandyEmpty(
          title: tr(
            context,
            'Text recognition is in the app',
            'Nhận dạng chữ có trong ứng dụng',
          ),
          message: tr(
            context,
            'Reading text runs on the device in the Android, iOS and Windows apps. The browser has no engine for it, and pages are never uploaded.',
            'Nhận dạng chữ chạy trên máy trong ứng dụng Android, iOS và Windows. Trình duyệt không có bộ nhận dạng, và trang không bao giờ được tải lên mạng.',
          ),
        );
      case OcrState.chooseLanguage:
        return pad(_languages(context));
      case OcrState.failed:
        return pad(
          HandyNotice(
            '${job.error is OcrUnavailable ? (job.error as OcrUnavailable).message : errorText(context, job.error!)}. ${tr(context, 'The page is unchanged.', 'Trang vẫn giữ nguyên.')}',
            tone: HandyTone.warning,
            action: TextButton(
              key: const Key('ocr-retry'),
              onPressed: () => job.read(job.language),
              child: Text(tr(context, 'Try again', 'Thử lại')),
            ),
          ),
        );
      case OcrState.done:
        if (job.result!.isEmpty) {
          return HandyEmpty(
            title: tr(context, 'No text found', 'Không thấy chữ'),
            message: tr(
              context,
              'Nothing readable was found on this page. A straight, sharp, well-lit photo reads best.',
              'Không đọc được chữ nào trên trang. Ảnh chụp thẳng, rõ nét, đủ sáng sẽ đọc tốt hơn.',
            ),
          );
        }
        final lines = job.result!.lines.length;
        return Padding(
          padding: const EdgeInsets.all(HandySpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                [
                  job.source.label,
                  tr(
                    context,
                    '${formatFigure(context, '$lines')} lines',
                    '${formatFigure(context, '$lines')} dòng',
                  ),
                  if (job.language != null)
                    languageName(context, job.language!),
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
              ),
              const SizedBox(height: HandySpace.s),
              Expanded(
                child: TextField(
                  key: const Key('ocr-text'),
                  controller: job.text,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  decoration: InputDecoration(
                    labelText: tr(
                      context,
                      'Text read from the page, check it and fix any errors',
                      'Chữ đọc từ trang, hãy soát và sửa lỗi',
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _languages(BuildContext context) {
    final theme = Theme.of(context);
    final vi = job.preferred == 'vi';
    final installed = job.support.languages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          vi
              ? tr(
                  context,
                  'Vietnamese text recognition is not installed',
                  'Windows chưa cài nhận dạng chữ tiếng Việt',
                )
              : tr(
                  context,
                  'English text recognition is not installed',
                  'Windows chưa cài nhận dạng chữ tiếng Anh',
                ),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: HandySpace.s),
        Text(
          tr(
            context,
            'Add it in Windows Settings › Time & language › Language & region: add the language, then make sure its "Optical character recognition" part is installed. Then open this page again.',
            'Thêm trong Cài đặt Windows › Thời gian và ngôn ngữ › Ngôn ngữ và vùng: thêm ngôn ngữ, rồi kiểm tra phần "Nhận dạng ký tự quang học" đã được cài. Sau đó mở lại trang này.',
          ),
          style: theme.textTheme.bodyMedium,
        ),
        if (installed.isNotEmpty) ...[
          const SizedBox(height: HandySpace.l),
          Text(
            tr(
              context,
              'Or read it now with what is installed. Letters with accents may come out without them.',
              'Hoặc đọc ngay bằng ngôn ngữ đã có. Chữ có dấu có thể bị mất dấu.',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: HandySpace.m),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final tag in installed)
                OutlinedButton(
                  key: Key('ocr-language-$tag'),
                  onPressed: () => job.read(tag),
                  child: Text(
                    tr(
                      context,
                      'Read in ${languageName(context, tag)}',
                      'Đọc bằng ${languageName(context, tag)}',
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// `#/ocr`: reads the page it was given; without one it says where to
/// start (a web address opened directly carries no picture).
class OcrRoute extends StatefulWidget {
  final OcrSource? source;
  final HandyFiles files;
  final TextOpener opener;
  const OcrRoute({
    super.key,
    required this.source,
    required this.files,
    required this.opener,
  });
  @override
  State<OcrRoute> createState() => _OcrRouteState();
}

class _OcrRouteState extends State<OcrRoute> {
  OcrJob? job;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = widget.source;
    if (job == null && s != null) {
      job = OcrJob(
        s,
        preferred: Localizations.localeOf(context).languageCode == 'vi'
            ? 'vi'
            : 'en',
      );
    }
  }

  @override
  void dispose() {
    job?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final j = job;
    if (j != null) {
      return OcrPage(job: j, files: widget.files, opener: widget.opener);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Read the text', 'Nhận dạng chữ')),
      ),
      body: HandyEmpty(
        title: tr(context, 'Pick a page to read', 'Chọn một trang để đọc'),
        message: tr(
          context,
          'Open a scanned page or a PDF page and choose Read the text.',
          'Mở một trang quét hoặc một trang PDF rồi chọn Nhận dạng chữ.',
        ),
      ),
    );
  }
}
