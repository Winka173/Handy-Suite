import 'package:flutter_test/flutter_test.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_tools/qr_page.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:handy_ui/kit.dart';
import 'pilot_test.dart' show FixtureFiles;

class Store implements DocumentRepository {
  String? text;
  int writes = 0;
  bool fail = false;
  @override
  Future<String?> load() async => text;
  @override
  Future<void> save(String value) async {
    writes++;
    if (fail) throw StateError('Disk full');
    text = value;
  }
}

Future<void> mount(WidgetTester tester, Store store) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHandyTheme(const Color(0xFFD97706), Brightness.light),
      home: Scaffold(
        body: ListView(
          children: [
            QrPage(
              files: FixtureFiles(),
              historyDocuments: store,
              header: (context, actions) => Row(children: actions),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> toggleHistory(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('qr-history')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('qr-history-toggle')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'history is off by default; enabled history records saved codes, reopens, and clears when turned off',
    (tester) async {
      final store = Store();
      await mount(tester, store);
      await tester.enterText(
        find.byKey(const ValueKey('qr-field-0')),
        'private text',
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.byKey(const Key('qr-save')));
      await tester.pumpAndSettle();
      expect(store.writes, 0);
      await toggleHistory(tester);
      expect(QrHistory.parse(store.text!).enabled, isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('qr-save')));
      await tester.pumpAndSettle();
      expect(
        QrHistory.parse(store.text!).entries.single['text'],
        'private text',
      );
      await tester.pumpWidget(const SizedBox());
      await mount(tester, store);
      await toggleHistory(tester);
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();
      final cleared = QrHistory.parse(store.text!);
      expect(cleared.enabled, isFalse);
      expect(cleared.entries, isEmpty);
      expect(store.writes, 6);
    },
  );
  testWidgets(
    'failed history save keeps the code usable and existing history intact',
    (tester) async {
      final initial = QrHistory(enabled: true).add('old').serialize(),
          store = Store()
            ..text = initial
            ..fail = true;
      await mount(tester, store);
      await tester.enterText(find.byKey(const ValueKey('qr-field-0')), 'new');
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.byKey(const Key('qr-save')));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(store.text, initial);
      expect(
        find.text('History could not be saved. Try again.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('a history entry opens back into the form', (tester) async {
    final store = Store()
      ..text = QrHistory(enabled: true).add('from history').serialize();
    await mount(tester, store);
    await tester.tap(find.byKey(const Key('qr-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('from history'));
    await tester.pumpAndSettle();
    expect(find.text('from history'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
