import 'package:flutter/foundation.dart';
import 'package:handy_save_engine/handy_save_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';

Uint8List _encode((SaveLibrary, SaveFormat) v) =>
    SavePortable.export(v.$1, v.$2);
ImportPreview _preview((Uint8List, SaveFormat, SaveLibrary) v) =>
    SavePortable.preview(v.$1, v.$2, current: v.$3);

String formatName(BuildContext c, SaveFormat f) => switch (f) {
  SaveFormat.json => tr(c, 'Full backup (JSON)', 'Bản sao lưu đầy đủ (JSON)'),
  SaveFormat.zip => tr(
    c,
    'Backup with pictures (ZIP)',
    'Sao lưu kèm ảnh (ZIP)',
  ),
  SaveFormat.html => tr(
    c,
    'Browser bookmarks (HTML)',
    'Dấu trang trình duyệt (HTML)',
  ),
  SaveFormat.csv => tr(c, 'Spreadsheet (CSV)', 'Bảng tính (CSV)'),
  SaveFormat.markdown => 'Markdown',
  SaveFormat.txt => tr(c, 'Plain list of links (TXT)', 'Danh sách link (TXT)'),
};

/// Saving the library somewhere else, and bringing a file in.
extension ImportExport on SaveScope {
  /// Exports the whole library, or only the selected links.
  Future<void> exportLinks(
    BuildContext context, {
    bool selected = false,
  }) async {
    final format = await showDialog<SaveFormat>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr(context, 'Save as', 'Lưu dạng')),
        children: [
          for (final f in SaveFormat.values)
            SimpleDialogOption(
              key: Key('export-${f.name}'),
              onPressed: () => Navigator.pop(context, f),
              child: Text(formatName(context, f)),
            ),
        ],
      ),
    );
    if (format == null || !context.mounted) return;
    var lib = library;
    if (selected)
      lib = lib.copyWith(
        bookmarks: [
          for (final b in lib.bookmarks)
            if (view.selected.contains(b.id)) b,
        ],
      );
    await run(context, () async {
      final bytes = await compute(_encode, (lib, format));
      final uri = await files.exportBytes(
        'handy-save.${format == SaveFormat.markdown ? 'md' : format.name}',
        bytes,
        mimeType: switch (format) {
          SaveFormat.zip => 'application/zip',
          SaveFormat.json => 'application/json',
          SaveFormat.html => 'text/html',
          SaveFormat.csv => 'text/csv',
          _ => 'text/plain',
        },
      );
      if (uri != null && context.mounted)
        showHandyMessage(
          context,
          tr(
            context,
            '${lib.bookmarks.length} links saved to a file.',
            'Đã lưu ${lib.bookmarks.length} link ra file.',
          ),
        );
    });
  }

  /// Reads a file, shows what it holds, then adds it or (asked twice)
  /// replaces everything. Nothing is written before the person chooses.
  Future<void> importLinks(BuildContext context) => run(context, () async {
    final file = await files.importBytes(
      extensions: ['json', 'zip', 'html', 'htm', 'csv', 'txt', 'md'],
      maxBytes: SavePortable.maxImportBytes,
    );
    if (file == null) return;
    final format = switch (file.name.split('.').last.toLowerCase()) {
      'zip' => SaveFormat.zip,
      'html' || 'htm' => SaveFormat.html,
      'csv' => SaveFormat.csv,
      'md' => SaveFormat.markdown,
      'txt' => SaveFormat.txt,
      _ => SaveFormat.json,
    };
    final baseline = library;
    final preview = await compute(_preview, (file.bytes, format, baseline));
    if (!context.mounted) return;
    final strategy = await showDialog<ImportStrategy>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tr(
            context,
            'Bring in ${preview.validCount} links?',
            'Nhập ${preview.validCount} link?',
          ),
        ),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(
                context,
                '${preview.duplicateCount} are already saved and ${preview.invalidCount} could not be read.',
                '${preview.duplicateCount} link đã có sẵn và ${preview.invalidCount} link không đọc được.',
              ),
            ),
            const SizedBox(height: HandySpace.m),
            for (final b in preview.library.bookmarks.take(5))
              Text(
                '· ${b.title.isEmpty ? b.sourceDomain : b.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Cancel', 'Hủy')),
          ),
          TextButton(
            key: const Key('import-replace'),
            onPressed: () => Navigator.pop(context, ImportStrategy.replace),
            child: Text(tr(context, 'Replace all…', 'Thay toàn bộ…')),
          ),
          FilledButton(
            key: const Key('import-merge'),
            onPressed: () => Navigator.pop(context, ImportStrategy.merge),
            child: Text(tr(context, 'Add new ones', 'Thêm link mới')),
          ),
        ],
      ),
    );
    if (strategy == null || !context.mounted) return;
    if (strategy == ImportStrategy.replace &&
        !await confirmHandy(
          context,
          title: tr(
            context,
            'Replace your whole library?',
            'Thay toàn bộ thư viện?',
          ),
          message: tr(
            context,
            'Every link here now is swapped for the file. You can undo once.',
            'Mọi link hiện có sẽ được thay bằng nội dung file. Có thể hoàn tác một lần.',
          ),
          confirmLabel: tr(context, 'Replace', 'Thay thế'),
          destructive: true,
        )) {
      return;
    }
    await view.change((l) {
      if (strategy == ImportStrategy.replace && !identical(l, baseline)) {
        throw StateError(
          'The library changed meanwhile; import again / Thư viện vừa thay đổi; hãy nhập lại',
        );
      }
      return preview.commit(l, strategy: strategy);
    });
    if (context.mounted)
      undoMessage(context, tr(context, 'Links imported.', 'Đã nhập link.'));
  });
}
