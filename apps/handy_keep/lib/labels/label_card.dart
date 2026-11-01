import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:handy_ui/kit.dart';

/// The label as it will be stuck on the box: white, QR beside the name, in
/// fixed ink so it prints the same in the dark theme.
class LabelCard extends StatelessWidget {
  final Uint8List png;
  final String kind, name, detail;
  const LabelCard({
    super.key,
    required this.png,
    required this.kind,
    required this.name,
    required this.detail,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const ink = Color(0xFF0A0A0A);
    return Container(
      padding: const EdgeInsets.all(HandySpace.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HandyColors.of(context).border),
        borderRadius: BorderRadius.circular(HandyRadius.card),
      ),
      child: Wrap(
        spacing: HandySpace.xl,
        runSpacing: HandySpace.l,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Image.memory(
            png,
            key: const Key('keep-label-qr'),
            width: 168,
            height: 168,
            filterQuality: FilterQuality.none,
            semanticLabel: tr(context, 'QR code for $name', 'Mã QR của $name'),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5F5F5F),
                  ),
                ),
                Text(
                  name,
                  style: theme.textTheme.headlineMedium?.copyWith(color: ink),
                ),
                const SizedBox(height: HandySpace.xs),
                Text(
                  detail,
                  style: theme.textTheme.bodyLarge?.copyWith(color: ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The card as a 3× PNG, sharp enough to print at sticker size.
Future<Uint8List> renderLabel(GlobalKey card) async {
  final boundary =
      card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
