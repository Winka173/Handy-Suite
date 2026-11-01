import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'images_test.dart' show fixture;

CaptureProject projectFixture() {
  final source = CaptureProject.create('legacy-project', title: 'Hướng dẫn 😀');
  return CaptureProject.parse({
    ...source.toJson(),
    'kind': 'bug',
    'tags': ['vi', 'private'],
    'bug': {
      'environment': 'Android',
      'expected': 'Expected',
      'actual': 'Actual',
      'reproduction': 'One\nTwo',
    },
    'steps': [
      ProjectStep(
        id: 'original-step',
        title: 'Ảnh gốc',
        body: 'Nội dung',
        imageUri: 'file:///old-snap/image.png',
        imageWidth: 24,
        imageHeight: 16,
        annotations: [
          for (var i = 0; i < annotationKinds.length; i++)
            defaultLayer('layer-$i', annotationKinds[i]),
        ],
      ).toJson(),
    ],
  });
}

Uint8List zip(Map<String, Uint8List> files, {int level = 0}) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return ZipEncoder().encodeBytes(archive, level: level);
}

void main() {
  test(
    'strict Snap v1 JSON preserves all nine layer types, points, bug and timestamps',
    () {
      final p = projectFixture(),
          restored = CaptureProject.fromText(p.serialize());
      expect(restored.toJson(), p.toJson());
      expect(
        restored.steps.single.annotations.map((l) => l.kind),
        annotationKinds,
      );
      expect(() => restored.tags.add('lost'), throwsUnsupportedError);
      final raw = restored.toJson();
      (raw['bug'] as Map)['actual'] = 'changed';
      expect(restored.bug['actual'], 'Actual');
      expect(
        () => CaptureProject.parse({...p.toJson(), 'unknown': true}),
        throwsFormatException,
      );
      expect(
        () => CaptureProject.parse({
          ...p.toJson(),
          'createdAt': '2026-02-30T00:00:00.000Z',
        }),
        throwsFormatException,
      );
      expect(
        () => CaptureProject.parse({
          ...p.toJson(),
          'steps': [p.steps.single.toJson(), p.steps.single.toJson()],
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'JSON rejects remote/traversal URIs, invalid geometry and wrong stroke points',
    () {
      for (final uri in [
        'https://example.com/image.png',
        'file:///a/%2e%2e/image.png',
        'file:///a/image.png?x',
        'file:///a/%00.png',
      ]) {
        expect(() => projectImageUri(uri), throwsFormatException);
      }
      final layer = defaultLayer('one', 'rect').toJson();
      expect(
        () => ProjectLayer.parse({...layer, 'x': 0.9, 'width': 0.2}),
        throwsFormatException,
      );
      expect(
        () => ProjectLayer.parse({...layer, 'kind': 'pen'}),
        throwsFormatException,
      );
      expect(
        () => ProjectLayer.parse({
          ...layer,
          'kind': 'arrow',
          'points': [
            {'x': 0, 'y': 0},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => ProjectLayer.parse({...layer, 'x': double.nan}),
        throwsFormatException,
      );
    },
  );
  test(
    'portable ZIP roundtrip retains IDs/text/points/pixels but removes install paths',
    () {
      final p = projectFixture(),
          png = fixture(),
          original = p.serialize(),
          bytes = buildPortableProject(p, {p.steps.single.imageUri: png}),
          bundle = parsePortableProject(bytes);
      expect(p.serialize(), original);
      expect(bundle.project.id, p.id);
      expect(bundle.project.createdAt, p.createdAt);
      expect(bundle.project.updatedAt, p.updatedAt);
      expect(
        bundle.project.steps.single.annotations.map((l) => l.toJson()),
        p.steps.single.annotations.map((l) => l.toJson()),
      );
      expect(bundle.assets.values.single, png);
      expect(
        bundle.project.steps.single.imageUri,
        'file:///portable/assets/image-0.png',
      );
      expect(
        parsePortableProject(
          buildPortableProject(bundle.project, bundle.assets),
        ).project.toJson(),
        bundle.project.toJson(),
      );
      expect(() => bundle.assets.values.single[0] = 0, throwsUnsupportedError);
      expect(() => buildPortableProject(p, {}), throwsFormatException);
    },
  );
  test(
    'ZIP rejects traversal/duplicate/extra/CRC/missing/dimension/manifest damage',
    () {
      final p = projectFixture(),
          png = fixture(),
          bytes = buildPortableProject(p, {p.steps.single.imageUri: png}),
          archive = ZipDecoder().decodeBytes(bytes),
          files = {for (final f in archive.files) f.name: f.readBytes()!};
      expect(() => parsePortableProject(Uint8List(10)), throwsFormatException);
      expect(
        () => parsePortableProject(zip({...files, '../evil.png': png})),
        throwsFormatException,
      );
      expect(
        () => parsePortableProject(zip({...files, 'assets/image-1.png': png})),
        throwsFormatException,
      );
      expect(
        () => parsePortableProject(
          zip({'manifest.json': files['manifest.json']!}),
        ),
        throwsFormatException,
      );
      final altered = Uint8List.fromList(bytes);
      altered[50] ^= 1;
      expect(() => parsePortableProject(altered), throwsFormatException);
      final badManifest = jsonDecode(utf8.decode(files['manifest.json']!));
      badManifest['assets'][0]['crc32'] = '00000000';
      expect(
        () => parsePortableProject(
          zip({
            ...files,
            'manifest.json': Uint8List.fromList(
              utf8.encode(jsonEncode(badManifest)),
            ),
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => verifyProjectImage(fixture(width: 25), p.steps.single),
        throwsFormatException,
      );
      final duplicate = zip({...files, 'assets/image-1.png': png});
      final before = ascii.encode('assets/image-1.png'),
          after = ascii.encode('assets/image-0.png');
      for (var at = 0; at <= duplicate.length - before.length; at++) {
        if (List.generate(
          before.length,
          (i) => duplicate[at + i] == before[i],
        ).every((same) => same))
          duplicate.setRange(at, at + after.length, after);
      }
      expect(
        () => parsePortableProject(duplicate),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('duplicate'),
          ),
        ),
      );
    },
  );
  test(
    'bounded ZIP inflate refuses lying uncompressed length before retaining output',
    () {
      final bytes = zip({'manifest.json': Uint8List(1000000)}, level: 6),
          data = ByteData.sublistView(bytes);
      for (var i = 0; i < bytes.length - 46; i++) {
        if (data.getUint32(i, Endian.little) == 0x02014b50) {
          data.setUint32(i + 24, 1, Endian.little);
          break;
        }
      }
      expect(() => parsePortableProject(bytes), throwsFormatException);
    },
  );
  test(
    'move/resize/align transforms arrow points and keeps normalized bounds',
    () {
      final layer = ProjectLayer.parse({
        'id': 'arrow',
        'kind': 'arrow',
        'x': 0.2,
        'y': 0.2,
        'width': 0.3,
        'height': 0.3,
        'color': '#123456',
        'text': '',
        'points': [
          {'x': 0.2, 'y': 0.2},
          {'x': 0.5, 'y': 0.5},
        ],
      });
      final moved = layer.copyWith(
        geometry: const LayerGeometry(0.4, 0.4, 0.5, 0.5),
      );
      expect(moved.points!.first.x, closeTo(0.4, 0.00001));
      expect(moved.points!.last.y, closeTo(0.9, 0.00001));
      expect(alignLayer(layer.geometry, 'right').x, closeTo(0.7, 0.00001));
      expect(alignLayer(layer.geometry, 'bottom').y, closeTo(0.7, 0.00001));
      expect(
        () => alignLayer(layer.geometry, 'invalid'),
        throwsFormatException,
      );
    },
  );
}
