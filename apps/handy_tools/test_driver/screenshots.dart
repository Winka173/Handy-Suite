import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
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
