import 'dart:typed_data';
import 'package:handy_ui/kit.dart';

/// A sheet of paper: A4 proportions, white even in the dark theme, a
/// hairline edge and the faintest shadow, because it lies on the desk.
/// Holds a page image, or the first lines of a text.
class Paper extends StatelessWidget {
  final double width;
  final Uint8List? image;
  final String? text;
  final bool selected;

  /// How the image meets the sheet: pages fill it, PDF pages fit inside.
  final BoxFit fit;
  const Paper({
    super.key,
    required this.width,
    this.image,
    this.text,
    this.selected = false,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: HandyMotion.of(context, HandyMotion.short),
      width: width,
      height: width * 1.414,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: selected ? primary : c.border,
          width: selected ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: image != null
          ? Image.memory(
              image!,
              fit: fit,
              gaplessPlayback: true,
              cacheWidth: (width * 3).round(),
              excludeFromSemantics: true,
            )
          : Padding(
              padding: EdgeInsets.all(width * .1),
              child: Text(
                text ?? '',
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: const Color(0xFF2A2A2A),
                  fontSize: (width * .07).clamp(6, 14),
                  height: 1.4,
                ),
              ),
            ),
    );
  }
}

/// A few sheets, slightly offset, for a document with [count] pages.
class PaperStack extends StatelessWidget {
  final double width;
  final int count;
  final Widget top;
  const PaperStack({
    super.key,
    required this.width,
    required this.count,
    required this.top,
  });
  @override
  Widget build(BuildContext context) {
    final behind = (count - 1).clamp(0, 2);
    return SizedBox(
      width: width + behind * 6,
      height: width * 1.414 + behind * 6,
      child: Stack(
        children: [
          for (var i = behind; i > 0; i--)
            Positioned(
              left: i * 6.0,
              top: i * 6.0,
              child: Paper(width: width),
            ),
          top,
        ],
      ),
    );
  }
}

/// A full-width sheet for reading: white with dark ink in both themes,
/// at most a readable line wide.
class PaperSheet extends StatelessWidget {
  final Widget child;
  const PaperSheet({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const ink = Color(0xFF1F1F1F);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: HandyColors.of(context).border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < 480
                  ? HandySpace.l
                  : HandySpace.xxl,
              vertical: HandySpace.xl,
            ),
            child: Theme(
              data: theme.copyWith(
                brightness: Brightness.light,
                colorScheme: theme.colorScheme.copyWith(
                  brightness: Brightness.light,
                  onSurface: ink,
                ),
                textTheme: theme.textTheme.apply(
                  bodyColor: ink,
                  displayColor: ink,
                ),
              ),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: ink),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
