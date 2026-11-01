import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'images_test.dart' show fixture;
import 'project_test.dart' show projectFixture;

void main() {
  final regular = ByteData.sublistView(
    File('../handy_ui/assets/fonts/NotoSans-Regular.ttf').readAsBytesSync(),
  );
  final bold = ByteData.sublistView(
    File('../handy_ui/assets/fonts/NotoSans-Bold.ttf').readAsBytesSync(),
  );
  test(
    'PDF embeds flattened images and selectable Vietnamese without source URIs',
    () async {
      final project = projectFixture().copyWith(title: 'Hướng dẫn kiểm thử');
      final source = project.serialize(), png = fixture();
      final bytes = await buildGuidePdf(
        project,
        [GuideRaster(project.steps.single.id, png)],
        regularFont: regular,
        boldFont: bold,
        locale: 'vi',
      );
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(latin1.decode(bytes), isNot(contains('file:///old-snap')));
      expect(latin1.decode(bytes), isNot(contains('/URI')));
      expect(project.serialize(), source);
      expect(png, fixture());
    },
  );
  test(
    'PDF rejects missing images, unsupported glyphs, excessive text and cancellation',
    () async {
      final project = projectFixture();
      final images = [GuideRaster(project.steps.single.id, fixture())];
      Future<Uint8List> build(
        CaptureProject p,
        List<GuideRaster> r, {
        CancellationToken? token,
      }) => buildGuidePdf(
        p,
        r,
        regularFont: regular,
        boldFont: bold,
        cancellation: token,
      );
      await expectLater(build(project, []), throwsFormatException);
      await expectLater(
        build(project, images),
        throwsFormatException,
      ); // Original emoji is not in Noto Sans.
      final large = project.copyWith(
        title: 'Guide',
        steps: [
          for (var i = 0; i < 30; i++)
            ProjectStep.parse({
              ...project.steps.first.toJson(),
              'id': 'step-$i',
              'body': 'x' * 4000,
            }),
        ],
      );
      await expectLater(
        build(large, [
          for (final s in large.steps) GuideRaster(s.id, fixture()),
        ]),
        throwsFormatException,
      );
      final token = CancellationToken()..cancel();
      await expectLater(
        build(project, images, token: token),
        throwsA(isA<Cancelled>()),
      );
      final running = CancellationToken();
      final future = build(
        project.copyWith(title: 'Guide'),
        images,
        token: running,
      );
      running.cancel();
      await expectLater(future, throwsA(isA<Cancelled>()));
    },
  );
}
