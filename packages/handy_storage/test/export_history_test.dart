import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/export_history.dart';

class HistoryStore implements DocumentRepository {
  String? text;
  bool fail = false;
  @override
  Future<String?> load() async => text;
  @override
  Future<void> save(String next) async {
    if (fail) throw StateError('Full disk');
    text = next;
  }
}

void main() {
  test(
    'metadata-only persisted history/JSON roundtrip caps/deduplicates and never stores exported secrets',
    () async {
      final store = HistoryStore(),
          data = Uint8List.fromList(
            utf8.encode('Bearer SECRET-MUST-NOT-PERSIST'),
          );
      final history = ExportHistory('dev', documents: store);
      for (var i = 0; i < 55; i++)
        await history.record(
          tool: 'jwt',
          uri: 'file:///exports/$i.txt',
          mime: 'text/plain',
          data: data,
        );
      var entries = await history.load();
      expect(entries.length, 50);
      expect(store.text, isNot(contains('SECRET-MUST-NOT-PERSIST')));
      expect(entries.first.matches(data), isTrue);
      expect(entries.first.matches(Uint8List(2)), isFalse);
      final text = serializeExportHistory(entries);
      await history.restore(text);
      expect(serializeExportHistory(await history.load()), text);
      await history.record(
        tool: 'jwt',
        uri: entries.first.uri,
        mime: 'text/plain',
        data: data,
      );
      entries = await history.load();
      expect(entries.length, 50);
      expect(entries.map((e) => e.uri).toSet().length, 50);
      await history.remove(entries.first.id);
      expect((await history.load()).length, 49);
      await history.clear();
      expect(await history.load(), isEmpty);
    },
  );
  test(
    'legacy URI reference import roundtrips without dereferencing, bad input/save failure preserves history',
    () async {
      final store = HistoryStore(),
          history = ExportHistory('tools', documents: HistoryStore());
      const old = {
        'id': 'legacy-1',
        'tool': 'uppercase',
        'at': '2026-10-31T00:00:00.000Z',
        'uri': 'file:///old-install/private.txt',
        'mime': 'text/plain',
      };
      final entries = parseExportHistory(
        jsonEncode({
          'version': 1,
          'history': [old],
        }),
      );
      expect(entries.single.toJson(), old);
      expect(entries.single.checksum, isNull);
      await history.restore(serializeExportHistory(entries));
      expect((await history.load()).single.uri, old['uri']);
      final guarded = ExportHistory('tools', documents: store);
      await guarded.restore(serializeExportHistory(entries));
      final before = store.text;
      store.fail = true;
      await expectLater(guarded.clear(), throwsStateError);
      expect(store.text, before);
      for (final raw in [
        {
          'version': 2,
          'history': [old],
        },
        {
          'version': 1,
          'history': [old, old],
        },
        {
          'version': 1,
          'history': [
            {...old, 'uri': 'https://evil.example/token?secret=1'},
          ],
        },
        {
          'version': 1,
          'history': [
            {...old, 'at': 'invalid'},
          ],
        },
        {
          'version': 1,
          'history': [
            {...old, 'mime': 'text/plain\nsecret'},
          ],
        },
        {
          'version': 1,
          'history': [
            {...old, 'checksum': 'bad', 'bytes': 10},
          ],
        },
      ])
        expect(
          () => parseExportHistory(jsonEncode(raw)),
          throwsFormatException,
        );
      await expectLater(guarded.restore('not JSON'), throwsFormatException);
      expect(store.text, before);
      expect(() => parseExportHistory(' ' * 200001), throwsFormatException);
    },
  );
}
