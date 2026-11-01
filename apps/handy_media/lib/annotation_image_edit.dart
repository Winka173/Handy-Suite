import 'dart:math' as math;
import 'dart:typed_data';
import 'package:handy_core/handy_core.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'annotation_painter.dart';

/// Match the legacy raster edit: flatten once, then transform a new PNG.
/// Originals and editable layers remain available to the caller's Undo history.
Future<Uint8List> editAnnotatedImage(
  ProjectStep step,
  Uint8List source,
  String operation, {
  ProjectLayer? cropLayer,
  CancellationToken? cancellation,
}) async {
  if (!{'rotate', 'resize', 'crop'}.contains(operation))
    throw const FormatException('Unknown image edit');
  if (operation == 'crop' &&
      (cropLayer == null ||
          !step.annotations.any((l) => l.id == cropLayer.id) ||
          !{
            'rect',
            'highlight',
            'redact',
            'spotlight',
          }.contains(cropLayer.kind) ||
          cropLayer.geometry.width <= 0 ||
          cropLayer.geometry.height <= 0)) {
    throw const FormatException('Select a box layer to crop');
  }
  cancellation?.check();
  final flat = await flattenAnnotation(
    step,
    source,
    maxWidth: 1600,
    maxHeight: 4000,
  );
  cancellation?.check();
  if (operation == 'rotate')
    return convertImage(
      flat,
      format: 'png',
      rotation: 90,
      cancellation: cancellation,
    );
  final dimensions = projectPngDimensions(flat);
  if (operation == 'resize')
    return resizeImage(
      flat,
      width: math.max(1, (dimensions.width / 2).round()),
      cancellation: cancellation,
    );
  final g = cropLayer!.geometry;
  // Legacy crop origin uses floor and extent uses round, clamped to the image.
  final x = (g.x * dimensions.width).floor(),
      y = (g.y * dimensions.height).floor();
  final width = math.min(
    dimensions.width - x,
    math.max(1, (g.width * dimensions.width).round()),
  );
  final height = math.min(
    dimensions.height - y,
    math.max(1, (g.height * dimensions.height).round()),
  );
  return cropImage(
    flat,
    ImageRegion(
      x: x / dimensions.width,
      y: y / dimensions.height,
      width: width / dimensions.width,
      height: height / dimensions.height,
    ),
    cancellation: cancellation,
  );
}
