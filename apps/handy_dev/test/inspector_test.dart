import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_workflow/handy_workflow.dart';
import 'helpers.dart';

void main() {
  testWidgets(
    'JSON shows as a tree; choosing a node puts its path on the status line',
    (tester) async {
      await start(tester);
      await paste(tester, '{"order": {"items": [{"sku": "A-17"}]}}');
      expect(find.byKey(const Key('status-line')), findsOneWidget);
      await tapKey(tester, r'tree-row-$.order');
      await tapKey(tester, r'tree-row-$.order.items');
      expect(find.text(r'$.order.items'), findsOneWidget);
    },
  );

  testWidgets('the JSON format lens runs the real Dart parser', (tester) async {
    await start(tester);
    await paste(tester, '{"a":1}');
    await tapKey(tester, 'lens-json');
    await reveal(tester, find.byKey(const Key('dev-output')));
    expect(find.text('{\n  "a": 1\n}'), findsOneWidget);
  });

  testWidgets('a schema with local references reports the failing path', (
    tester,
  ) async {
    await start(tester);
    await paste(tester, '{"age":"bad"}');
    await tapKey(tester, 'lens-schema');
    await tester.enterText(
      find.byKey(const Key('lens-option')),
      jsonEncode({
        'properties': {
          'age': {r'$ref': '#/definitions/age'},
        },
        'definitions': {
          'age': {'type': 'integer', 'minimum': 0},
        },
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('false'), findsOneWidget);
    await tapKey(tester, r'tree-row-$.errors[0]');
    expect(find.textContaining('/age'), findsWidgets);
  });

  testWidgets('the regex lens lists matches with their groups', (tester) async {
    await start(tester);
    await paste(tester, 'a1 b2');
    await tapKey(tester, 'lens-regex');
    await tester.enterText(find.byKey(const Key('lens-option')), r'(\w)(\d)');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key(r'tree-row-$.matches[1]')), findsOneWidget);
  });

  testWidgets('a parse error is one line, never an invented answer', (
    tester,
  ) async {
    await start(tester);
    await paste(tester, '{"a":1}');
    await tapKey(tester, 'lens-json');
    await paste(tester, '{"a": 1, "b":');
    expect(find.byKey(const Key('dev-copy')), findsNothing);
  });

  testWidgets(
    'a JWT is decoded, marked sensitive and never offered as a draft',
    (tester) async {
      final prefs = DevPreferences()
        ..value = HandyPreferences(
          locale: 'en',
          theme: 'dark',
          drafts: {'jwt': 'private-token', 'base64-encode': 'hello'},
        );
      await start(tester, prefs: prefs);
      expect(
        find.byKey(const Key('draft-jwt')),
        findsNothing,
        reason: 'sensitive drafts are dropped on load',
      );
      await paste(tester, 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.');
      expect(find.byKey(const Key('lens-jwt')), findsOneWidget);
      expect(
        find.text(
          'Sensitive: shown here only. Never saved as a draft or a step.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('dev-save-draft')), findsNothing);
      expect(find.text('signature not checked'), findsOneWidget);
    },
  );

  testWidgets('drafts restore and survive a failed save', (tester) async {
    final prefs = DevPreferences()
      ..value = HandyPreferences(drafts: {'base64-encode': 'hello'});
    await start(tester, prefs: prefs);
    await tapKey(tester, 'draft-base64');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('dev-input')))
          .controller!
          .text,
      'hello',
    );
    await paste(tester, 'Xin chào');
    await tapKey(tester, 'lens-base64');
    prefs.fail = true;
    await tapKey(tester, 'dev-save-draft');
    // The failed save leaves the stored file as it was, old id and all.
    expect(prefs.value.drafts, {'base64-encode': 'hello'});
    prefs.fail = false;
    await tapKey(tester, 'dev-save-draft');
    expect(prefs.value.drafts, {'base64': 'Xin chào'});
  });

  testWidgets('pins from the finder survive a failed save and a restart', (
    tester,
  ) async {
    final prefs = DevPreferences();
    await start(tester, prefs: prefs, size: const Size(1280, 900));
    await ctrl(tester, LogicalKeyboardKey.keyK);
    await tester.enterText(find.byKey(const Key('catalog-search')), 'base64');
    await tester.pumpAndSettle();
    prefs.fail = true;
    await tapKey(tester, 'catalog-pin-base64');
    expect(prefs.value.favorites, isEmpty);
    prefs.fail = false;
    await tapKey(tester, 'catalog-pin-base64');
    expect(prefs.value.favorites, ['base64']);
    await tester.pumpWidget(const SizedBox());
    await start(tester, prefs: prefs);
    expect(find.byKey(const Key('pinned-base64')), findsOneWidget);
  });

  testWidgets(
    'safe lenses chain and save as a workflow; a failed save keeps the old list',
    (tester) async {
      final prefs = DevPreferences();
      await start(tester, prefs: prefs);
      await paste(tester, 'Xin chào');
      await tapKey(tester, 'lens-base64');
      await tapKey(tester, 'transform-base64-decode');
      expect(find.text('Xin chào'), findsWidgets);
      prefs.fail = true;
      await tapKey(tester, 'chain-save');
      await tester.enterText(find.byKey(const Key('chain-name')), 'Roundtrip');
      await tapKey(tester, 'chain-save-confirm');
      expect(prefs.value.recipes, isEmpty);
      prefs.fail = false;
      await tapKey(tester, 'chain-save');
      await tester.enterText(find.byKey(const Key('chain-name')), 'Roundtrip');
      await tapKey(tester, 'chain-save-confirm');
      expect(prefs.value.recipes.single.steps, [
        'base64-encode',
        'base64-decode',
      ]);
    },
  );

  testWidgets('restoring settings refuses a chain with a sensitive step', (
    tester,
  ) async {
    final prefs = DevPreferences(), files = Files();
    await start(tester, prefs: prefs, files: files);
    files.next = jsonEncode({
      'format': 'handy-dev-settings',
      'version': 1,
      'preferences': {
        'version': 1,
        'locale': 'system',
        'theme': 'system',
        'favorites': [],
        'drafts': {},
        'recipes': [
          Recipe('Unsafe', ['jwt']).toJson(),
        ],
      },
    });
    await tapKey(tester, 'open-settings');
    await tapKey(tester, 'settings-import');
    expect(prefs.value.recipes, isEmpty);
  });

  testWidgets('a cURL command opens as a request', (tester) async {
    await start(tester);
    await paste(
      tester,
      "curl https://api.example.com/v1/orders -H 'Accept: application/json'",
    );
    await tapKey(tester, 'open-request');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('request-url')))
          .controller!
          .text,
      'https://api.example.com/v1/orders',
    );
  });
}
