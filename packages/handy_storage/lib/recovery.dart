import 'package:flutter/material.dart';
import 'package:handy_files/handy_files.dart';
import 'documents.dart';

String _tr(BuildContext c, String en, String vi) =>
    Localizations.localeOf(c).languageCode == 'vi' ? vi : en;

/// Available from load errors and settings; never interprets corrupted payloads.
class DocumentRecoveryButton extends StatelessWidget {
  final DocumentRepository documents;
  final HandyFiles files;
  final Future<void> Function() reload;
  final String? label;
  const DocumentRecoveryButton({
    super.key,
    required this.documents,
    required this.files,
    required this.reload,
    this.label,
  });
  @override
  Widget build(BuildContext context) {
    final store = documents;
    if (store is! RecoverableDocuments) return const SizedBox.shrink();
    return OutlinedButton.icon(
      key: const Key('document-recovery'),
      icon: const Icon(Icons.restore),
      label: Text(
        label ??
            _tr(context, 'Recover local library', 'Khôi phục thư viện cục bộ'),
      ),
      onPressed: () async {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                DocumentRecoveryPage(documents: store, files: files),
          ),
        );
        await reload();
      },
    );
  }
}

class DocumentRecoveryPage extends StatefulWidget {
  final RecoverableDocuments documents;
  final HandyFiles files;
  const DocumentRecoveryPage({
    super.key,
    required this.documents,
    required this.files,
  });
  @override
  State<DocumentRecoveryPage> createState() => _DocumentRecoveryPageState();
}

class _DocumentRecoveryPageState extends State<DocumentRecoveryPage> {
  List<PreservedDocuments> copies = [];
  bool busy = false, changed = false;
  String error = '', notice = '';
  @override
  void initState() {
    super.initState();
    run(refresh);
  }

  Future<void> refresh() async {
    final next = await widget.documents.preserved();
    if (mounted) setState(() => copies = next);
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
          () => error = _tr(
            context,
            'Recovery could not finish. Preserved copies remain stored. Undo requires an empty new library; large diagnostic exports may exceed limits.',
            'Chưa thể khôi phục. Bản giữ lại vẫn còn. Hoàn tác cần thư viện mới trống; bản chẩn đoán lớn có thể vượt giới hạn.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(bool undo) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            _tr(
              context,
              undo ? 'Undo library reset?' : 'Preserve and reset library?',
              undo
                  ? 'Hoàn tác đặt lại thư viện?'
                  : 'Giữ bản cũ và đặt lại thư viện?',
            ),
          ),
          content: Text(
            _tr(
              context,
              undo
                  ? 'Restore the preserved files only if the new library is empty. Corrupted files will still require repair or a valid backup.'
                  : 'Keep all current bytes as a separate local copy, then open an empty library. Use the normal import action to restore a valid backup. No preserved copy is deleted.',
              undo
                  ? 'Chỉ khôi phục bản giữ lại khi thư viện mới trống. File hỏng vẫn cần sửa hoặc bản sao lưu hợp lệ.'
                  : 'Giữ nguyên dữ liệu hiện tại thành bản cục bộ riêng, rồi mở thư viện trống. Dùng chức năng nhập để khôi phục bản sao lưu hợp lệ. Không xóa bản giữ lại.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_tr(context, 'Cancel', 'Hủy')),
            ),
            FilledButton(
              key: const Key('recovery-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(_tr(context, 'Continue', 'Tiếp tục')),
            ),
          ],
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          _tr(context, 'Local library recovery', 'Khôi phục thư viện cục bộ'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _tr(
              context,
              'Preserved copies may contain private information. Diagnostic ZIP files contain raw data, not a repaired app backup. Export them only to a location you trust.',
              'Bản giữ lại có thể chứa thông tin riêng tư. ZIP chẩn đoán chứa dữ liệu thô, không phải bản sao lưu đã sửa. Chỉ xuất đến nơi bạn tin cậy.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('recovery-reset'),
            onPressed: busy
                ? null
                : () => run(() async {
                    if (!await confirm(false)) return;
                    await widget.documents.preserveAndReset();
                    changed = true;
                    await refresh();
                  }),
            child: Text(
              _tr(
                context,
                'Preserve and open empty library',
                'Giữ bản cũ và mở thư viện trống',
              ),
            ),
          ),
          if (busy) const LinearProgressIndicator(),
          if (error.isNotEmpty) Text(error, key: const Key('recovery-error')),
          if (notice.isNotEmpty) Text(notice),
          for (final copy in copies)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(copy.createdAt.toLocal().toString()),
                    SelectableText(copy.id),
                    Wrap(
                      spacing: 12,
                      children: [
                        OutlinedButton(
                          key: Key('recovery-export-${copy.id}'),
                          onPressed: busy
                              ? null
                              : () => run(() async {
                                  final bytes = await widget.documents
                                      .exportPreserved(copy.id);
                                  final uri = await widget.files.exportBytes(
                                    'handy-preserved-${copy.id}.zip',
                                    bytes,
                                    mimeType: 'application/zip',
                                  );
                                  if (mounted)
                                    setState(
                                      () => notice = _tr(
                                        context,
                                        uri == null
                                            ? 'Export canceled'
                                            : 'Diagnostic copy exported',
                                        uri == null
                                            ? 'Đã hủy xuất'
                                            : 'Đã xuất bản chẩn đoán',
                                      ),
                                    );
                                }),
                          child: Text(
                            _tr(
                              context,
                              'Export diagnostic ZIP',
                              'Xuất ZIP chẩn đoán',
                            ),
                          ),
                        ),
                        TextButton(
                          key: Key('recovery-undo-${copy.id}'),
                          onPressed: busy
                              ? null
                              : () => run(() async {
                                  if (!await confirm(true)) return;
                                  await widget.documents.undoReset(copy.id);
                                  changed = true;
                                  await refresh();
                                }),
                          child: Text(
                            _tr(context, 'Undo reset', 'Hoàn tác đặt lại'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('recovery-done'),
            onPressed: busy ? null : () => Navigator.pop(context, changed),
            child: Text(_tr(context, 'Return to library', 'Trở về thư viện')),
          ),
        ],
      ),
    ),
  );
}
