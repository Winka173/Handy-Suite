import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:handy_core/handy_core.dart';
import 'package:share_plus/share_plus.dart';

enum LocalShareResult { selected, dismissed, unknown }

bool get localShareSupported =>
    kIsWeb ||
    {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.windows,
    }.contains(defaultTargetPlatform);

class LocalShare {
  final SharePlus? client;
  const LocalShare({this.client});
  Future<LocalShareResult> bytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    required Rect origin,
    CancellationToken? cancellation,
  }) async {
    cancellation?.check();
    if (!localShareSupported)
      throw UnsupportedError('Use Export on this platform');
    final mime = mimeType.split(';').first.trim().toLowerCase();
    if (bytes.isEmpty ||
        bytes.length > 30000000 ||
        !RegExp(r'^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$').hasMatch(mime) ||
        ![
          origin.left,
          origin.top,
          origin.width,
          origin.height,
        ].every((v) => v.isFinite) ||
        origin.width <= 0 ||
        origin.height <= 0)
      throw const FormatException(
        'Share requires a valid file, MIME type and origin; limit 30 MB',
      );
    final safeName = safeFilename(name), snapshot = Uint8List.fromList(bytes);
    final result = await (client ?? SharePlus.instance).share(
      ShareParams(
        files: [XFile.fromData(snapshot, mimeType: mime, name: safeName)],
        fileNameOverrides: [safeName],
        sharePositionOrigin: origin,
        downloadFallbackEnabled: false,
        mailToFallbackEnabled: false,
      ),
    );
    cancellation?.check();
    return _result(result);
  }

  /// Opens the OS share sheet with [text] (for example a title and a link)
  /// after an explicit user action. [subject] fills an e-mail subject and
  /// [title] the sheet's own title where the platform has one. No download
  /// or e-mail fallback runs, so a missing share sheet is reported, never
  /// silently replaced.
  Future<LocalShareResult> text(
    String text, {
    String? subject,
    String? title,
    required Rect origin,
    CancellationToken? cancellation,
  }) async {
    cancellation?.check();
    if (!localShareSupported)
      throw UnsupportedError('Sharing is not available on this platform');
    final body = text.trim();
    if (body.isEmpty ||
        body.length > 100000 ||
        ![
          origin.left,
          origin.top,
          origin.width,
          origin.height,
        ].every((v) => v.isFinite) ||
        origin.width <= 0 ||
        origin.height <= 0)
      throw const FormatException(
        'Share requires text of 1 to 100000 characters and a valid origin',
      );
    String? short(String? value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return null;
      return v.length > 300 ? v.substring(0, 300) : v;
    }

    final result = await (client ?? SharePlus.instance).share(
      ShareParams(
        text: body,
        subject: short(subject),
        title: short(title),
        sharePositionOrigin: origin,
        downloadFallbackEnabled: false,
        mailToFallbackEnabled: false,
      ),
    );
    cancellation?.check();
    return _result(result);
  }

  static LocalShareResult _result(ShareResult result) =>
      switch (result.status) {
        ShareResultStatus.success => LocalShareResult.selected,
        ShareResultStatus.dismissed => LocalShareResult.dismissed,
        ShareResultStatus.unavailable => LocalShareResult.unknown,
      };
}

/// Shares a snapshot only after the user presses this explicit action.
class ShareOutputButton extends StatefulWidget {
  final String name, mimeType;
  final Uint8List Function() bytes;
  final bool enabled;
  const ShareOutputButton({
    super.key,
    required this.name,
    required this.mimeType,
    required this.bytes,
    this.enabled = true,
  });
  @override
  State<ShareOutputButton> createState() => _ShareOutputButtonState();
}

class _ShareOutputButtonState extends State<ShareOutputButton> {
  bool busy = false;
  String tr(String en, String vi) =>
      Localizations.localeOf(context).languageCode == 'vi' ? vi : en;
  @override
  Widget build(BuildContext context) {
    if (!localShareSupported) return const SizedBox.shrink();
    return OutlinedButton.icon(
      icon: const Icon(Icons.share_outlined),
      onPressed: !widget.enabled || busy
          ? null
          : () async {
              setState(() => busy = true);
              try {
                final box = context.findRenderObject() as RenderBox;
                final result = await const LocalShare().bytes(
                  widget.name,
                  widget.bytes(),
                  mimeType: widget.mimeType,
                  origin: box.localToGlobal(Offset.zero) & box.size,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(switch (result) {
                      LocalShareResult.selected => tr(
                        'Share action selected',
                        'Đã chọn thao tác chia sẻ',
                      ),
                      LocalShareResult.dismissed => tr(
                        'Share canceled',
                        'Đã hủy chia sẻ',
                      ),
                      LocalShareResult.unknown => tr(
                        'Share result unavailable; use Export if needed',
                        'Chưa có kết quả chia sẻ; có thể dùng Xuất file',
                      ),
                    }),
                  ),
                );
              } catch (_) {
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tr(
                          'Could not share this file. Export a copy instead. Source data was preserved.',
                          'Không thể chia sẻ file này. Hãy xuất một bản sao. Giữ nguyên dữ liệu nguồn.',
                        ),
                      ),
                    ),
                  );
              } finally {
                if (mounted) setState(() => busy = false);
              }
            },
      label: Text(
        busy
            ? tr('Opening share sheet…', 'Đang mở chia sẻ…')
            : tr('Share file', 'Chia sẻ file'),
      ),
    );
  }
}
