import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import '../annotation_painter.dart';

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
      maxWidth: 1600,
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
