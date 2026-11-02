import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_tools/app.dart';
import 'package:handy_tools/bench/bench_page.dart';
import 'package:handy_tools/bench/tool_panel.dart';
import 'package:handy_tools/specs.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_ui/kit.dart';

class QrTestDocuments implements DocumentRepository {
  @override
  Future<String?> load() async => null;
  @override
  Future<void> save(String value) async {}
}

class MemoryPreferences implements PreferencesRepository {
  HandyPreferences state = HandyPreferences();
  bool fail = false;
  @override
  Future<HandyPreferences> load() async => state;
  @override
  Future<void> save(HandyPreferences value) async {
    if (fail) throw Exception('disk unavailable');
    state = value;
  }
}

class FixtureFiles implements HandyFiles {
  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => null;
  Uint8List? binary;
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    binary = bytes;
    return 'fixture://$name';
  }

  String? saved;
  ImportedText? incoming;
  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => incoming;
  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async {
    saved = text;
    return 'fixture://$name';
  }
}

Future<void> start(
  WidgetTester tester, {
  MemoryPreferences? repo,
  FixtureFiles? files,
  Size size = const Size(400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    HandyToolsApp(
      repository: repo ?? MemoryPreferences(),
      files: files ?? FixtureFiles(),
      qrHistoryDocuments: QrTestDocuments(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> enter(
  WidgetTester tester,
  String text, {
  bool submit = false,
}) async {
  await tester.enterText(find.byKey(const Key('bench-input')), text);
  await tester.pumpAndSettle();
  if (submit) {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }
}

Future<void> openTool(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(const Key('open-catalog')).first);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('catalog-search')),
    id.replaceAll('-', ' '),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('catalog-$id')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a sum answers while typing; Enter puts it on the tape with a total',
    (tester) async {
      await start(tester);
      await enter(tester, '0.1 + 0.2');
      expect(find.text('0.3'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await enter(tester, '10 / 4', submit: true);
      expect(find.byKey(const Key('tape-entry-1')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('tape-total'))).data,
        '2.8',
      );
    },
  );

  testWidgets(
    'a bad sum shows its error only after Enter, never an invented answer',
    (tester) async {
      await start(tester);
      await enter(tester, '1/0');
      expect(find.byKey(const Key('tool-error')), findsNothing);
      expect(find.byKey(const Key('bench-answer')), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tool-error')), findsOneWidget);
      expect(find.byKey(const Key('tape-entry-0')), findsNothing);
    },
  );

  testWidgets('words are understood: units and percent from one line', (
    tester,
  ) async {
    await start(tester);
    await enter(tester, '1 m sang cm');
    expect(find.text('100 cm'), findsOneWidget);
    expect(find.byKey(const Key('reading-units')), findsOneWidget);
    await enter(tester, '15% của 2.400.000');
    expect(find.text('360,000'), findsOneWidget);
  });

  testWidgets('open as form keeps the values; the form swaps units', (
    tester,
  ) async {
    await start(tester);
    await enter(tester, '1 m to cm');
    await tester.tap(find.byKey(const Key('bench-open-form')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('field-value')), findsOneWidget);
    await tester.tap(find.byKey(const Key('swap-units')));
    await tester.pumpAndSettle();
    expect(find.text('0.01 m'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tool-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bench-input')), findsOneWidget);
  });

  testWidgets('text transforms chain in place and save as a workflow', (
    tester,
  ) async {
    final repo = MemoryPreferences();
    await start(tester, repo: repo);
    await enter(tester, 'b\na\nb');
    await tester.tap(find.byKey(const Key('transform-deduplicate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transform-sort')));
    await tester.pumpAndSettle();
    expect(find.text('a\nb'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chain-save')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chain-name')), 'Clean');
    await tester.tap(find.byKey(const Key('chain-save-confirm')));
    await tester.pumpAndSettle();
    expect(repo.state.recipes.single.steps, ['deduplicate', 'sort']);
    expect(find.byKey(const Key('chain-use-Clean')), findsOneWidget);
  });

  testWidgets('a form tool saves the exact result to a file', (tester) async {
    final files = FixtureFiles();
    await start(tester, files: files);
    await openTool(tester, 'calculate');
    await tester.enterText(
      find.byKey(const Key('field-expression')),
      '0.1 + 0.2',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('export-result')));
    await tester.tap(find.byKey(const Key('export-result')));
    await tester.pumpAndSettle();
    expect(files.saved, '0.3');
  });

  testWidgets('loan takes labelled fields instead of a comma list', (
    tester,
  ) async {
    await start(tester);
    await openTool(tester, 'loan');
    await tester.enterText(find.byKey(const Key('field-principal')), '1000');
    await tester.enterText(find.byKey(const Key('field-rate')), '12');
    await tester.pumpAndSettle();
    expect(find.text('Monthly payment'), findsOneWidget);
    expect(find.text('88.85'), findsWidgets);
  });

  test('legacy comma drafts fill the matching fields', () {
    expect(decodeDraft(specById['loan']!, '1000, 12, 24'), {
      'principal': '1000',
      'rate': '12',
      'months': '24',
    });
    expect(decodeDraft(specById['case']!, 'a,b'), {'text': 'a,b'});
  });

  testWidgets(
    'a pin from the catalog survives restart and shows on the bench',
    (tester) async {
      final repo = MemoryPreferences();
      await start(tester, repo: repo);
      await tester.tap(find.byKey(const Key('open-catalog')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-pin-calculate')));
      await tester.pumpAndSettle();
      expect(repo.state.favorites, contains('calculate'));
      await tester.pumpWidget(const SizedBox());
      await start(tester, repo: repo);
      expect(find.byKey(const Key('pinned-calculate')), findsOneWidget);
    },
  );

  testWidgets('a failed save keeps settings and says nothing changed', (
    tester,
  ) async {
    final repo = MemoryPreferences()..fail = true;
    await start(tester, repo: repo);
    await tester.tap(find.byKey(const Key('open-catalog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-pin-calculate')));
    await tester.pump();
    expect(repo.state.favorites, isEmpty);
    expect(find.text('Could not save. Nothing changed.'), findsOneWidget);
  });

  testWidgets('a pasted link becomes a QR code; SVG never embeds the text', (
    tester,
  ) async {
    final files = FixtureFiles();
    await start(tester, files: files);
    await enter(tester, 'https://example.com');
    await tester.tap(find.byKey(const Key('bench-make-qr')));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.byKey(const Key('more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('qr-svg')));
    await tester.pumpAndSettle();
    expect(String.fromCharCodes(files.binary!), contains('<svg'));
    expect(
      String.fromCharCodes(files.binary!),
      isNot(contains('https://example.com')),
    );
  });

  testWidgets('password is ready on open', (tester) async {
    await start(tester);
    await openTool(tester, 'password');
    expect(
      tester.widget<Text>(find.byKey(const Key('password-value'))).data!.length,
      20,
    );
  });

  testWidgets('settings save themselves', (tester) async {
    final repo = MemoryPreferences();
    await start(tester, repo: repo);
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(repo.state.theme, 'dark');
  });

  testWidgets('a web address like #/tool/loan opens that tool directly', (
    tester,
  ) async {
    tester.platformDispatcher.defaultRouteNameTestValue = '/tool/loan';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await start(tester);
    expect(find.byKey(const Key('field-principal')), findsOneWidget);
  });

  testWidgets('Ctrl+K opens the tool finder on desktop; Escape leaves a tool', (
    tester,
  ) async {
    await start(tester, size: const Size(1400, 900));
    expect(find.byKey(const Key('tape')), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-search')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('catalog-search')), 'loan');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-loan')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bench-input')), findsOneWidget);
  });

  testWidgets('every tool lays out at 320px without overflow', (tester) async {
    await start(tester, size: const Size(320, 700));
    final nav = Navigator.of(tester.element(find.byType(BenchPage)));
    for (final id in [
      ...specs.map((s) => s.id),
      'qr',
      'password',
      'subtitles',
    ]) {
      nav.pushNamed('/tool/$id');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: id);
      nav.pop();
      await tester.pumpAndSettle();
    }
  });
}
