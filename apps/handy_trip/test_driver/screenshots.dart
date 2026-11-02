import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('../../docs/qa/evidence/screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
    responseDataCallback: (data) async {
      final summary = Map<String, dynamic>.from(data ?? {});
      final screenshots = summary.remove('screenshots') as List? ?? [];
      summary['screenshotNames'] = [
        for (final item in screenshots) item['screenshotName'],
      ];
      final exports = summary.remove('exports') as Map? ?? {};
      for (final entry in exports.entries) {
        if (!RegExp(
          r'^trip-native-[a-z-]+\.(png|pdf|zip)$',
        ).hasMatch(entry.key as String))
          throw const FormatException('Unsafe QA artifact name');
        final file = File('../../docs/qa/evidence/exports/${entry.key}');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(base64Decode(entry.value as String));
      }
      summary['exportFiles'] = exports.keys.toList();
      await File(
        '../../docs/qa/evidence/trip-native-report.json',
      ).writeAsString(jsonEncode(summary));
    },
  );
}
