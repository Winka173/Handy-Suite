import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import '../text/text_opener.dart';
import 'draft.dart';

/// The editor's less frequent actions: find, bring text in, insert a
/// template, and the limits.
class WriteMenu extends StatelessWidget {
  final DraftController draft;
  final HandyFiles files;
  final bool busy;
  final Future<void> Function(Future<void> Function()) run;
  final Future<bool> Function() mayReplace;
  final VoidCallback onFind;
  final TextOpener opener;
  const WriteMenu({
    super.key,
    required this.draft,
    required this.files,
    required this.busy,
    required this.run,
    required this.mayReplace,
    required this.onFind,
    required this.opener,
  });

  /// The app's one way in: Markdown replaces the draft here (after
  /// asking), other text opens read-only with "make a Markdown copy".
  Future<void> _importText(BuildContext context) =>
      run(() => opener.pickAndShow(context, inWriter: true));

  Future<void> _importPack(BuildContext context) => run(() async {
    final file = await files.importBytes(
      extensions: ['zip'],
      maxBytes: 16000000,
    );
    if (file == null || !context.mounted) return;
    final text = await draft.readPack(file.bytes);
    if (await mayReplace()) draft.replace(text);
  });

  void _limits(BuildContext context) => showAdaptiveDialog<void>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(tr(context, 'Formats and limits', 'Định dạng và giới hạn')),
      content: Text(
        tr(
          context,
          'The draft holds up to 1 MB of text. Preview and formatted exports take up to 100 KB. Raw HTML is shown as text and pictures are never loaded. PDFs use fonts on this device, keep selectable text and stop at 100 pages. A document pack holds the source, HTML, text and PDF.',
          'Bản nháp chứa tối đa 1 MB chữ. Xem trước và xuất có định dạng tối đa 100 KB. HTML thô hiện như chữ và ảnh không bao giờ được tải. PDF dùng phông trên máy, giữ chữ chọn được, tối đa 100 trang. Gói tài liệu gồm mã nguồn, HTML, văn bản và PDF.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Close', 'Đóng')),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    void insert(String kind) => draft.template(kind, vi ? 'vi' : 'en');
    return HandyMenuButton(
      items: [
        HandyMenuItem(
          Icons.search,
          tr(context, 'Find and replace', 'Tìm và thay'),
          onFind,
          key: const Key('markdown-find-open'),
        ),
        HandyMenuItem(
          Icons.title,
          tr(context, 'Insert a heading', 'Chèn tiêu đề'),
          busy ? null : () => insert('heading'),
        ),
        HandyMenuItem(
          Icons.checklist,
          tr(context, 'Insert a checklist', 'Chèn danh sách việc'),
          busy ? null : () => insert('checklist'),
        ),
        HandyMenuItem(
          Icons.table_chart_outlined,
          tr(context, 'Insert a table', 'Chèn bảng'),
          busy ? null : () => insert('table'),
          key: const Key('markdown-template-table'),
        ),
        HandyMenuItem(
          Icons.file_open_outlined,
          tr(context, 'Open a text file', 'Mở tệp văn bản'),
          busy ? null : () => _importText(context),
          key: const Key('markdown-import'),
        ),
        HandyMenuItem(
          Icons.folder_zip_outlined,
          tr(context, 'Open a document pack', 'Mở gói tài liệu'),
          busy ? null : () => _importPack(context),
          key: const Key('markdown-import-pack'),
        ),
        HandyMenuItem(
          Icons.info_outline,
          tr(context, 'Formats and limits', 'Định dạng và giới hạn'),
          () => _limits(context),
        ),
      ],
    );
  }
}
