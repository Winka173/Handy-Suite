import 'dart:io';
import 'package:flutter/services.dart';

/// Real typefaces only for optional host screenshots; normal tests stay hermetic.
Future<void> loadSafetyFonts() async {
  if (!Platform.environment.containsKey('HABIT_RUN2_SHOTS')) return;
  Future<void> font(String family, Iterable<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      loader.addFont(
        Future.value(ByteData.view(File(path).readAsBytesSync().buffer)),
      );
    }
    await loader.load();
  }

  await font(
    'Nunito',
    Directory('fonts')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.ttf'))
        .map((f) => f.path),
  );
  await font('MaterialIcons', [
    '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]);
}
