// A guided walk through the app for a screen recording on a device:
// python tooling/device-tour.py --device <serial> dev
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev/app.dart';
import 'package:handy_dev/http_transport.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import '../test/helpers.dart' show DevPreferences, Files, Store;

/// Lets the viewer see the screen before the next step.
Future<void> pause(WidgetTester t, [int ms = 1200]) async {
  await t.pumpAndSettle();
  await Future<void>.delayed(Duration(milliseconds: ms));
  await t.pump();
}

Future<void> tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    // Scrolled out of a lazy list: go back to the top of what is on screen.
    for (final list
        in find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .hitTestable()
            .evaluate()
            .toList()) {
      (list as StatefulElement).state is ScrollableState
          ? (list.state as ScrollableState).position.jumpTo(0)
          : null;
    }
    await t.pumpAndSettle();
  }
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await pause(t, 700);
}

Future<void> type(WidgetTester t, String key, String text) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  // A new text-input client after the last one closed on the device.
  await t.tap(f);
  await t.pumpAndSettle();
  await t.enterText(f, text);
  await pause(t, 700);
}

/// Drops the soft keyboard so the result stays in view.
Future<void> hideKeyboard(WidgetTester t) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await pause(t, 400);
}

/// Switches between Inspect and Requests in the top bar.
Future<void> area(WidgetTester t, Pattern label) async {
  await t.tap(
    find
        .descendant(
          of: find.byKey(const Key('area')),
          matching: find.textContaining(label),
        )
        .first,
  );
  await pause(t, 900);
}

/// Goes back the way a person does: the top bar's back arrow, or the
/// system back when the screen has none.
Future<void> back(WidgetTester t) async {
  await t.pumpAndSettle();
  final arrow = find.byType(BackButton).hitTestable();
  if (arrow.evaluate().isNotEmpty) {
    await t.tap(arrow.last);
  } else {
    await t.binding.handlePopRoute();
  }
  await pause(t, 700);
}

const _order =
    '{"order": 1042, "customer": {"name": "Trần Bình", "city": "Đà Nẵng"}, '
    '"items": [{"sku": "A-17", "qty": 2, "price": 129000}, {"sku": "B-03", "qty": 1, "price": 349000}], '
    '"paid": true, "total": 607000}';

/// Three saved requests, as the review screenshots use.
Store _requests() {
  final ws = ApiWorkspace(
    requests: [
      ApiRequest(
        id: 'r1',
        name: 'Đơn hàng 1042',
        url: 'https://api.example.com/v1/orders/1042',
      ),
      ApiRequest(
        id: 'r2',
        name: 'Tạo đơn',
        url: 'https://api.example.com/v1/orders',
        method: 'POST',
      ),
      ApiRequest(
        id: 'r3',
        name: 'Danh sách khách',
        url: 'https://api.example.com/v1/customers',
      ),
    ],
  );
  return Store()
    ..text = exportWorkspace(
      saveRequest(
        saveRequest(saveRequest(ws, ws.requests[0]), ws.requests[1]),
        ws.requests[2],
      ),
    );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Handy Dev tour', (t) async {
    await t.pumpWidget(
      DevApp(
        preferences: DevPreferences()
          ..value = HandyPreferences(
            theme: 'light',
            locale: 'vi',
            favorites: ['jwt', 'json-filter'],
          ),
        files: Files(),
        documents: _requests(),
        // Every Send answers from here: the network is never touched.
        transport: HttpTransport(
          clientFactory: () => MockClient(
            (_) async => http.Response.bytes(
              utf8.encode(_order),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        ),
      ),
    );
    await pause(t, 2000);
    await hideKeyboard(t);

    // JSON: paste an order, walk its tree, the JSONPath follows the row.
    await type(t, 'dev-input', _order);
    await hideKeyboard(t);
    await pause(t, 1500);
    await tap(t, r'tree-row-$.items');
    await tap(t, r'tree-row-$.items[0]');
    await tap(t, r'tree-row-$.customer.city');
    await pause(t, 2000);

    // The same order as YAML.
    await tap(t, 'lens-convert');
    await pause(t, 2500);

    // A JSONPath query over it.
    await tap(t, 'lens-jsonpath');
    await type(t, 'lens-option', r'$.items[*].sku');
    await hideKeyboard(t);
    await pause(t, 2500);

    // Checked against a JSON Schema: one required field is missing.
    await tap(t, 'lens-schema');
    await type(
      t,
      'lens-option',
      '{"required": ["order", "total", "shipping"], '
          '"properties": {"total": {"type": "integer", "minimum": 0}}}',
    );
    await hideKeyboard(t);
    await pause(t, 3000);

    // A JWT decodes on the device, never saved.
    await type(
      t,
      'dev-input',
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyLTQyIiwicm9sZSI6ImFkbWluIiwiZXhwIjoxNzk4NzYxNjAwfQ.',
    );
    await hideKeyboard(t);
    await pause(t, 3000);

    // Plain text: a regular expression finds the order codes.
    await type(t, 'dev-input', 'Đơn A-17, B-03 và C-21 đã giao lúc 9 giờ 15');
    await type(t, 'lens-option', r'[A-Z]-\d+');
    await hideKeyboard(t);
    await pause(t, 3000);

    // A cURL command becomes a request, sent and answered.
    await type(
      t,
      'dev-input',
      "curl https://api.example.com/v1/orders/1042 -H 'Accept: application/json'",
    );
    await hideKeyboard(t);
    await pause(t, 1500);
    await tap(t, 'open-request');
    await pause(t, 1500);
    await tap(t, 'send');
    await pause(t, 2500);
    await tap(t, r'tree-row-$.customer');
    await pause(t, 1500);
    await tap(t, 'request-save');
    await pause(t, 2000);

    // The saved requests.
    await tap(t, 'request-r3');
    await pause(t, 1500);

    // Back to Inspect: a sample, then a tool from the finder (Ctrl K).
    await area(t, RegExp('[Dd]ữ liệu'));
    await tap(t, 'source-clear');
    await hideKeyboard(t);
    await pause(t, 1500);
    await tap(t, 'example-JSON');
    await pause(t, 1500);
    await tap(t, 'open-catalog');
    await type(t, 'catalog-search', 'typescript');
    await pause(t, 1000);
    await tap(t, 'catalog-json-typescript');
    await hideKeyboard(t);
    await pause(t, 3000);
    await tap(t, 'lens-auto');
    await pause(t, 1500);

    // Settings.
    await tap(t, 'open-settings');
    await pause(t, 2500);
    await back(t);
    await pause(t, 1500);
  });
}
