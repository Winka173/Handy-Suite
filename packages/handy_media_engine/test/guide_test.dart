import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:image/image.dart' as img;
import 'images_test.dart' show fixture, chunk;
import 'project_test.dart' show projectFixture;

void main() {
  test(
    'frozen legacy expectations remain executable without TypeScript sources',
    () async {
      final folder = Directory('../../test-fixtures/guide-export');
      final expected =
          jsonDecode(
                File('${folder.path}/legacy-parity.json').readAsStringSync(),
              )
              as Map;
      final project = CaptureProject.parse(expected['project']);
      expect(buildGuideMarkdown(project), expected['markdown']);
      final first = GuideRaster(
        'first',
        File('${folder.path}/flattened-1.png').readAsBytesSync(),
      );
      final second = GuideRaster(
        'second',
        File('${folder.path}/flattened-2.png').readAsBytesSync(),
      );
      final result = await compareGuidePng(first, second);
      final legacy = expected['comparison'] as Map;
      expect(result.changedPixels, legacy['changedPixels']);
      expect(result.totalPixels, legacy['totalPixels']);
      expect(result.percent, legacy['percent']);
      expect(
        decodeBoundedImage(result.png).rgba,
        decodeBoundedImage(
          File('${folder.path}/legacy-change-map.png').readAsBytesSync(),
        ).rgba,
      );
    },
  );
  test(
    'guide HTML escapes text, removes PNG metadata and excludes editable source identity',
    () {
      final original = projectFixture();
      final project = original.copyWith(title: '<script>"Tiếng Việt"</script>');
      final png = fixture(),
          input = Uint8List.fromList([
            ...png.take(33),
            ...chunk(
              'tEXt',
              utf8.encode('private\u0000email=hidden@example.com'),
            ),
            ...png.skip(33),
          ]),
          snapshot = Uint8List.fromList(input);
      final image = GuideRaster(project.steps.first.id, input);
      expect(latin1.decode(image.png), isNot(contains('hidden@example.com')));
      expect(decodeBoundedImage(image.png).rgba, decodeBoundedImage(png).rgba);
      final html = buildGuideHtml(project, [image], locale: 'vi');
      expect(html, contains('&lt;script&gt;'));
      expect(html, isNot(contains('<script>')));
      expect(html, contains("default-src 'none'"));
      expect(html, contains('type="checkbox"'));
      expect(html, contains('id="snap-step-1"'));
      expect(html, contains('Bước 1'));
      expect(html, isNot(contains('file:///old-snap')));
      expect(html, isNot(contains('original-step')));
      expect(html, isNot(contains('annotations')));
      final encoded = RegExp(
        r'src="data:image/png;base64,([^"]+)"',
      ).firstMatch(html)![1]!;
      expect(base64Decode(encoded), image.png);
      expect(input, snapshot);
      expect(original.title, 'Hướng dẫn 😀');
      expect(() => image.png[0] = 0, throwsUnsupportedError);
    },
  );
  test(
    'Markdown and bug-report output preserve legacy escaping, sections and step order',
    () {
      final project = projectFixture();
      expect(
        buildGuideMarkdown(project),
        '# Hướng dẫn 😀\n\n## Environment\n\nAndroid\n\n## Expected\n\nExpected\n\n## Actual\n\nActual\n\n## Reproduction\n\nOne\nTwo\n\n## 1. Ảnh gốc\n\nNội dung\n\n',
      );
      expect(
        buildGuideMarkdown(project, bugReport: true),
        contains('## Evidence 1: Ảnh gốc'),
      );
      expect(
        buildGuideMarkdown(project.copyWith(title: r'a\b [x] *y*')),
        startsWith(r'# a\\b \[x\] \*y\*'),
      );
      expect(project.kind, 'bug');
    },
  );
  test(
    'safe-share ZIP reopens exact flattened files and rejects corrupt/missing/unsafe entries',
    () {
      final project = projectFixture(),
          image = GuideRaster('original-step', fixture());
      final zip = buildGuideZip(project, [image], locale: 'vi'),
          files = parseGuideZip(zip);
      expect(files.keys.toSet(), {
        'guide.html',
        'guide.md',
        'report.txt',
        'README.txt',
        'steps/001.png',
      });
      expect(files['steps/001.png'], image.png);
      expect(utf8.decode(files['guide.md']!), buildGuideMarkdown(project));
      expect(
        utf8.decode(files['guide.html']!),
        buildGuideHtml(project, [image], locale: 'vi'),
      );
      expect(
        utf8.decode(files['report.txt']!),
        buildGuideMarkdown(project, bugReport: true),
      );
      expect(
        () => files['project.json'] = Uint8List(0),
        throwsUnsupportedError,
      );
      final payloadStart = latin1.decode(zip).indexOf('<!doctype');
      expect(payloadStart, greaterThan(0));
      final corrupted = Uint8List.fromList(zip)..[payloadStart] ^= 1;
      expect(() => parseGuideZip(corrupted), throwsFormatException);
      for (final entry in ['../outside.png', 'project.json', 'steps/000.png']) {
        final archive = Archive()..addFile(ArchiveFile.bytes(entry, image.png));
        expect(
          () => parseGuideZip(ZipEncoder().encodeBytes(archive, level: 0)),
          throwsFormatException,
        );
      }
      expect(() => buildGuideHtml(project, []), throwsFormatException);
      expect(
        () => buildGuideHtml(project, [image, image]),
        throwsFormatException,
      );
      expect(
        () => buildGuideHtml(project, [GuideRaster('unknown', fixture())]),
        throwsFormatException,
      );
      expect(
        () => buildGuideHtml(project, [image], locale: 'bad'),
        throwsFormatException,
      );
      final dir = Directory('../../docs/qa/evidence/guide-export')
        ..createSync(recursive: true);
      File('${dir.path}/safe-guide.zip').writeAsBytesSync(zip);
      File(
        '${dir.path}/guide.html',
      ).writeAsStringSync(buildGuideHtml(project, [image], locale: 'vi'));
      File(
        '${dir.path}/guide.md',
      ).writeAsStringSync(buildGuideMarkdown(project));
      File('${dir.path}/project.json').writeAsStringSync(project.serialize());
      File('${dir.path}/flattened.png').writeAsBytesSync(image.png);
    },
  );
  test(
    'difference alpha-composites on white, uses strict threshold and emits only heatmap colors',
    () async {
      GuideRaster solid(String id, int red, int alpha) {
        final image = img.Image(width: 2, height: 1, numChannels: 4);
        for (var x = 0; x < 2; x++) {
          image.setPixelRgba(x, 0, red, 0, 0, alpha);
        }
        return GuideRaster(id, img.encodePng(image));
      }

      final before = solid('before', 100, 255);
      final same = await compareGuidePng(before, solid('after', 124, 255));
      expect(same.changedPixels, 0);
      expect(decodeBoundedImage(same.png).rgba, [
        226,
        232,
        240,
        255,
        226,
        232,
        240,
        255,
      ]);
      final changed = await compareGuidePng(before, solid('after', 125, 255));
      expect(changed.changedPixels, 2);
      expect(changed.percent, 100);
      expect(decodeBoundedImage(changed.png).rgba, [
        239,
        68,
        68,
        255,
        239,
        68,
        68,
        255,
      ]);
      expect(
        (await compareGuidePng(
          solid('a', 10, 0),
          solid('b', 200, 0),
        )).changedPixels,
        0,
      );
      await expectLater(
        compareGuidePng(before, GuideRaster('other', fixture())),
        throwsFormatException,
      );
      await expectLater(
        compareGuidePng(before, before, threshold: -1),
        throwsFormatException,
      );
      final canceled = CancellationToken();
      Future<void>.delayed(Duration.zero, canceled.cancel);
      await expectLater(
        compareGuidePng(before, before, cancellation: canceled),
        throwsA(isA<Cancelled>()),
      );
    },
  );
  test(
    'long-image output roundtrips pixels in order; size and actual event-loop cancellation are bounded',
    () async {
      GuideRaster solid(String id, int red) {
        final image = img.Image(width: 24, height: 16, numChannels: 4);
        img.fill(image, color: img.ColorRgba8(red, 0, 0, 255));
        return GuideRaster(id, img.encodePng(image));
      }

      final a = solid('a', 10),
          b = solid('b', 200),
          source = Uint8List.fromList(a.png);
      final png = await stitchGuidePng([a, b], width: 24),
          raster = decodeBoundedImage(png);
      expect((raster.width, raster.height), (24, 32));
      expect(raster.rgba[0], 10);
      expect(raster.rgba[24 * 16 * 4], 200);
      expect(a.png, source);
      await expectLater(
        stitchGuidePng(List.filled(10, a), width: 4096),
        throwsFormatException,
      );
      final canceled = CancellationToken();
      Future<void>.delayed(Duration.zero, canceled.cancel);
      await expectLater(
        stitchGuidePng([a, b], cancellation: canceled),
        throwsA(isA<Cancelled>()),
      );
    },
  );
  test(
    'manual share review findings name fields without retaining sensitive values',
    () {
      final base = projectFixture();
      final project = CaptureProject.parse({
        ...base.toJson(),
        'title': 'contact me@example.com',
        'bug': {...base.bug, 'actual': 'api_key=keep-private'},
      });
      final findings = findSensitiveGuideText(project);
      expect(
        findings.any((f) => f.field == 'title' && f.kind == 'email'),
        isTrue,
      );
      expect(
        findings.any((f) => f.field == 'bug.actual' && f.kind == 'secret'),
        isTrue,
      );
      expect(findings.toString(), isNot(contains('keep-private')));
      expect(project.bug['actual'], 'api_key=keep-private');
    },
  );
}
