import 'package:flutter/material.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_files/share.dart';
import 'export_history.dart';
import 'recovery.dart';

class ExportHistoryButton extends StatelessWidget {
  final String app;
  final HandyFiles files;
  final ExportHistory? history;
  const ExportHistoryButton({
    super.key,
    required this.app,
    required this.files,
    this.history,
  });
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.history),
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExportHistoryPage(
          history: history ?? ExportHistory(app),
          files: files,
        ),
      ),
    ),
    label: Text(
      Localizations.localeOf(context).languageCode == 'vi'
          ? 'Lịch sử xuất file'
          : 'Export history',
    ),
  );
}

class ExportHistoryPage extends StatefulWidget {
  final ExportHistory history;
  final HandyFiles files;
  const ExportHistoryPage({
    super.key,
    required this.history,
    required this.files,
  });
  @override
  State<ExportHistoryPage> createState() => _ExportHistoryPageState();
}

class _ExportHistoryPageState extends State<ExportHistoryPage> {
  List<ExportHistoryEntry> entries = [];
  bool busy = false;
  String error = '', notice = '';
  String tr(String en, String vi) =>
      Localizations.localeOf(context).languageCode == 'vi' ? vi : en;
  @override
  void initState() {
    super.initState();
    run(load);
  }

  Future<void> load() async {
    final next = await widget.history.load();
    if (mounted) setState(() => entries = next);
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
      notice = '';
    });
    try {
      await work();
    } catch (_) {
      if (mounted)
        setState(
          () => error = tr(
            'History action failed; exported files and existing records were preserved.',
            'Thao tác lịch sử thất bại; giữ nguyên file đã xuất và dữ liệu hiện có.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('Cancel', 'Hủy')),
            ),
            FilledButton(
              key: const Key('history-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('Confirm', 'Xác nhận')),
            ),
          ],
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Export history', 'Lịch sử xuất file'))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr(
            'Only file references are stored, never result contents. Select a file explicitly to share it again. New records verify its checksum; old references never open automatically.',
            'Chỉ lưu tham chiếu file, không lưu nội dung kết quả. Chủ động chọn file để chia sẻ lại. Bản ghi mới kiểm tra checksum; không tự mở đường dẫn cũ.',
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      final uri = await widget.files.exportText(
                        'handy-export-history.json',
                        serializeExportHistory(entries),
                      );
                      if (mounted)
                        setState(
                          () => notice = uri == null
                              ? tr('Export canceled', 'Đã hủy xuất')
                              : tr('History exported', 'Đã xuất lịch sử'),
                        );
                    }),
              child: Text(tr('Export JSON', 'Xuất JSON')),
            ),
            OutlinedButton(
              key: const Key('history-import'),
              onPressed: busy
                  ? null
                  : () => run(() async {
                      final file = await widget.files.importText(
                        maxBytes: 200000,
                      );
                      if (file == null) return;
                      parseExportHistory(file.text);
                      if (!mounted ||
                          !await confirm(
                            tr(
                              'Replace history records? Exported files will not be changed.',
                              'Thay lịch sử? Không thay đổi file đã xuất.',
                            ),
                          ))
                        return;
                      await widget.history.restore(file.text);
                      await load();
                    }),
              child: Text(tr('Import history', 'Nhập lịch sử')),
            ),
            TextButton(
              key: const Key('history-clear'),
              onPressed: busy
                  ? null
                  : () => run(() async {
                      if (!await confirm(
                        tr(
                          'Clear history records? The exported files are kept.',
                          'Xóa lịch sử? Giữ nguyên file đã xuất.',
                        ),
                      ))
                        return;
                      await widget.history.clear();
                      await load();
                    }),
              child: Text(tr('Clear history', 'Xóa lịch sử')),
            ),
          ],
        ),
        if (busy) const LinearProgressIndicator(),
        if (error.isNotEmpty) Text(error),
        if (notice.isNotEmpty) Text(notice),
        DocumentRecoveryButton(
          documents: widget.history.documents,
          files: widget.files,
          reload: load,
        ),
        for (final entry in entries)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.tool} · ${entry.at}'),
                  SelectableText(entry.uri),
                  Text(entry.mime),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (localShareSupported)
                        Builder(
                          builder: (buttonContext) => OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => run(() async {
                                    final file = await widget.files.importBytes(
                                      extensions: switch (entry.mime) {
                                        'application/json' => ['json'],
                                        'text/csv' => ['csv'],
                                        'text/markdown' => ['md', 'markdown'],
                                        'text/html' => ['html', 'htm'],
                                        'application/pdf' => ['pdf'],
                                        'application/zip' => ['zip'],
                                        'text/vtt' => ['vtt'],
                                        'application/x-subrip' => ['srt'],
                                        _ => ['txt'],
                                      },
                                      maxBytes: 30000000,
                                    );
                                    if (file == null) return;
                                    if (!entry.matches(file.bytes))
                                      throw const FormatException(
                                        'Selected file does not match exported bytes',
                                      );
                                    if (!mounted ||
                                        !await confirm(
                                          tr(
                                            'Share the selected file? Review its content before sharing.',
                                            'Chia sẻ file đã chọn? Kiểm tra nội dung trước khi chia sẻ.',
                                          ),
                                        ))
                                      return;
                                    if (!buttonContext.mounted) return;
                                    final box =
                                        buttonContext.findRenderObject()
                                            as RenderBox;
                                    final result = await const LocalShare()
                                        .bytes(
                                          file.name,
                                          file.bytes,
                                          mimeType: entry.mime,
                                          origin:
                                              box.localToGlobal(Offset.zero) &
                                              box.size,
                                        );
                                    if (mounted)
                                      setState(
                                        () => notice =
                                            result == LocalShareResult.dismissed
                                            ? tr(
                                                'Share canceled',
                                                'Đã hủy chia sẻ',
                                              )
                                            : tr(
                                                'Share sheet closed; recipient delivery is not verified',
                                                'Đã đóng bảng chia sẻ; chưa xác minh gửi đến người nhận',
                                              ),
                                      );
                                  }),
                            child: Text(
                              tr(
                                'Select file and share',
                                'Chọn file và chia sẻ',
                              ),
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                await widget.history.remove(entry.id);
                                await load();
                              }),
                        child: Text(tr('Remove record', 'Xóa bản ghi')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
