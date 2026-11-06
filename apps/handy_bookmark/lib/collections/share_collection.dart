import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:image/image.dart' as img;
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(
            tr(
              context,
              'Share ${col.name} as a page',
              'Chia sẻ ${col.name} thành một trang',
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
                  'One file anyone can open: titles, links, sources and pictures of this collection and the ones inside it. Pictures are saved again small, without camera, place or time data. Tags, reminders and other collections stay here.',
                  'Một file ai cũng mở được: tiêu đề, link, nguồn và ảnh của bộ sưu tập này cùng các bộ sưu tập bên trong. Ảnh được lưu lại cỡ nhỏ, không kèm dữ liệu máy ảnh, vị trí hay thời gian. Thẻ, hẹn nhắc và bộ sưu tập khác ở lại máy.',
                ),
              ),
              SwitchListTile.adaptive(
                key: const Key('share-notes'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  tr(context, 'Include my notes', 'Kèm ghi chú của tôi'),
                ),
                value: notes,
                onChanged: (v) => set(() => notes = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'Cancel', 'Hủy')),
            ),
            FilledButton(
              key: const Key('share-page'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, 'Share', 'Chia sẻ')),
            ),
          ],
        ),
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
