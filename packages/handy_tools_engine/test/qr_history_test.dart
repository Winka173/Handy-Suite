import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';

void main() {
  test(
    'QR history defaults off, preserves existing parser format, and roundtrips',
    () {
      final off = QrHistory();
      expect(off.add('private').entries, isEmpty);
      final on = QrHistory(enabled: true).add(
        wifiQr('Office', 'secret', 'WPA', false),
        at: '2026-01-01T00:00:00.000Z',
      );
      final restored = QrHistory.parse(on.serialize());
      expect(restored.enabled, isTrue);
      expect(restored.entries, on.entries);
      expect(parseQrHistory(jsonEncode(restored.entries)), restored.entries);
      expect(
        () => restored.entries.first['text'] = 'changed',
        throwsUnsupportedError,
      );
    },
  );
  test(
    'history caps at 50, deduplicates payloads, removes entries and disables empty',
    () {
      var history = QrHistory(enabled: true);
      for (var i = 0; i < 60; i++) {
        history = history.add('QR $i');
      }
      expect(history.entries.length, 50);
      expect(history.entries.first['text'], 'QR 59');
      expect(history.entries.last['text'], 'QR 10');
      history = history.add('QR 10');
      expect(history.entries.length, 50);
      expect(history.entries.first['text'], 'QR 10');
      expect(history.remove(0).entries.length, 49);
      expect(() => history.remove(-1), throwsFormatException);
      expect(() => QrHistory(entries: history.entries), throwsFormatException);
      expect(QrHistory.parse(QrHistory().serialize()).entries, isEmpty);
    },
  );
  test('malformed, incompatible and oversized history is rejected', () {
    expect(() => QrHistory.parse('{'), throwsFormatException);
    expect(
      () => QrHistory.parse(
        '{"format":"handy-tools-qr-history","version":2,"enabled":true,"entries":[]}',
      ),
      throwsFormatException,
    );
    expect(
      () => QrHistory(enabled: true).add('x' * 1201),
      throwsFormatException,
    );
    expect(
      () => QrHistory(enabled: true).add('abc', at: 'yesterday'),
      throwsFormatException,
    );
    expect(() => QrHistory.parse(' ' * 300001), throwsFormatException);
  });
}
