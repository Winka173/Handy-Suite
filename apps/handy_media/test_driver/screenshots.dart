import 'dart:io';
import 'dart:convert';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    responseDataCallback: (data) async {
      final transforms = data?['videoTransformArtifacts'];
      if (transforms is Map) {
        final dir = Directory('../../docs/qa/evidence/video-transform');
        await dir.create(recursive: true);
        var total = 0;
        for (final e in transforms.entries) {
          if (!{
                'source.mp4',
                'muted-rotated.mp4',
                'resized-audio.mp4',
              }.contains(e.key) ||
              e.value is! String ||
              (e.value as String).length > 40000000)
            throw const FormatException('Invalid video transform evidence');
          final bytes = base64Decode(e.value);
          total += bytes.length;
          if (total > 60000000)
            throw const FormatException('Video transform evidence limit');
          await File('${dir.path}/${e.key}').writeAsBytes(bytes, flush: true);
        }
      }
      final guideArtifacts = data?['guideArtifacts'];
      if (guideArtifacts is Map) {
        const names = {
          'handy-media-guide.html',
          'handy-media-guide.pdf',
          'handy-media-guide.md',
          'handy-media-guide.zip',
          'handy-media-long.png',
          'handy-media-change-map.png',
        };
        final directory = Directory(
          '../../docs/qa/evidence/guide-native',
        );
        await directory.create(recursive: true);
        var total = 0;
        for (final entry in guideArtifacts.entries) {
          if (!names.contains(entry.key) ||
              entry.value is! String ||
              (entry.value as String).length > 12000000)
            throw const FormatException('Invalid guide evidence');
          final bytes = base64Decode(entry.value as String);
          total += bytes.length;
          if (total > 20000000)
            throw const FormatException('Guide evidence limit exceeded');
          await File(
            '${directory.path}/${entry.key}',
          ).writeAsBytes(bytes, flush: true);
        }
      }
      final artifacts = data?['captureArtifacts'];
      if (artifacts is! Map) return;
      const allowed = {
        'recording.mp4',
        'trimmed.mp4',
        'joined.mp4',
        'frame.png',
        'screenshot.png',
      };
      final directory = Directory(
        '../../docs/qa/evidence/native-capture',
      );
      await directory.create(recursive: true);
      var total = 0;
      for (final entry in artifacts.entries) {
        if (!allowed.contains(entry.key) ||
            entry.value is! String ||
            (entry.value as String).length > 12000000)
          throw const FormatException('Invalid capture evidence');
        final bytes = base64Decode(entry.value as String);
        total += bytes.length;
        if (total > 20000000)
          throw const FormatException('Capture evidence limit exceeded');
        await File(
          '${directory.path}/${entry.key}',
        ).writeAsBytes(bytes, flush: true);
      }
    },
    onScreenshot:
        (
          String name,
          List<int> bytes, [
          Map<String, Object?>? arguments,
        ]) async {
          if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(name)) return false;
          final dir = Directory('../../docs/qa/evidence/screenshots');
          await dir.create(recursive: true);
          await File('${dir.path}/$name.png').writeAsBytes(bytes, flush: true);
          return true;
        },
  );
}
