import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:image/image.dart' as img;
import '../design/theme.dart';
import '../scope.dart';

/// At most this many pictures go into one shared page.
const sharedPictureLimit = 200;

/// A picture as it may leave the device: decoded, turned upright, at most
/// 480 px, re-encoded as JPEG with no camera, place or time data. Null
/// when the bytes are not a picture.
Uint8List? sharablePicture(Uint8List bytes) {
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
    return img.encodeJpg(picture, quality: 78);
  } catch (_) {
    return null;
  }
}

Map<String, Uint8List> _strip(Map<String, Uint8List> raw) => {
  for (final e in raw.entries)
    if (sharablePicture(e.value) case final clean?) e.key: clean,
};

extension ShareCollection on SaveScope {
  /// Asks what to include, then shares the collection as one HTML page.
  Future<void> shareCollection(BuildContext context, String id) async {
    final col = library.collections.where((c) => c.id == id).firstOrNull;
    if (col == null) return;
    var notes = false;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) => StatefulBuilder(
        builder: (context, set) {
          final theme = Theme.of(context);
          final p = BookmarkPalette.of(context);
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
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    tr(context, 'Share “${col.name}”', 'Chia sẻ “${col.name}”'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(
                    context,
                    'As one page anyone can open in a browser.',
                    'Thành một trang ai cũng mở được bằng trình duyệt.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                ),
                const SizedBox(height: 20),
                point(
                  Icons.check,
                  tr(
                    context,
                    'Titles, links and where they are from, with its folders',
                    'Tiêu đề, link và nguồn, cùng các thư mục của nó',
                  ),
                ),
                point(
                  Icons.check,
                  tr(
                    context,
                    'Pictures, made small, without camera, place or time data',
                    'Ảnh, thu nhỏ, không kèm dữ liệu máy ảnh, vị trí hay thời gian',
                  ),
                ),
                point(
                  Icons.remove,
                  tr(
                    context,
                    'Tags, reminders and your other collections stay here',
                    'Thẻ, hẹn nhắc và các bộ sưu tập khác ở lại máy',
                  ),
                ),
                const SizedBox(height: 6),
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
                              'Your notes go into the page',
                              'Ghi chú sẽ nằm trong trang',
                            )
                          : tr(
                              context,
                              'Your notes stay private',
                              'Ghi chú vẫn là của riêng bạn',
                            ),
                    ),
                    value: notes,
                    onChanged: (v) => set(() => notes = v),
                  ),
                ),
                const SizedBox(height: 12),
                HandyNotice(
                  tr(
                    context,
                    'Whoever gets the file can see every link in it, and pass it on.',
                    'Ai nhận được file đều thấy mọi link bên trong, và có thể gửi tiếp.',
                  ),
                  tone: HandyTone.warning,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('share-page'),
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  label: Text(tr(context, 'Share page', 'Chia sẻ trang')),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (ok != true || !context.mounted) return;
    await run(context, () async {
      final html = await sharedPage(
        id,
        notes: notes,
        vietnamese: Localizations.localeOf(context).languageCode == 'vi',
      );
      if (!context.mounted) return;
      final name = col.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
      await shareFile(
        context,
        name: '${name.isEmpty ? 'collection' : name}.html',
        mimeType: 'text/html',
        bytes: Uint8List.fromList(utf8.encode(html)),
      );
    });
  }

  /// The page itself, with every picture cleaned on a worker.
  Future<String> sharedPage(
    String id, {
    bool notes = false,
    bool vietnamese = false,
  }) async {
    final ids = <String>{id};
    for (var grew = true; grew;) {
      grew = false;
      for (final c in library.collections) {
        if (c.parentId != null && ids.contains(c.parentId) && ids.add(c.id))
          grew = true;
      }
    }
    final raw = <String, Uint8List>{};
    for (final b in library.bookmarks) {
      if (raw.length >= sharedPictureLimit) break;
      if (b.isArchived || !ids.contains(b.collectionId)) continue;
      final bytes = b.media != null
          ? await c.mediaPreview(b.media!.id)
          : await c.thumbnail(b.id);
      if (bytes != null) raw[b.id] = bytes;
    }
    final pictures = await compute(_strip, raw);
    return collectionPage(
      library,
      id,
      pictures: pictures,
      notes: notes,
      vietnamese: vietnamese,
      now: DateTime.now(),
    );
  }
}
