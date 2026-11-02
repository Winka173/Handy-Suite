import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import '../annotation_painter.dart';

/// How a guide GIF plays: seconds per step, its widest size, and whether
/// each frame carries the step's number and title.
typedef GifOptions = ({int frameMs, int width, bool captions});

const defaultGifOptions = (frameMs: 2000, width: 800, captions: true);

/// Media's hue: step numbers in exports wear it, as in the film strip.
const _stepHue = Color(0xFFC2255C);

/// The size a step's flattened picture will have: the same sum as
/// [flattenAnnotation] with the bounds [renderGuide] gives it.
({int width, int height}) _flatSize(ProjectStep s, int maxWidth) {
  final scale = [
    1.0,
    maxWidth / s.imageWidth,
    4000 / s.imageHeight,
    math.sqrt(6400000 / (s.imageWidth * s.imageHeight)),
  ].reduce(math.min);
  return (
    width: math.max(1, (s.imageWidth * scale).floor()),
    height: math.max(1, (s.imageHeight * scale).floor()),
  );
}

/// The frame size [options] give [guide], before anything is drawn; throws
/// the reason when the GIF would be too big.
GuideGifLayout gifLayoutFor(CaptureProject guide, GifOptions options) =>
    GuideGifLayout.of(
      [for (final s in guide.steps) _flatSize(s, options.width)],
      maxWidth: options.width,
      captions: options.captions,
    );

/// The bar under a GIF frame: the step's number in a disc of the app's
/// hue, then its title, white on near-black, on one line.
Future<Uint8List> renderGifCaption(
  int number,
  String title,
  int width,
  int height,
) async {
  final recorder = ui.PictureRecorder(),
      canvas = Canvas(recorder),
      h = height.toDouble();
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), h),
    Paint()..color = const Color(0xFF1D1F20),
  );
  final pad = h * .25, disc = h * .56;
  canvas.drawCircle(
    Offset(pad + disc / 2, h / 2),
    disc / 2,
    Paint()..color = _stepHue,
  );
  TextPainter paint(String text, double size, FontWeight weight, double max) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'Geist',
            package: 'handy_ui',
            fontSize: size,
            fontWeight: weight,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(1, max));
  final n = paint('$number', disc * .5, FontWeight.w700, disc);
  n.paint(canvas, Offset(pad + (disc - n.width) / 2, (h - n.height) / 2));
  final left = pad * 2 + disc;
  final t = paint(title, h * .34, FontWeight.w500, width - left - pad);
  t.paint(canvas, Offset(left, (h - t.height) / 2));
  n.dispose();
  t.dispose();
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

/// A finished export: the file and, for a change map, what changed.
typedef GuideFile = ({String name, Uint8List bytes, String mime, String note});

/// The guide in one format, with every mask painted in. Pictures are drawn
/// one at a time, each within bounds; [progress] hears "3 of 8".
Future<GuideFile> renderGuide(
  CaptureProject guide,
  Map<String, Uint8List> assets,
  String format, {
  required String locale,
  required CancellationToken token,
  void Function(int done, int of)? progress,
  GifOptions gif = defaultGifOptions,
  void Function(int done, int of)? frames,
}) async {
  if (guide.steps.isEmpty)
    throw const FormatException('Add a screenshot first');
  if (format == 'md') {
    return (
      name: 'handy-media-guide.md',
      bytes: Uint8List.fromList(utf8.encode(buildGuideMarkdown(guide))),
      mime: 'text/markdown',
      note: '',
    );
  }
  final steps = format == 'diff' ? guide.steps.take(2).toList() : guide.steps;
  final rendered = <GuideRaster>[];
  var total = 0;
  for (final (i, s) in steps.indexed) {
    token.check();
    final source = assets[s.imageUri];
    if (source == null) {
      throw const FormatException(
        'Relink every missing screenshot before exporting',
      );
    }
    progress?.call(i, steps.length);
    await Future<void>.delayed(Duration.zero);
    token.check();
    final png = await flattenAnnotation(
      s,
      source,
      // A GIF frame is never wider than its chosen width.
      maxWidth: format == 'gif' ? gif.width : 1600,
      maxHeight: 4000,
      maxPixels: format == 'diff' ? 1500000 : 6400000,
    );
    total += png.length;
    if (total > 18000000) {
      throw const FormatException(
        'Rendered screenshots exceed 18 MB; split this project',
      );
    }
    rendered.add(GuideRaster(s.id, png));
  }
  progress?.call(steps.length, steps.length);
  token.check();
  switch (format) {
    case 'html':
      return (
        name: 'handy-media-guide.html',
        bytes: Uint8List.fromList(
          utf8.encode(buildGuideHtml(guide, rendered, locale: locale)),
        ),
        mime: 'text/html; charset=utf-8',
        note: '',
      );
    case 'pdf':
      final fonts = await Future.wait([
        for (final style in ['Regular', 'Bold'])
          rootBundle.load('packages/handy_ui/assets/fonts/NotoSans-$style.ttf'),
      ]);
      token.check();
      return (
        name: 'handy-media-guide.pdf',
        bytes: await buildGuidePdf(
          guide,
          rendered,
          regularFont: fonts[0],
          boldFont: fonts[1],
          locale: locale,
          cancellation: token,
        ),
        mime: 'application/pdf',
        note: '',
      );
    case 'zip':
      return (
        name: 'handy-media-guide.zip',
        bytes: buildGuideZip(guide, rendered, locale: locale),
        mime: 'application/zip',
        note: '',
      );
    case 'long':
      return (
        name: 'handy-media-long.png',
        bytes: await stitchGuidePng(rendered, cancellation: token),
        mime: 'image/png',
        note: '',
      );
    case 'gif':
      final layout = GuideGifLayout.of(
        [for (final r in rendered) (width: r.width, height: r.height)],
        maxWidth: gif.width,
        captions: gif.captions,
      );
      final word = locale == 'vi' ? 'Bước' : 'Step';
      final made = <GuideGifFrame>[];
      for (final (i, s) in steps.indexed) {
        token.check();
        made.add(
          GuideGifFrame(
            rendered[i],
            caption: layout.captionHeight == 0
                ? null
                : await renderGifCaption(
                    i + 1,
                    s.title.trim().isEmpty ? '$word ${i + 1}' : s.title.trim(),
                    layout.width,
                    layout.captionHeight,
                  ),
          ),
        );
      }
      return (
        name: 'handy-media-guide.gif',
        bytes: await buildGuideGif(
          made,
          layout,
          frameMs: gif.frameMs,
          cancellation: token,
          progress: frames,
        ),
        mime: 'image/gif',
        note: '',
      );
    case 'diff':
      final diff = await compareGuidePng(
        rendered[0],
        rendered[1],
        cancellation: token,
      );
      return (
        name: 'handy-media-change-map.png',
        bytes: diff.png,
        mime: 'image/png',
        note:
            '${diff.changedPixels}/${diff.totalPixels} pixels (${diff.percent.toStringAsFixed(3)}%)',
      );
  }
  throw const FormatException('Unsupported guide output');
}

/// Why [format] cannot be made from [guide] now, or null.
String? guideBlocker(CaptureProject guide, String format) {
  if (guide.steps.isEmpty) return 'Add a screenshot first';
  if (format == 'diff' &&
      (guide.steps.length < 2 ||
          guide.steps[0].imageWidth != guide.steps[1].imageWidth ||
          guide.steps[0].imageHeight != guide.steps[1].imageHeight)) {
    return 'Change map needs two screenshots with matching dimensions';
  }
  return null;
}
