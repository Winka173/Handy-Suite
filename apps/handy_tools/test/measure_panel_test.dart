import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'vn_tools_test.dart' show go;
import 'pilot_test.dart' show start;

void main() {
  testWidgets('the measure tool asks for a photo first and says how', (
    t,
  ) async {
    await start(t);
    await go(t, 'measure');
    expect(find.byKey(const Key('measure-pick')), findsOneWidget);
    expect(find.textContaining('bank card'), findsOneWidget);
    expect(find.byKey(const Key('measure-board')), findsNothing);
  });
}
