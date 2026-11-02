import 'package:handy_ui/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/editors.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

Bookmark _bookmark() {
  final url = UrlTools.normalize('https://example.com/original');
  return Bookmark(
    id: 'bookmark',
    originalUrl: url.originalUrl,
    normalizedUrl: url.normalizedUrl,
    canonicalUrl: 'https://example.com/canonical',
    title: 'Original',
    note: 'Keep this note',
    description: 'Existing description',
    platform: url.platform,
    sourceDomain: url.sourceDomain,
    savedAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
  );
}

Future<void> _open(
  WidgetTester tester,
  Widget editor,
  ValueChanged<Object?> result, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHandyTheme(const Color(0xFF0E7490), Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result(
                await Navigator.of(
                  context,
                ).push<Object?>(MaterialPageRoute(builder: (_) => editor)),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pump();
}

Future<void> _choose(WidgetTester tester, String key, String text) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'bookmark Save returns URL identity and edited text without losing notes',
    (tester) async {
      final initial = _bookmark();
      Object? result;
      await _open(
        tester,
        BookmarkEditor(
          initial: initial,
          library: SaveLibrary(bookmarks: [initial]),
        ),
        (v) => result = v,
      );
      await _enter(
        tester,
        'bookmark-url',
        'https://www.youtube.com/shorts/AbCdEF12345?utm_source=share',
      );
      await _enter(tester, 'bookmark-title', 'A new title');
      await _enter(tester, 'bookmark-tags', 'watch, learning, watch');
      await tester.tap(find.byKey(const Key('editor-save')));
      await tester.pumpAndSettle();
      final edited = result as Bookmark;
      expect(edited.id, initial.id);
      expect(edited.title, 'A new title');
      expect(edited.platform, 'youtube');
      expect(edited.normalizedUrl, isNot(contains('utm_source')));
      expect(edited.canonicalUrl, isNull);
      expect(edited.note, 'Keep this note');
      expect(edited.tags, ['watch', 'learning']);
      expect(edited.savedAt, initial.savedAt);
      expect(initial.title, 'Original');
    },
  );

  testWidgets('Cancel returns no model and leaves original values intact', (
    tester,
  ) async {
    final initial = _bookmark();
    Object? result = 'pending';
    await _open(
      tester,
      BookmarkEditor(
        initial: initial,
        library: SaveLibrary(bookmarks: [initial]),
      ),
      (v) => result = v,
    );
    await _enter(tester, 'bookmark-title', 'Discard this');
    await tester.tap(find.byKey(const Key('editor-cancel')));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(initial.title, 'Original');
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('invalid bookmark URL stays in editor', (tester) async {
    final initial = _bookmark();
    Object? result;
    await _open(
      tester,
      BookmarkEditor(
        initial: initial,
        library: SaveLibrary(bookmarks: [initial]),
      ),
      (v) => result = v,
    );
    await _enter(tester, 'bookmark-url', 'javascript:alert(1)');
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('Enter a valid HTTP or HTTPS URL'), findsOneWidget);
  });

  testWidgets('collection descendant parent selection is rejected as a cycle', (
    tester,
  ) async {
    final parent = SaveCollection(id: 'parent', name: 'Parent', position: 9);
    final child = SaveCollection(
      id: 'child',
      name: 'Child',
      parentId: parent.id,
    );
    Object? result;
    await _open(
      tester,
      CollectionEditor(
        initial: parent,
        library: SaveLibrary(collections: [parent, child]),
      ),
      (v) => result = v,
    );
    await _choose(tester, 'collection-parent', 'Child');
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(
      find.text('Choose a parent outside this collection'),
      findsOneWidget,
    );
    await _choose(tester, 'collection-parent', 'None');
    await _enter(tester, 'collection-name', 'Renamed');
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();
    final edited = result as SaveCollection;
    expect(edited.name, 'Renamed');
    expect(edited.position, 9);
    expect(edited.parentId, isNull);
  });

  testWidgets('new collection returns selected parent and icon', (
    tester,
  ) async {
    final parent = SaveCollection(id: 'parent', name: 'Parent');
    Object? result;
    await _open(
      tester,
      CollectionEditor(library: SaveLibrary(collections: [parent])),
      (v) => result = v,
    );
    await _enter(tester, 'collection-name', 'Reading');
    await _choose(tester, 'collection-parent', 'Parent');
    await _choose(tester, 'collection-icon', 'Learning');
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();
    final edited = result as SaveCollection;
    expect(edited.parentId, 'parent');
    expect(edited.icon, 'learning');
    expect(edited.id, isNotEmpty);
  });

  testWidgets(
    'smart collection OR mode returns typed rules that match engine semantics',
    (tester) async {
      Object? result;
      final initial = SmartCollection(
        id: 'smart',
        name: 'Read or favorite',
        mode: 'all',
        rules: [
          SmartRule(field: 'isRead', operator: 'equals', value: true),
          SmartRule(field: 'isFavorite', operator: 'equals', value: true),
        ],
      );
      await _open(
        tester,
        SmartCollectionEditor(
          initial: initial,
          library: SaveLibrary(smartCollections: [initial]),
        ),
        (v) => result = v,
      );
      await _choose(tester, 'smart-mode', 'Any rule (OR)');
      await tester.tap(find.byKey(const Key('editor-save')));
      await tester.pumpAndSettle();
      final edited = result as SmartCollection;
      final favorite = _bookmark().copyWith(isFavorite: true, isRead: false);
      expect(edited.mode, 'any');
      expect(edited.rules.first.value, isTrue);
      expect(edited.matches(favorite), isTrue);
      expect(initial.matches(favorite), isFalse);
    },
  );

  testWidgets('smart date builder validates and returns numeric withinDays', (
    tester,
  ) async {
    Object? result;
    await _open(
      tester,
      SmartCollectionEditor(library: SaveLibrary()),
      (v) => result = v,
    );
    await _enter(tester, 'smart-name', 'Recent');
    await _choose(tester, 'smart-field-0', 'Saved date');
    await _enter(tester, 'smart-value-0-savedAt-withinDays', '0');
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(
      find.text('Enter a whole number between 1 and 36500'),
      findsOneWidget,
    );
    await _enter(tester, 'smart-value-0-savedAt-withinDays', '14');
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();
    final edited = result as SmartCollection;
    expect(edited.mode, 'all');
    expect(edited.rules.single.operator, 'withinDays');
    expect(edited.rules.single.value, 14);
    expect(edited.rules.single.value, isA<int>());
  });
  testWidgets('smart editor stays usable on a narrow display with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Object? result;
    await _open(
      tester,
      SmartCollectionEditor(library: SaveLibrary()),
      (v) => result = v,
      textScale: 2,
    );
    await _enter(tester, 'smart-name', 'Recent');
    await _choose(tester, 'smart-field-0', 'Saved date');
    await _enter(tester, 'smart-value-0-savedAt-withinDays', '7');
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('editor-save')));
    await tester.pumpAndSettle();
    expect(result, isA<SmartCollection>());
  });
}
