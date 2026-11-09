import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:image/image.dart' as img;
import '../design/theme.dart';
import '../scope.dart';
import 'collection_actions.dart';
import '../ui/collection_picker.dart' show collectionHue;

/// At most this many pictures go into one shared page.
const sharedPictureLimit = 200;

/// A picture as it may leave the device: decoded, turned upright, at most
/// 480 px, re-encoded as JPEG with no camera, place or time data. Null
/// when the bytes are not a picture.
Uint8List? sharablePicture(Uint8List bytes) => sharedPictureOf(bytes)?.jpeg;

/// [sharablePicture] with the size it came out at (the receiving app needs
/// it to keep a picture item).
SharedPicture? sharedPictureOf(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    var picture = img.bakeOrientation(decoded);
    final edge = picture.width > picture.height
        ? picture.width
        : picture.height;
    if (edge > 480)
      picture = img.copyResize(
        picture,
        width: picture.width >= picture.height ? 480 : null,
        height: picture.height > picture.width ? 480 : null,
        interpolation: img.Interpolation.average,
      );
    picture.exif = img.ExifData();
    return SharedPicture(
      img.encodeJpg(picture, quality: 78),
      picture.width,
      picture.height,
    );
  } catch (_) {
    return null;
  }
}

Map<String, SharedPicture> _strip(Map<String, Uint8List> raw) => {
  for (final e in raw.entries)
    if (sharedPictureOf(e.value) case final clean?) e.key: clean,
};

extension ShareCollection on SaveScope {
  /// A collection's menu › Send: the send sheet with it picked (a folder
  /// travels with its collection).
  Future<void> shareCollection(BuildContext context, String id) {
    final c = library.collections.where((c) => c.id == id).firstOrNull;
    return sendCollections(
      context,
      chosen: {if (c != null) c.parentId ?? c.id},
    );
  }

  /// Send collections: pick one or several, then share one file. A browser
  /// shows it as a page; Handy Bookmark (Settings › Import) adds it.
  Future<void> sendCollections(
    BuildContext context, {
    Set<String> chosen = const {},
  }) async {
    final tops = [
      for (final c in library.collections)
        if (c.parentId == null) c,
    ]..sort((a, b) => a.position.compareTo(b.position));
    if (tops.isEmpty) return;
    final picked = {...chosen};
    var notes = false;
    final live = [
      for (final b in library.bookmarks)
        if (!b.isArchived) b,
    ];
    final folderOf = {
      for (final c in library.collections)
        if (c.parentId != null) c.id: c.parentId!,
    };
    int count(String id) => live
        .where((b) => b.collectionId == id || folderOf[b.collectionId] == id)
        .length;
    int folders(String id) => folderOf.values.where((p) => p == id).length;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) => StatefulBuilder(
        builder: (context, set) => _SendSheet(
          tops: tops,
          picked: picked,
          notes: notes,
          count: count,
          folders: folders,
          hue: (id) => collectionHue(library, id),
          onPick: (id, on) =>
              set(() => on ? picked.add(id) : picked.remove(id)),
          onAll: (on) => set(() {
            picked.clear();
            if (on) picked.addAll(tops.map((c) => c.id));
          }),
          onNotes: (v) => set(() => notes = v),
        ),
      ),
    );
    if (ok != true || picked.isEmpty || !context.mounted) return;
    final ids = [
      for (final c in tops)
        if (picked.contains(c.id)) c.id,
    ];
    await run(context, () async {
      final html = await sharedPage(
        ids,
        notes: notes,
        vietnamese: Localizations.localeOf(context).languageCode == 'vi',
      );
      if (!context.mounted) return;
      String clean(String s) =>
          s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
      final one = ids.length == 1
          ? clean(tops.firstWhere((c) => c.id == ids.single).name)
          : '';
      await shareFile(
        context,
        name: ids.length == 1
            ? '${one.isEmpty ? 'collection' : one}.html'
            : 'Handy Bookmark - ${ids.length} ${tr(context, 'collections', 'bo suu tap')}.html',
        mimeType: 'text/html',
        bytes: Uint8List.fromList(utf8.encode(html)),
      );
    });
  }

  /// The file itself: [ids] with their folders, every picture cleaned on a
  /// worker.
  Future<String> sharedPage(
    List<String> ids, {
    bool notes = false,
    bool vietnamese = false,
  }) async {
    final all = <String>{...ids};
    for (final c in library.collections) {
      if (c.parentId != null && ids.contains(c.parentId)) all.add(c.id);
    }
    final raw = <String, Uint8List>{};
    for (final b in library.bookmarks) {
      if (raw.length >= sharedPictureLimit) break;
      if (b.isArchived || !all.contains(b.collectionId)) continue;
      final bytes = b.media != null
          ? await c.mediaPreview(b.media!.id)
          : await c.thumbnail(b.id);
      if (bytes != null) raw[b.id] = bytes;
    }
    final pictures = await compute(_strip, raw);
    return sharedCollectionsPage(
      library,
      ids,
      pictures: pictures,
      notes: notes,
      vietnamese: vietnamese,
      now: DateTime.now(),
    );
  }
}

/// A collection held down (or right-clicked): its quick actions, Send to
/// friends first.
Future<void> showCollectionQuick(
  BuildContext context,
  SaveScope scope,
  SaveCollection collection,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (sheet) => SafeArea(
    child: Column(
      key: const Key('collection-quick'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            collection.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(sheet).textTheme.titleLarge,
          ),
        ),
        ListTile(
          key: const Key('collection-quick-send'),
          leading: const Icon(Icons.send_rounded),
          title: Text(tr(sheet, 'Send to friends', 'Gửi cho bạn bè')),
          subtitle: Text(
            tr(
              sheet,
              'One file they open, or add to their Handy Bookmark',
              'Một tệp để mở xem, hoặc thêm vào Handy Bookmark của họ',
            ),
          ),
          onTap: () {
            Navigator.pop(sheet);
            scope.shareCollection(context, collection.id);
          },
        ),
        ListTile(
          key: const Key('collection-quick-edit'),
          leading: const Icon(Icons.edit_outlined),
          title: Text(tr(sheet, 'Edit collection', 'Sửa bộ sưu tập')),
          subtitle: Text(
            tr(sheet, 'Name, icon, colour', 'Tên, biểu tượng, màu'),
          ),
          onTap: () {
            Navigator.pop(sheet);
            scope.editCollection(context, collection);
          },
        ),
        const SizedBox(height: HandySpace.s),
      ],
    ),
  ),
);

/// The send sheet: the collections to pick, what goes and what stays, the
/// notes switch, and one Send action that says how much will go.
class _SendSheet extends StatelessWidget {
  final List<SaveCollection> tops;
  final Set<String> picked;
  final bool notes;
  final int Function(String) count, folders, hue;
  final void Function(String, bool) onPick;
  final ValueChanged<bool> onAll, onNotes;
  const _SendSheet({
    required this.tops,
    required this.picked,
    required this.notes,
    required this.count,
    required this.folders,
    required this.hue,
    required this.onPick,
    required this.onAll,
    required this.onNotes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final links = picked.fold(0, (n, id) => n + count(id));
    final all = picked.length == tops.length;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: p.sage),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
    String items(int n) =>
        tr(context, '$n ${n == 1 ? 'item' : 'items'}', '$n mục');
    return Column(
      key: const Key('send-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            children: [
              Semantics(
                header: true,
                child: Text(
                  tr(context, 'Send collections', 'Gửi bộ sưu tập'),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  context,
                  'One file. Friends open it in a browser, or add it to their Handy Bookmark.',
                  'Một tệp. Bạn bè mở bằng trình duyệt, hoặc thêm vào Handy Bookmark của họ.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(
                        context,
                        '${picked.length} of ${tops.length} picked',
                        'Đã chọn ${picked.length}/${tops.length}',
                      ),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    key: const Key('send-all'),
                    onPressed: () => onAll(!all),
                    child: Text(
                      all
                          ? tr(context, 'Clear', 'Bỏ chọn')
                          : tr(context, 'Pick all', 'Chọn tất cả'),
                    ),
                  ),
                ],
              ),
              for (final c in tops)
                CheckboxListTile(
                  key: Key('send-pick-${c.id}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: picked.contains(c.id),
                  onChanged: (v) => onPick(c.id, v == true),
                  // The collection's colour as a dot beside its name.
                  title: Row(
                    children: [
                      HandyDot(hue(c.id), size: 10),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    [
                      items(count(c.id)),
                      if (folders(c.id) > 0)
                        tr(
                          context,
                          '${folders(c.id)} ${folders(c.id) == 1 ? 'folder' : 'folders'}',
                          '${folders(c.id)} thư mục',
                        ),
                    ].join(' · '),
                  ),
                ),
              const SizedBox(height: 12),
              point(
                Icons.check,
                tr(
                  context,
                  'Titles, links, sources and pictures (made small, without camera, place or time data), with their folders',
                  'Tiêu đề, link, nguồn và ảnh (thu nhỏ, không kèm dữ liệu máy ảnh, vị trí, thời gian), cùng các thư mục',
                ),
              ),
              point(
                Icons.remove,
                tr(
                  context,
                  'Tags, reminders, what you have read and the collections you leave out stay here',
                  'Thẻ, hẹn nhắc, trạng thái đã đọc và các bộ sưu tập không chọn ở lại máy',
                ),
              ),
              Material(
                color: theme.brightness == Brightness.dark
                    ? p.raised
                    : p.canvas,
                borderRadius: BorderRadius.circular(BookmarkRadii.item),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile.adaptive(
                  key: const Key('share-notes'),
                  title: Text(
                    tr(context, 'Include my notes', 'Kèm ghi chú của tôi'),
                  ),
                  subtitle: Text(
                    notes
                        ? tr(
                            context,
                            'Your notes go into the file',
                            'Ghi chú sẽ nằm trong tệp',
                          )
                        : tr(
                            context,
                            'Your notes stay private',
                            'Ghi chú vẫn là của riêng bạn',
                          ),
                  ),
                  value: notes,
                  onChanged: onNotes,
                ),
              ),
              const SizedBox(height: 12),
              HandyNotice(
                tr(
                  context,
                  'Whoever gets the file can see every link in it, and pass it on.',
                  'Ai nhận được tệp đều thấy mọi link bên trong, và có thể gửi tiếp.',
                ),
                tone: HandyTone.warning,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
            key: const Key('share-page'),
            onPressed: picked.isEmpty
                ? null
                : () => Navigator.pop(context, true),
            icon: const Icon(Icons.send_rounded, size: 20),
            label: Text(
              picked.isEmpty
                  ? tr(context, 'Pick a collection', 'Chọn một bộ sưu tập')
                  : tr(
                      context,
                      'Send ${picked.length == 1 ? '1 collection' : '${picked.length} collections'} · ${items(links)}',
                      'Gửi ${picked.length} bộ sưu tập · ${items(links)}',
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
