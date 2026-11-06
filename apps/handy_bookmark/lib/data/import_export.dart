import 'package:flutter/foundation.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';

PortableExport _encode(
  (
    SaveLibrary,
    SaveFormat,
    Map<String, ReadingCopy>,
    Map<String, PortablePicture>,
  )
  v,
) => SavePortable.exportWithReport(
  v.$1,
  v.$2,
  readingCopies: v.$3,
  pictures: v.$4,
);
ImportPreview _preview((Uint8List, SaveFormat, SaveLibrary) v) =>
    SavePortable.preview(v.$1, v.$2, current: v.$3);
ImportPreview _raindrop((Uint8List, SaveLibrary) v) =>
    SavePortable.previewRaindrop(v.$1, current: v.$2);

ImportPreview _pocket((Uint8List, SaveLibrary) v) =>
    SavePortable.previewPocket(v.$1, current: v.$2);

String formatName(BuildContext c, SaveFormat f) => switch (f) {
  SaveFormat.json => tr(
    c,
    'Library and offline copies, no pictures (JSON)',
    'Thư viện và bản đọc offline, không kèm ảnh (JSON)',
  ),
  SaveFormat.zip => tr(
    c,
    'Full backup with pictures and offline copies (ZIP)',
    'Sao lưu đầy đủ, kèm ảnh và bản đọc offline (ZIP)',
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
  /// The full ZIP backup, offline copies included; what automatic backups
  /// write.
  Future<Uint8List> fullBackup() async {
    final copies = c.readingIds.isNotEmpty
        ? await c.allReadingCopies()
        : const <String, ReadingCopy>{};
    final pictures = await _pictures(library);
    return (await compute(_encode, (
      library,
      SaveFormat.zip,
      copies,
      pictures,
    ))).bytes;
  }

  /// The bytes of every picture [lib]'s items (and Trash items) use that
  /// this device still has.
  Future<Map<String, PortablePicture>> _pictures(SaveLibrary lib) async {
    final out = <String, PortablePicture>{};
    for (final id in mediaInUse(lib)) {
      final original = await c.store!.media(id);
      final preview = await c.store!.media(id, preview: true);
      if (original != null && preview != null)
        out[id] = PortablePicture(original, preview);
    }
    return out;
  }

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
    // Only what was picked: never Recently Deleted along with it.
    if (selected)
      lib = lib.copyWith(
        bookmarks: [
          for (final b in lib.bookmarks)
            if (view.selected.contains(b.id)) b,
        ],
        trash: const [],
        tombstones: const [],
      );
    await run(context, () async {
      // Full backups carry offline copies within the 30 MB budget.
      final full = format == SaveFormat.json || format == SaveFormat.zip;
      final copies = full && c.readingIds.isNotEmpty
          ? await c.allReadingCopies()
          : const <String, ReadingCopy>{};
      final pictures = format == SaveFormat.zip
          ? await _pictures(lib)
          : const <String, PortablePicture>{};
      final out = await compute(_encode, (lib, format, copies, pictures));
      final bytes = out.bytes;
      final uri = await files.exportBytes(
        'handy-bookmark.${format == SaveFormat.markdown ? 'md' : format.name}',
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
          [
            tr(
              context,
              '${lib.bookmarks.length} links saved to a file.',
              'Đã lưu ${lib.bookmarks.length} link ra file.',
            ),
            if (out.readingIncluded > 0)
              tr(
                context,
                '${out.readingIncluded} offline copies included.',
                'Kèm ${out.readingIncluded} bản đọc offline.',
              ),
            if (out.readingOmitted > 0)
              tr(
                context,
                '${out.readingOmitted} offline copies left out to stay under 30 MB.',
                '${out.readingOmitted} bản đọc offline bị bỏ ra để file dưới 30 MB.',
              ),
            if (out.picturesIncluded > 0)
              tr(
                context,
                '${out.picturesIncluded} pictures included.',
                'Kèm ${out.picturesIncluded} ảnh.',
              ),
            if (out.picturesOmitted > 0)
              tr(
                context,
                '${out.picturesOmitted} pictures (${(out.omittedPictureBytes / 1048576).toStringAsFixed(0)} MB) left out to stay under 256 MB; they are still on this device.',
                '${out.picturesOmitted} ảnh (${(out.omittedPictureBytes / 1048576).toStringAsFixed(0)} MB) bị bỏ ra để file dưới 256 MB; ảnh vẫn còn trên máy.',
              ),
            if (out.picturesMissing > 0)
              tr(
                context,
                '${out.picturesMissing} pictures are missing on this device and could not be included.',
                '${out.picturesMissing} ảnh không còn trên máy nên không thể đưa vào.',
              ),
            if (format != SaveFormat.zip &&
                lib.bookmarks.any((b) => b.media != null))
              tr(
                context,
                'Pictures need a ZIP backup.',
                'Muốn giữ ảnh, hãy sao lưu dạng ZIP.',
              ),
          ].join(' '),
        );
    });
  }

  /// Pocket's export (CSV, or the older ril_export.html): shows what it
  /// holds, then adds the new links into a "Pocket" collection. Only adds;
  /// nothing is replaced, and Undo takes it back.
  Future<void> importPocket(BuildContext context) => _importService(
    context,
    name: 'Pocket',
    read: _pocket,
    where: tr(
      context,
      'They go into a new collection named Pocket, with their tags and the date you saved them.',
      'Chúng vào bộ sưu tập mới tên Pocket, giữ thẻ và ngày bạn đã lưu.',
    ),
  );

  /// Raindrop.io's export (CSV or HTML): folders become collections
  /// (nested ones too), with tags, notes, excerpts, dates and favourites.
  Future<void> importRaindrop(BuildContext context) => _importService(
    context,
    name: 'Raindrop',
    read: _raindrop,
    where: tr(
      context,
      'Its folders become collections here; tags, notes, excerpts, favourites and saved dates are kept. Covers are not downloaded.',
      'Thư mục thành bộ sưu tập; giữ thẻ, ghi chú, đoạn trích, yêu thích và ngày lưu. Không tải ảnh bìa.',
    ),
  );

  /// Shows what another app's export holds, then adds only what is new.
  Future<void> _importService(
    BuildContext context, {
    required String name,
    required ImportPreview Function((Uint8List, SaveLibrary)) read,
    required String where,
  }) => run(context, () async {
    final file = await files.importBytes(
      extensions: ['csv', 'html', 'htm'],
      maxBytes: SavePortable.maxImportBytes,
    );
    if (file == null) return;
    final baseline = library;
    final preview = await compute(read, (file.bytes, baseline));
    if (!context.mounted) return;
    final archived = preview.library.bookmarks.where((b) => b.isArchived);
    final adding = preview.fresh(baseline);
    final fresh = adding.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tr(
            context,
            'Bring in $fresh links from $name?',
            'Nhập $fresh link từ $name?',
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
                '${preview.validCount} in the file: ${archived.length} archived (they arrive archived and read), ${preview.duplicateCount} already saved here, ${preview.invalidCount} could not be read.',
                '${preview.validCount} link trong file: ${archived.length} đã lưu trữ (nhập vào sẽ ở Lưu trữ, đã đọc), ${preview.duplicateCount} đã có sẵn, ${preview.invalidCount} không đọc được.',
              ),
            ),
            const SizedBox(height: HandySpace.m),
            Text(where),
            const SizedBox(height: HandySpace.m),
            for (final b in adding.take(5))
              Text(
                '· ${b.title.isEmpty ? b.sourceDomain : b.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Cancel', 'Hủy')),
          ),
          FilledButton(
            key: Key('${name.toLowerCase()}-add'),
            onPressed: fresh == 0 ? null : () => Navigator.pop(context, true),
            child: Text(tr(context, 'Add $fresh links', 'Thêm $fresh link')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await view.change((l) => preview.commit(l));
    if (context.mounted)
      undoMessage(
        context,
        tr(
          context,
          '$fresh links added from $name.',
          'Đã thêm $fresh link từ $name.',
        ),
      );
  });

  /// Reads a file, shows what it holds, then adds it or (asked twice)
  /// replaces everything. Nothing is written before the person chooses.
  Future<void> importLinks(BuildContext context) => run(context, () async {
    final file = await files.importBytes(
      extensions: ['json', 'zip', 'html', 'htm', 'csv', 'txt', 'md', 'hseal'],
      // A ZIP with pictures may be larger; the reader checks each format.
      maxBytes: SavePortable.maxBackupBytes,
    );
    if (file == null || !context.mounted) return;
    // A password-locked automatic backup opens to the same ZIP.
    final bytes = await openSealedBackup(context, file.bytes);
    if (bytes == null || !context.mounted) return;
    final name = file.name.toLowerCase().endsWith('.hseal')
        ? file.name.substring(0, file.name.length - 6)
        : file.name;
    final format = switch (name.split('.').last.toLowerCase()) {
      'zip' => SaveFormat.zip,
      'html' || 'htm' => SaveFormat.html,
      'csv' => SaveFormat.csv,
      'md' => SaveFormat.markdown,
      'txt' => SaveFormat.txt,
      _ => SaveFormat.json,
    };
    final baseline = library;
    final preview = await compute(_preview, (bytes, format, baseline));
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
            if (preview.pictures.isNotEmpty ||
                preview.invalidPictures > 0 ||
                preview.missingPictures > 0) ...[
              const SizedBox(height: HandySpace.s),
              Text(
                key: const Key('import-pictures'),
                [
                  if (preview.pictures.isNotEmpty)
                    tr(
                      context,
                      'With ${preview.pictures.length} pictures.',
                      'Kèm ${preview.pictures.length} ảnh.',
                    ),
                  if (preview.invalidPictures > 0)
                    tr(
                      context,
                      '${preview.invalidPictures} damaged pictures left out.',
                      '${preview.invalidPictures} ảnh hỏng, bỏ qua.',
                    ),
                  if (preview.missingPictures > 0)
                    tr(
                      context,
                      '${preview.missingPictures} pictures are not in this file; those items come without them.',
                      '${preview.missingPictures} ảnh không có trong file; các mục đó sẽ thiếu ảnh.',
                    ),
                ].join(' '),
              ),
            ],
            if (preview.readingCopies.isNotEmpty ||
                preview.invalidCopies > 0) ...[
              const SizedBox(height: HandySpace.s),
              Text(
                tr(
                  context,
                  'With ${preview.readingCopies.length} offline copies${preview.invalidCopies > 0 ? ' (${preview.invalidCopies} damaged, left out)' : ''}.',
                  'Kèm ${preview.readingCopies.length} bản đọc offline${preview.invalidCopies > 0 ? ' (${preview.invalidCopies} bản hỏng, bỏ qua)' : ''}.',
                ),
              ),
            ],
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
    // Pictures first, so no item ever points at a missing one. Those a merge
    // ends up not needing are reclaimed later.
    for (final e in preview.pictures.entries) {
      final ref = [
        ...preview.library.bookmarks,
        ...preview.library.trash,
      ].firstWhere((b) => b.media?.id == e.key).media!;
      await c.store!.putMedia(ref.toJson(), e.value.original, e.value.preview);
    }
    ImportResult? applied;
    await view.change((l) {
      if (strategy == ImportStrategy.replace && !identical(l, baseline)) {
        throw StateError(
          'The library changed meanwhile; import again / Thư viện vừa thay đổi; hãy nhập lại',
        );
      }
      applied = preview.apply(l, strategy: strategy);
      return applied!.library;
    });
    var copiesFailed = false;
    try {
      // After the links: each copy needs its link to exist.
      await c.putReadingCopies(applied!.readingCopies);
    } catch (_) {
      copiesFailed = true;
    }
    if (context.mounted)
      undoMessage(
        context,
        copiesFailed
            ? tr(
                context,
                'Links imported; the offline copies could not be stored.',
                'Đã nhập link; chưa lưu được các bản đọc offline.',
              )
            : tr(context, 'Links imported.', 'Đã nhập link.'),
      );
  });
}
