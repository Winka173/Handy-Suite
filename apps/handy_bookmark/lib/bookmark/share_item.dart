import 'package:flutter/foundation.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_files/share.dart';
import 'package:handy_ui/kit.dart';
import 'package:image/image.dart' as img;
import '../design/theme.dart';
import '../scope.dart';
import '../services/media_import.dart' show pictureMime;

/// The OS share sheet, as the item actions use it. Tests swap it.
abstract interface class ItemSharer {
  bool get supported;
  Future<LocalShareResult> text(
    String text, {
    String? subject,
    required Rect origin,
  });
  Future<LocalShareResult> bytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    required Rect origin,
  });
}

class _OsSharer implements ItemSharer {
  const _OsSharer();
  @override
  bool get supported => localShareSupported;
  @override
  Future<LocalShareResult> text(
    String text, {
    String? subject,
    required Rect origin,
  }) => const LocalShare().text(
    text,
    subject: subject,
    title: subject,
    origin: origin,
  );
  @override
  Future<LocalShareResult> bytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    required Rect origin,
  }) =>
      const LocalShare().bytes(name, bytes, mimeType: mimeType, origin: origin);
}

/// What the item actions share through; replaced in tests.
@visibleForTesting
ItemSharer itemSharer = const _OsSharer();

/// The address to hand on: tracking parameters (utm_…, fbclid…) and any
/// user name or password removed, the rest exactly as saved.
String shareableUrl(Bookmark b) {
  try {
    final clean = Uri.parse(UrlTools.normalize(b.originalUrl).normalizedUrl);
    return (clean.userInfo.isEmpty ? clean : clean.replace(userInfo: ''))
        .toString();
  } on FormatException {
    return b.originalUrl;
  }
}

/// The words a shared link carries: its title (when it has one) over the
/// clean address. Notes, tags and collections never leave.
String shareText(Bookmark b) {
  final url = shareableUrl(b);
  final title = b.title.trim();
  return title.isEmpty || title == url ? url : '$title\n$url';
}

/// True when [bytes] carry data beyond the pixels that can say where or
/// when a picture was taken: EXIF, XMP or IPTC in a JPEG; eXIf or text
/// chunks in a PNG; EXIF or XMP in a WebP. Only headers are read.
bool pictureCarriesMetadata(Uint8List bytes) {
  final b = bytes;
  int u16(int i) => (b[i] << 8) | b[i + 1];
  String tag(int i) => String.fromCharCodes(b.sublist(i, i + 4));
  switch (pictureMime(bytes)) {
    case 'image/jpeg':
      var i = 2;
      while (i + 4 <= b.length && b[i] == 0xFF) {
        final marker = b[i + 1];
        if (marker == 0xDA || marker == 0xD9) return false;
        if (marker == 0xFF) {
          i++;
          continue;
        }
        if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
          i += 2;
          continue;
        }
        // APP1 holds EXIF and XMP; APP13 holds IPTC (which can name a place).
        if (marker == 0xE1 || marker == 0xED) return true;
        i += 2 + u16(i + 2);
      }
      return false;
    case 'image/png':
      var i = 8;
      while (i + 8 <= b.length) {
        final length =
            (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
        final type = tag(i + 4);
        if (const {'eXIf', 'tEXt', 'iTXt', 'zTXt'}.contains(type)) return true;
        if (type == 'IEND') return false;
        i += 12 + length;
      }
      return false;
    case 'image/webp':
      var i = 12;
      while (i + 8 <= b.length) {
        final type = tag(i);
        if (type == 'EXIF' || type == 'XMP ') return true;
        final size =
            b[i + 4] | (b[i + 5] << 8) | (b[i + 6] << 16) | (b[i + 7] << 24);
        i += 8 + size + (size.isOdd ? 1 : 0);
      }
      return false;
  }
  return false;
}

/// A picture made fit to share: the same pixels turned upright and saved
/// again with no camera, place or time data. PNG stays PNG (and a WebP
/// with see-through parts becomes PNG); the rest become JPEG. Null when
/// the bytes are not a picture. Run it off the UI isolate.
({Uint8List bytes, String mime, String extension})? cleanPictureForShare(
  Uint8List bytes,
) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final picture = img.bakeOrientation(decoded)
      ..exif = img.ExifData()
      ..textData = null;
    if (pictureMime(bytes) == 'image/png' || picture.hasAlpha)
      return (
        bytes: img.encodePng(picture),
        mime: 'image/png',
        extension: 'png',
      );
    return (
      bytes: img.encodeJpg(picture, quality: 92),
      mime: 'image/jpeg',
      extension: 'jpg',
    );
  } catch (_) {
    return null;
  }
}

String _extension(String mime) => switch (mime) {
  'image/png' => 'png',
  'image/webp' => 'webp',
  _ => 'jpg',
};

/// The global rectangle of [context]'s box: where an iPad or Mac share
/// sheet points.
Rect shareOrigin(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize && box.size.width > 0)
    return box.localToGlobal(Offset.zero) & box.size;
  final size = MediaQuery.sizeOf(context);
  return Rect.fromCenter(center: size.center(Offset.zero), width: 1, height: 1);
}

/// How a picture leaves the device.
enum PictureShare { clean, original, preview }

extension ShareItem on SaveScope {
  /// Shares [b] through the OS share sheet: a link as its title and clean
  /// address, a picture as its file. Says plainly when nothing was shared.
  Future<void> shareItem(BuildContext context, Bookmark b, {Rect? origin}) {
    final at = origin ?? shareOrigin(context);
    return b.isImage && b.media != null
        ? _sharePicture(context, b, at)
        : _shareLink(context, b, at);
  }

  Future<void> _shareLink(BuildContext context, Bookmark b, Rect at) async {
    if (!b.hasUrl) return;
    if (!itemSharer.supported) return _unsupported(context, b);
    try {
      final result = await itemSharer.text(
        shareText(b),
        subject: b.title.trim().isEmpty ? null : b.title.trim(),
        origin: at,
      );
      if (context.mounted) _report(context, result);
    } on UnsupportedError {
      if (context.mounted) _unsupported(context, b);
    } catch (_) {
      if (context.mounted) _failed(context);
    }
  }

  Future<void> _sharePicture(BuildContext context, Bookmark b, Rect at) async {
    if (!itemSharer.supported) return _unsupported(context, b);
    final media = b.media!;
    final original = await c.mediaOriginal(media.id);
    if (!context.mounted) return;
    Uint8List? preview;
    if (original == null) {
      preview = await c.mediaPreview(media.id);
      if (!context.mounted) return;
      if (preview == null) {
        showHandyMessage(
          context,
          tr(
            context,
            'This picture is missing on this device, so there is nothing to share. Restore a full backup to bring it back.',
            'Ảnh này không còn trên máy nên chưa chia sẻ được. Khôi phục một bản sao lưu đầy đủ để lấy lại.',
          ),
        );
        return;
      }
    }
    final carries = original != null && pictureCarriesMetadata(original);
    ({Uint8List bytes, String mime, String extension})? file;
    if (original != null && !carries) {
      // Nothing beyond the pixels: the original is already safe to send.
      file = (
        bytes: original,
        mime: media.mime,
        extension: _extension(media.mime),
      );
    } else {
      file = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (context) => PictureShareSheet(
          original: original,
          preview: preview,
          mime: media.mime,
        ),
      );
    }
    if (file == null || !context.mounted) return;
    final base = b.title.trim().isEmpty
        ? (media.name.isEmpty
              ? 'picture'
              : media.name.replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), ''))
        : b.title.trim();
    try {
      final result = await itemSharer.bytes(
        '$base.${file.extension}',
        file.bytes,
        mimeType: file.mime,
        origin: at,
      );
      if (context.mounted) _report(context, result);
    } on UnsupportedError {
      if (context.mounted) _unsupported(context, b);
    } on FormatException {
      if (context.mounted)
        showHandyMessage(
          context,
          tr(
            context,
            'This picture is too large to share from here (30 MB at most). Nothing was changed.',
            'Ảnh quá lớn để chia sẻ từ đây (tối đa 30 MB). Không có gì thay đổi.',
          ),
        );
    } catch (_) {
      if (context.mounted) _failed(context);
    }
  }

  /// A finished or dismissed sheet needs no words; only an unconfirmed
  /// one does, and it never claims the item was sent.
  void _report(BuildContext context, LocalShareResult result) {
    if (result != LocalShareResult.unknown) return;
    showHandyMessage(
      context,
      tr(
        context,
        'Could not confirm that it was shared.',
        'Chưa xác nhận được là đã chia sẻ.',
      ),
    );
  }

  void _failed(BuildContext context) => showHandyMessage(
    context,
    tr(
      context,
      'Could not open sharing. Nothing was sent or changed.',
      'Chưa mở được phần chia sẻ. Chưa gửi gì và không có gì thay đổi.',
    ),
  );

  /// No share sheet here: say so, and for a link offer to copy it instead
  /// (a copy is a copy, never reported as shared).
  void _unsupported(BuildContext context, Bookmark b) {
    final text = b.hasUrl && !b.isImage
        ? tr(
            context,
            'Sharing is not available on this device. Nothing was sent.',
            'Thiết bị này chưa hỗ trợ chia sẻ. Chưa gửi gì.',
          )
        : tr(
            context,
            'Sharing is not available on this device. Nothing was sent; use Export in Settings for a copy of the picture.',
            'Thiết bị này chưa hỗ trợ chia sẻ. Chưa gửi gì; dùng Xuất trong Cài đặt để có bản sao ảnh.',
          );
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: b.hasUrl && !b.isImage
              ? SnackBarAction(
                  label: tr(context, 'Copy link', 'Chép link'),
                  onPressed: () => copyToClipboard(context, shareableUrl(b)),
                )
              : null,
        ),
      );
  }
}

/// How to send a picture: without its location (re-saved, the default) or
/// as the original file. When only the small preview is on this device it
/// says so and offers that.
class PictureShareSheet extends StatefulWidget {
  final Uint8List? original, preview;
  final String mime;
  const PictureShareSheet({
    super.key,
    required this.original,
    required this.preview,
    required this.mime,
  });
  @override
  State<PictureShareSheet> createState() => _PictureShareSheetState();
}

class _PictureShareSheetState extends State<PictureShareSheet> {
  late PictureShare choice = widget.original == null
      ? PictureShare.preview
      : PictureShare.clean;
  bool busy = false;
  String? error;

  Future<void> _go() async {
    setState(() {
      busy = true;
      error = null;
    });
    ({Uint8List bytes, String mime, String extension})? file;
    switch (choice) {
      case PictureShare.original:
        file = (
          bytes: widget.original!,
          mime: widget.mime,
          extension: _extension(widget.mime),
        );
      case PictureShare.preview:
        // Previews are made without camera, place or time data.
        file = (bytes: widget.preview!, mime: 'image/jpeg', extension: 'jpg');
      case PictureShare.clean:
        file = await compute(cleanPictureForShare, widget.original!);
    }
    if (!mounted) return;
    if (file == null) {
      setState(() {
        busy = false;
        error = tr(
          context,
          'This picture could not be re-saved. Nothing was sent.',
          'Chưa lưu lại được ảnh này. Chưa gửi gì.',
        );
      });
      return;
    }
    Navigator.pop(context, file);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final previewOnly = widget.original == null;
    Widget option(
      PictureShare value,
      String key,
      IconData icon,
      String title,
      String note,
    ) {
      final on = choice == value;
      final dark = theme.brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: on ? p.tint : (dark ? p.raised : p.canvas),
          borderRadius: BorderRadius.circular(BookmarkRadii.item),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            inMutuallyExclusiveGroup: true,
            checked: on,
            child: InkWell(
              key: Key(key),
              onTap: busy ? null : () => setState(() => choice = value),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        icon,
                        size: 22,
                        color: on ? (dark ? p.primary : p.pressed) : p.muted,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: p.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            note,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: p.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      on
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 22,
                      color: on ? (dark ? p.primary : p.pressed) : p.control,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        key: const Key('share-picture-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              tr(context, 'Share picture', 'Chia sẻ ảnh'),
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            previewOnly
                ? tr(
                    context,
                    'Only a small preview of this picture is on this device. The original is not here to send.',
                    'Máy này chỉ còn ảnh xem trước cỡ nhỏ. Không có ảnh gốc để gửi.',
                  )
                : tr(
                    context,
                    'This picture carries data from the camera, which can include where and when it was taken.',
                    'Ảnh này kèm dữ liệu từ máy ảnh, có thể gồm nơi và lúc chụp.',
                  ),
            key: Key(previewOnly ? 'share-preview-only' : 'share-has-exif'),
            style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
          ),
          const SizedBox(height: 16),
          if (previewOnly)
            option(
              PictureShare.preview,
              'share-picture-preview',
              Icons.photo_size_select_small_outlined,
              tr(context, 'Share the small preview', 'Chia sẻ ảnh xem trước'),
              tr(
                context,
                'Up to 640 px, with no camera, place or time data.',
                'Tối đa 640 px, không kèm dữ liệu máy ảnh, vị trí hay thời gian.',
              ),
            )
          else ...[
            option(
              PictureShare.clean,
              'share-picture-clean',
              Icons.location_off_outlined,
              tr(context, 'Share without location', 'Chia sẻ không kèm vị trí'),
              tr(
                context,
                'Re-saved at full size with no camera, place or time data.',
                'Lưu lại cỡ đầy đủ, không kèm dữ liệu máy ảnh, vị trí hay thời gian.',
              ),
            ),
            option(
              PictureShare.original,
              'share-picture-original',
              Icons.insert_drive_file_outlined,
              tr(context, 'Share original file', 'Chia sẻ tệp gốc'),
              tr(
                context,
                'Exactly as saved, with everything the camera wrote into it.',
                'Đúng như đã lưu, kèm mọi thứ máy ảnh ghi vào.',
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 4),
            HandyNotice(error!, tone: HandyTone.error),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('share-picture-go'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: busy ? null : _go,
            icon: busy
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: tr(context, 'Preparing', 'Đang chuẩn bị'),
                    ),
                  )
                : const Icon(Icons.ios_share_rounded, size: 20),
            label: Text(tr(context, 'Share', 'Chia sẻ')),
          ),
        ],
      ),
    );
  }
}
