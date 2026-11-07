import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/covers/cover_art.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

void main() {
  final shots = Platform.environment['SHOTS_DIR'];
  setUpAll(() async {
    if (shots == null) return;
    final loader = FontLoader('PlusJakartaSans');
    for (final name in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File('fonts/PlusJakartaSans-$name.ttf').readAsBytesSync(),
          ),
        ),
      );
    }
    await loader.load();
  });

  for (final family in CoverFamily.values) {
    testWidgets('${family.name} contact sheet', (t) async {
      t.view.physicalSize = Size(
        1040,
        150 + 230 * coversIn(family).length.toDouble(),
      );
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'PlusJakartaSans'),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              backgroundColor: const Color(0xFFF1F0E9),
              body: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Handy Boards · ${familyNameEn(family)} / ${familyNameVi(family)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '3:1 card header     ·     1:1 gallery     ·     5:1 narrow strip     ·     3:4 board',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    for (final cover in coversIn(family)) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 300,
                            height: 100,
                            child: CoverArt(cover.id),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 150,
                            height: 150,
                            child: CoverArt(cover.id),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 300,
                            height: 60,
                            child: CoverArt(cover.id),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 112.5,
                            height: 150,
                            child: CoverArt(cover.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${cover.id}   ·   ${cover.pro ? "PRO" : "FREE"}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${cover.nameEn} / ${cover.nameVi}',
                        style: const TextStyle(fontSize: 12),
                      ),

                      const SizedBox(height: 19),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        final render =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final im = await render.toImage(pixelRatio: 1.5);
        try {
          final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory(shots!)..createSync(recursive: true);
          File(
            '${dir.path}/${family.name}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        } finally {
          im.dispose();
        }
      });
    }, skip: shots == null);
  }
}
