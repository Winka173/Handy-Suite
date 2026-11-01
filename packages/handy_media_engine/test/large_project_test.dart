import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'large_project_fixture.dart';

void main() {
  test(
    'legacy 32M PNG project ZIP preserves exact assets and schema through roundtrip',
    () {
      final png = largeProjectPng();
      final step = ProjectStep(
        id: 'large-step',
        title: 'Legacy 32M',
        body: 'Original dimensions preserved',
        imageUri: 'file:///old-snap/large.png',
        imageWidth: 4000,
        imageHeight: 8000,
      );
      final project = CaptureProject.create(
        'large-legacy',
      ).copyWith(steps: [step]);
      final source = project.serialize();
      final zip = buildPortableProject(project, {step.imageUri: png});
      final imported = parsePortableProject(zip);
      expect(
        imported.project.steps.single.imageWidth *
            imported.project.steps.single.imageHeight,
        32000000,
      );
      expect(imported.assets.values.single, png);
      expect(project.serialize(), source);
      final again = parsePortableProject(
        buildPortableProject(imported.project, imported.assets),
      );
      expect(again.project.toJson(), imported.project.toJson());
      expect(again.assets.values.single, png);
      final folder = Directory('../../docs/qa/evidence/large-project')
        ..createSync(recursive: true);
      File('${folder.path}/source-32m.png').writeAsBytesSync(png);
      File('${folder.path}/portable.zip').writeAsBytesSync(zip);
    },
  );
  test(
    'large PNG CRC/header/range damage never becomes an accepted project asset',
    () {
      final png = largeProjectPng();
      final step = ProjectStep(
        id: 'large-step',
        title: '',
        body: '',
        imageUri: 'file:///old/large.png',
        imageWidth: 4000,
        imageHeight: 8000,
      );
      final crc = Uint8List.fromList(png)..[png.length - 1] ^= 1;
      expect(() => verifyProjectImage(crc, step), throwsFormatException);
      final bomb = Uint8List.fromList(png);
      ByteData.sublistView(bomb)
        ..setUint32(16, 8000)
        ..setUint32(29, getCrc32(Uint8List.sublistView(bomb, 12, 29)));
      expect(() => verifyProjectImage(bomb, step), throwsFormatException);
      expect(
        () => verifyProjectImage(png.sublist(0, png.length - 1), step),
        throwsFormatException,
      );
    },
  );
}
