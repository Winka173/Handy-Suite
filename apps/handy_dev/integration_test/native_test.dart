import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:handy_dev/app.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import '../test/helpers.dart' show tapKey;

Future<void> boot(
  WidgetTester tester,
  String name, [
  DocumentRepository? docs,
]) async {
  final prefs = DevicePreferencesRepository(name);
  await prefs.save(HandyPreferences(locale: 'en', theme: 'light'));
  await tester.pumpWidget(
    DevApp(preferences: prefs, documents: docs ?? localDocuments(name)),
  );
  await tester.pumpAndSettle();
}

/// Types into a field and hides the soft keyboard so the result is on screen.
Future<void> type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
}

Future<void> snap(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  if (!const bool.fromEnvironment('HANDY_SCREENSHOTS')) return;
  await binding.convertFlutterSurfaceToImage();
  await tester.pumpAndSettle();
  await binding.takeScreenshot(name);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native JSON Schema evaluates local references and shows errors',
    (tester) async {
      await boot(tester, 'handy-dev-schema-integration');
      await type(tester, 'dev-input', '{"age":"bad"}');
      await tapKey(tester, 'lens-schema');
      await type(
        tester,
        'lens-option',
        jsonEncode({
          'properties': {
            'age': {r'$ref': '#/definitions/age'},
          },
          'definitions': {
            'age': {'type': 'integer', 'minimum': 0},
          },
        }),
      );
      await tapKey(tester, r'tree-row-$.errors[0]');
      expect(find.textContaining('/age'), findsWidgets);
      expect(
        validateJsonSchema(
          '{"age":2}',
          '{"properties":{"age":{"type":"integer"}}}',
        )['valid'],
        isTrue,
      );
      expect(
        () => validateJsonSchema(
          '{}',
          r'{"$ref":"https://example.invalid/remote"}',
        ),
        throwsA(isA<Exception>()),
      );
      await snap(binding, tester, 'dev-json-schema');
    },
  );
  testWidgets('actual native RE2 runs in the Android app and regex lens', (
    tester,
  ) async {
    expect(regexSupported, isTrue);
    expect(regex('${'a' * 99999}!', r'(a+)+$')['matches'], isEmpty);
    expect(() => regex('aaa', r'(a)\1'), throwsFormatException);
    await boot(tester, 'handy-dev-regex-integration');
    await type(tester, 'dev-input', 'a1 b2');
    await tapKey(tester, 'lens-regex');
    await type(tester, 'lens-option', r'(\w)(\d)');
    expect(find.byKey(const Key(r'tree-row-$.matches[1]')), findsOneWidget);
    expect(find.byKey(const Key(r'tree-row-$.matches[2]')), findsNothing);
    await snap(binding, tester, 'dev-native-re2');
  });
  testWidgets(
    'native Dev formatter uses actual parser and isolated workspace',
    (tester) async {
      await boot(tester, 'handy-dev-integration');
      await snap(binding, tester, 'dev-home-light');
      await type(tester, 'dev-input', '{"a":1}');
      await tapKey(tester, 'lens-json');
      expect(find.text('{\n  "a": 1\n}'), findsOneWidget);
      await snap(binding, tester, 'dev-json-formatter');
    },
  );
  testWidgets(
    'native collection edit migrates v1 workspace without dropping requests',
    (tester) async {
      final docs = localDocuments('handy-dev-collections-integration');
      await docs.save(
        jsonEncode({
          'version': 1,
          'requests': [
            ApiRequest(
              id: 'legacy-request',
              name: 'Legacy request',
              url: 'https://example.com',
            ).toJson(),
          ],
          'environments': [],
        }),
      );
      await boot(tester, 'handy-dev-collections-integration', docs);
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('request-legacy-request')), findsOneWidget);
      await tapKey(tester, 'more-menu');
      await tapKey(tester, 'api-create-collection');
      await tester.enterText(
        find.byKey(const Key('collection-name')),
        'Work requests',
      );
      await tapKey(tester, 'collection-save');
      final restored = parseWorkspace(
        (await localDocuments('handy-dev-collections-integration').load())!,
      );
      expect(restored.requests.single.id, 'legacy-request');
      expect(restored.collections.length, 2);
      expect(restored.collections.first.requestIds, ['legacy-request']);
      await snap(binding, tester, 'dev-api-collections');
      await docs.save(exportWorkspace(emptyWorkspace()));
    },
  );
}
