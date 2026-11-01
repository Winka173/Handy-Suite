import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'l10n.dart';
import 'theme.dart';

/// The step's picture as large as its box allows, with a 22 px margin so
/// 44 px handles stay touchable at the corners. Overlays are placed in
/// picture coordinates.
class HandyPictureFrame extends StatelessWidget {
  final Uint8List bytes;
  final double ratio;
  final List<Widget> Function(Size picture) overlays;
  const HandyPictureFrame({
    super.key,
    required this.bytes,
    required this.ratio,
    required this.overlays,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final room = box.maxHeight.isFinite
          ? box.maxHeight - 44
          : MediaQuery.sizeOf(context).height * .62;
      final width = math.max(
            1.0,
            math.min(box.maxWidth - 44, math.max(120.0, room) * ratio),
          ),
          height = width / ratio;
      return Center(
        child: SizedBox(
          width: width + 44,
          height: height + 44,
          child: Stack(
            children: [
              Positioned(
                left: 22,
                top: 22,
                width: width,
                height: height,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color:
                          Theme.of(context).extension<HandyColors>()?.border ??
                          Theme.of(context).dividerColor,
                    ),
                  ),
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    cacheWidth: math.min(
                      2048,
                      (width * MediaQuery.devicePixelRatioOf(context)).ceil(),
                    ),
                    errorBuilder: (context, _, _) => Center(
                      child: Text(
                        tr(
                          context,
                          'This picture cannot be shown. Its file is unchanged; relink a valid PNG.',
                          'Không hiện được ảnh này. Tệp vẫn giữ nguyên; hãy gắn lại một PNG hợp lệ.',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ...overlays(Size(width, height)),
            ],
          ),
        ),
      );
    },
  );
}
