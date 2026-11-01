import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:handy_files/share.dart';
import 'l10n.dart';
import 'widgets.dart';

export 'package:handy_files/share.dart' show localShareSupported;

/// Shares a snapshot through the OS sheet after an explicit tap. [context]
/// must belong to the tapped control so tablets anchor the sheet to it.
Future<void> shareFile(
  BuildContext context, {
  required String name,
  required String mimeType,
  required Uint8List bytes,
}) async {
  try {
    final box = context.findRenderObject() as RenderBox;
    final result = await const LocalShare().bytes(
      name,
      bytes,
      mimeType: mimeType,
      origin: box.localToGlobal(Offset.zero) & box.size,
    );
    if (context.mounted && result == LocalShareResult.unknown)
      showHandyMessage(
        context,
        tr(
          context,
          'Could not confirm sharing. Save a copy if you need one.',
          'Chưa xác nhận được việc chia sẻ. Hãy lưu một bản nếu cần.',
        ),
      );
  } catch (_) {
    if (context.mounted)
      showHandyMessage(
        context,
        tr(
          context,
          'Could not share. Save a copy instead; nothing was changed.',
          'Chưa chia sẻ được. Hãy lưu một bản; không có gì thay đổi.',
        ),
      );
  }
}

/// Outlined icon button that shares; hidden where the OS has no share sheet.
class HandyShareButton extends StatelessWidget {
  final String name, mimeType;
  final Uint8List Function()? bytes;
  const HandyShareButton({
    super.key,
    required this.name,
    required this.mimeType,
    required this.bytes,
  });
  @override
  Widget build(BuildContext context) {
    if (!localShareSupported) return const SizedBox.shrink();
    return Builder(
      builder: (context) => IconButton.outlined(
        key: const Key('share'),
        tooltip: tr(context, 'Share', 'Chia sẻ'),
        icon: const Icon(Icons.ios_share, size: 20),
        onPressed: bytes == null
            ? null
            : () => shareFile(
                context,
                name: name,
                mimeType: mimeType,
                bytes: bytes!(),
              ),
      ),
    );
  }
}
