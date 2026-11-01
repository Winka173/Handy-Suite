import 'dart:typed_data';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import '../annotation_painter.dart';

/// One frame of a guide's film: the step's screenshot with its notes drawn
/// on, cropped from the top, and its number in a circle of the app's
/// colour, the way the exported guide numbers it.
class FilmFrame extends StatelessWidget {
  final int number;
  final double width;
  final Uint8List? picture;
  final ProjectStep step;
  final bool selected;
  final String? label;
  final VoidCallback? onTap;
  const FilmFrame({
    super.key,
    required this.number,
    required this.width,
    required this.picture,
    required this.step,
    this.selected = false,
    this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final height = width * .62;
    final image = picture == null
        ? ColoredBox(
            color: c.control,
            child: Icon(Icons.broken_image_outlined, color: c.muted),
          )
        : FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: step.imageWidth.toDouble(),
              height: step.imageHeight.toDouble(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    picture!,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    cacheWidth: (width * 3).round(),
                    excludeFromSemantics: true,
                  ),
                  CustomPaint(
                    painter: AnnotationPainter(
                      step.annotations,
                      Size(
                        step.imageWidth.toDouble(),
                        step.imageHeight.toDouble(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
    final frame = AnimatedContainer(
      duration: HandyMotion.of(context, HandyMotion.short),
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? primary : c.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          Positioned(
            left: 6,
            top: 6,
            child: CircleAvatar(
              radius: 11,
              backgroundColor: primary,
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: tr(
        context,
        'Step $number${label == null || label!.isEmpty ? '' : ', $label'}',
        'Bước $number${label == null || label!.isEmpty ? '' : ', $label'}',
      ),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              frame,
              if (label != null) ...[
                const SizedBox(height: HandySpace.xs),
                Text(
                  label!.isEmpty ? '—' : label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
