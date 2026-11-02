import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_card/app.dart';
import 'package:handy_card/data/store.dart';
import 'package:handy_card/editor/canvas.dart';
import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:handy_core/handy_core.dart' show CancellationToken;
import 'package:handy_files/handy_files.dart';

class MemoryFiles implements HandyFiles {
  final saved = <String, Uint8List>{};
  ImportedBytes? next;
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    saved[name] = bytes;
    return name;
  }

  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => next;
  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => null;
  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async => null;
}

Future<void> boot(
  WidgetTester t,
  CardStore store,
  MemoryFiles files, {
  Size size = const Size(1280, 900),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    CardApp(
      store: store,
      files: files,
      clock: () => DateTime.utc(2026, 11, 2, 9),
    ),
  );
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await t.pumpAndSettle();
}

Future<void> settle(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 700)),
  );
  await t.pump(const Duration(milliseconds: 700));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'blank card → add, drag, undo, redo → saved and reopened exactly',
    (t) async {
      final store = MemoryCardStore(), files = MemoryFiles();
      await boot(t, store, files);
      expect(find.byKey(const Key('home-new-empty')), findsOneWidget);

      await t.tap(find.byKey(const Key('home-new-empty')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('new-create')));
      await settle(t);
      expect(find.byKey(const Key('studio')), findsOneWidget);

      await t.tap(find.byKey(const Key('add-text')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('add-rect')));
      await t.pumpAndSettle();

      // Drag the rectangle by 60 px: many pointer moves, one undo step.
      final canvas = find.byType(CardCanvas);
      final centre = t.getCenter(canvas);
      final gesture = await t.startGesture(centre);
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(5, 0));
        await t.pump();
      }
      await gesture.up();
      await t.pumpAndSettle();

      await settle(t);
      final saved = CardDocument.decode(
        store.records['design']!.values.single,
        ElementRegistry.standard(),
      );
      final els = saved.pages.first.elements;
      expect(els.map((e) => e.type), ['text', 'rect']);
      final movedX = els.last.frame.x;

      // Undo the drag only, then redo it.
      await t.tap(find.byKey(const Key('studio-undo')));
      await t.pumpAndSettle();
      await settle(t);
      final undone = CardDocument.decode(
        store.records['design']!.values.single,
        ElementRegistry.standard(),
      );
      expect(
        undone.pages.first.elements.length,
        2,
        reason: 'undo took back the drag, not the shape',
      );
      expect(undone.pages.first.elements.last.frame.x, lessThan(movedX));
      await t.tap(find.byKey(const Key('studio-redo')));
      await settle(t);
      expect(find.text('Saved'), findsOneWidget);

      // Close and reopen the whole app on the same store.
      final before = store.records['design']!.values.single;
      await t.pumpWidget(const SizedBox());
      await boot(t, store, files);
      expect(find.byKey(Key('design-${saved.id}')), findsOneWidget);
      expect(
        CardDocument.decode(
          before,
          ElementRegistry.standard(),
        ).pages.first.elements.last.frame.x,
        movedX,
      );
    },
  );

  testWidgets('a project file restores the design on a fresh install', (
    t,
  ) async {
    final store = MemoryCardStore(), files = MemoryFiles();
    final registry = ElementRegistry.standard();
    final doc = cardTemplates.first.build(registry, DateTime.utc(2026));
    await store.put('design', doc.id, doc.encode());
    await boot(t, store, files);
    await t.tap(find.byKey(const Key('open-settings')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('settings-backup')));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
    final zip = files.saved['handy-card-backup.zip']!;

    final fresh = MemoryCardStore(),
        freshFiles = MemoryFiles()
          ..next = ImportedBytes('handy-card-backup.zip', zip);
    await t.pumpWidget(const SizedBox());
    await boot(t, fresh, freshFiles);
    await t.tap(find.byKey(const Key('home-import')));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Add').last);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
    final restored = CardDocument.decode(
      fresh.records['design']!.values.single,
      registry,
    );
    expect(
      restored.pages.map((p) => p.toJson()).toList(),
      doc.pages.map((p) => p.toJson()).toList(),
    );
  });

  testWidgets('on a phone the studio uses the bottom bar and sheets', (
    t,
  ) async {
    final store = MemoryCardStore(), files = MemoryFiles();
    final doc = cardTemplates.first.build(
      ElementRegistry.standard(),
      DateTime.utc(2026),
    );
    await store.put('design', doc.id, doc.encode());
    await boot(t, store, files, size: const Size(360, 740));
    await t.tap(find.byKey(Key('design-${doc.id}')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('bar-add')), findsOneWidget);
    await t.tap(find.byKey(const Key('bar-layers')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('layers')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
