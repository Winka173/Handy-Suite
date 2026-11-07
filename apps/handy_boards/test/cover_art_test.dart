import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/covers/cover_art.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

Widget frame(
  String? id,
  Size size, {
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  home: Center(
    child: SizedBox.fromSize(size: size, child: CoverArt(id)),
  ),
);

void main() {
  testWidgets('every cover paints at all supported crops and in both themes', (
    t,
  ) async {
    for (final cover in coverCatalog) {
      expect(coverTone(cover.id), isNot(coverTone(null)), reason: cover.id);
      for (final size in [
        const Size(300, 100),
        const Size(120, 120),
        const Size(500, 100),
        const Size(120, 160),
      ]) {
        for (final brightness in Brightness.values) {
          await t.pumpWidget(frame(cover.id, size, brightness: brightness));
          expect(
            t.takeException(),
            isNull,
            reason: '${cover.id} $size $brightness',
          );
          expect(t.getSize(find.byType(CoverArt)), size);
        }
      }
    }
  });

  testWidgets('null and unknown IDs paint a named neutral fallback', (t) async {
    final semantics = t.ensureSemantics();
    try {
      for (final id in [null, '', 'unknown.cover']) {
        await t.pumpWidget(frame(id, const Size(300, 100)));
        expect(t.takeException(), isNull);
        expect(find.bySemanticsLabel('Neutral cover'), findsOneWidget);
        expect(coverTone(id), const Color(0xFFD3D9CF));
      }
      expect(coverTone(coverCatalog.first.id), isNot(coverTone(null)));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('known art exposes its Vietnamese accessible name', (t) async {
    final semantics = t.ensureSemantics();
    try {
      await t.pumpWidget(
        Localizations(
          locale: const Locale('vi'),
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 120,
              height: 120,
              child: CoverArt('study.open-book'),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Trang sách mở'), findsOneWidget);
      expect(t.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('all declared raster cover assets exist and load', (t) async {
    // This release is entirely procedural. If a later release adds rasters,
    // every cover-directory asset entry is expanded and verified here.
    final manifest = File('pubspec.yaml').readAsStringSync();
    final entries = RegExp(
      r'^\s*-\s*(assets/covers/[^\s#]*)',
      multiLine: true,
    ).allMatches(manifest).map((m) => m[1]!);
    final paths = <String>{};
    for (final path in entries) {
      if (path.endsWith('/')) {
        final dir = Directory(path);
        expect(dir.existsSync(), isTrue, reason: path);
        paths.addAll(
          dir
              .listSync(recursive: true)
              .whereType<File>()
              .map((f) => f.path.replaceAll('\\', '/')),
        );
      } else {
        paths.add(path);
      }
    }
    for (final path in paths) {
      expect(File(path).existsSync(), isTrue, reason: path);
      expect((await rootBundle.load(path)).lengthInBytes, greaterThan(0));
    }
    expect(
      coverCatalog.where((c) => c.provenance.contains('generated')).length,
      paths.where((p) => p.endsWith('.webp')).length,
    );
  });
}
