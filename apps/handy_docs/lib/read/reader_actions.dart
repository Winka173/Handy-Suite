import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'properties_dialog.dart';
import 'reader_store.dart';

/// What the reading screens can do, with the asking, the messages and the
/// one-at-a-time rule in one place. A failure says so and changes nothing.
class ReaderActions {
  final ReaderStore store;
  final HandyFiles files;
  ReaderActions(this.store, this.files);

  final busy = ValueNotifier(false);

  Future<void> guard(
    BuildContext context,
    Future<String?> Function() task,
  ) async {
    if (busy.value) return;
    busy.value = true;
    try {
      final done = await task();
      if (done != null && context.mounted) showHandyMessage(context, done);
    } catch (e) {
      if (context.mounted) {
        showHandyMessage(
          context,
          '${e is FormatException ? e.message : errorText(context, e)}. ${tr(context, 'Your documents are unchanged.', 'Tài liệu vẫn giữ nguyên.')}',
        );
      }
    } finally {
      busy.value = false;
    }
  }

  Future<bool> _ask(
    BuildContext context,
    String title,
    String message,
    String yes,
  ) => confirmHandy(context, title: title, message: message, confirmLabel: yes);

  /// The open document is not in the library yet: ask before putting it down.
  Future<bool> mayClose(BuildContext context) async =>
      store.current == null ||
      store.saved ||
      await _ask(
        context,
        tr(context, 'Close the unsaved document?', 'Đóng tài liệu chưa lưu?'),
        tr(
          context,
          '${store.current!.name} is not in your library. Save a copy to keep it.',
          '${store.current!.name} chưa có trong thư viện. Lưu một bản để giữ lại.',
        ),
        tr(context, 'Close it', 'Đóng'),
      );

  /// Opens one file for reading. Returns true when a document is shown.
  Future<bool> openFile(BuildContext context) async {
    var shown = false;
    await guard(context, () async {
      final file = await files.importBytes(
        extensions: readerExtensions,
        maxBytes: 1000000,
      );
      if (file == null || !context.mounted) return null;
      final doc = ReaderStore.read(file);
      if (!await mayClose(context)) return null;
      store.show(doc);
      shown = true;
      return null;
    });
    return shown;
  }

  Future<void> addMany(BuildContext context) => guard(context, () async {
    final picked = await (files as BatchHandyFiles).importManyBytes(
      extensions: readerExtensions,
      maxFiles: ReaderStore.maxDocuments,
      maxEachBytes: 1000000,
      maxTotalBytes: 8000000,
    );
    if (picked.isEmpty || !context.mounted) return null;
    final next = store.withAll(picked);
    if (!await _ask(
          context,
          tr(
            context,
            'Add ${picked.length} documents?',
            'Thêm ${picked.length} tài liệu?',
          ),
          tr(
            context,
            'Copies are kept in this app; the files themselves stay where they are.',
            'Bản sao được giữ trong app; các tệp gốc vẫn ở nguyên chỗ.',
          ),
          tr(context, 'Add', 'Thêm'),
        ) ||
        !context.mounted) {
      return null;
    }
    await store.commit(next);
    return context.mounted
        ? tr(
            context,
            'Added ${picked.length} documents',
            'Đã thêm ${picked.length} tài liệu',
          )
        : null;
  });

  Future<bool> open(BuildContext context, ReaderDocument entry) async {
    var shown = false;
    await guard(context, () async {
      if (!await mayClose(context)) return null;
      await store.open(entry);
      shown = true;
      return null;
    });
    return shown;
  }

  Future<void> keep(BuildContext context) => guard(context, () async {
    await store.keep();
    return context.mounted
        ? tr(context, 'Saved in your library', 'Đã lưu vào thư viện')
        : null;
  });

  Future<void> favorite(BuildContext context, ReaderDocument d) =>
      guard(context, () async {
        await store.change(d.copyWith(favorite: !d.favorite));
        return null;
      });

  Future<void> properties(BuildContext context, ReaderDocument d) =>
      guard(context, () async {
        final next = await editProperties(context, d);
        if (next != null) await store.change(next);
        return null;
      });

  Future<void> export(BuildContext context, ReaderDocument d) =>
      guard(context, () async {
        final uri = await files.exportBytes(
          d.name,
          store.source(d),
          mimeType: 'text/plain',
        );
        if (!context.mounted) return null;
        return uri == null
            ? tr(context, 'Export canceled', 'Đã hủy xuất')
            : tr(context, 'Saved a copy', 'Đã lưu một bản');
      });

  Future<void> remove(
    BuildContext context,
    ReaderDocument d,
  ) => guard(context, () async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Remove ${d.name}?', 'Xóa ${d.name}?'),
      message: tr(
        context,
        'Only the copy in this app is removed; the original file is untouched.',
        'Chỉ xóa bản sao trong app; tệp gốc không bị đụng tới.',
      ),
      confirmLabel: tr(context, 'Remove', 'Xóa'),
      destructive: true,
    );
    if (ok) await store.remove(d.id);
    return null;
  });

  Future<void> backup(BuildContext context) => guard(context, () async {
    final uri = await files.exportBytes(
      'handy-documents.zip',
      store.backup(),
      mimeType: 'application/zip',
    );
    if (!context.mounted) return null;
    return uri == null
        ? tr(context, 'Export canceled', 'Đã hủy xuất')
        : tr(context, 'Library saved as ZIP', 'Đã lưu thư viện thành ZIP');
  });

  Future<void> restore(BuildContext context) => guard(context, () async {
    final file = await files.importBytes(
      extensions: ['zip'],
      maxBytes: 9000000,
    );
    if (file == null || !context.mounted) return null;
    final next = readReaderZip(file.bytes);
    if (!await _ask(
      context,
      tr(context, 'Replace your library?', 'Thay thư viện hiện có?'),
      tr(
        context,
        'The ZIP holds ${next.documents.length} documents; the ${store.library!.documents.length} here are replaced. Save a ZIP first to keep them.',
        'ZIP có ${next.documents.length} tài liệu, thay cho ${store.library!.documents.length} tài liệu hiện có. Hãy lưu ZIP trước nếu muốn giữ.',
      ),
      tr(context, 'Replace', 'Thay thế'),
    )) {
      return null;
    }
    await store.commit(next);
    store.close();
    return context.mounted
        ? tr(context, 'Library restored', 'Đã khôi phục thư viện')
        : null;
  });
}
