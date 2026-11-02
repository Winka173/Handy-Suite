// Run from apps/handy_bookmark:
// flutter test --no-pub tool/store_benchmark.dart --reporter expanded
// Exercises the shipped native SQLite adapter in a Flutter test process.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/platform/store_native.dart';
import 'package:sqlite3/sqlite3.dart';

Map<String, dynamic> _bookmark(int index) => {
  'id': 'benchmark-$index',
  'originalUrl': 'https://public.org/article/$index',
  'normalizedUrl': 'https://public.org/article/$index',
  'canonicalUrl': null,
  'sourceDomain': 'public.org',
  'platform': 'website',
  'contentType': 'article',
  'collectionId': index.isEven ? 'reading' : null,
  'title': 'Benchmark article $index',
  'description': 'Reference Việt Nam document for offline search',
  'note': 'User-authored note $index',
  'tags': ['topic-${index % 10}'],
  'isFavorite': index % 7 == 0,
  'isArchived': false,
  'isRead': false,
  'isPinned': false,
  'savedAt': DateTime.utc(
    2026,
    1,
    1,
  ).add(Duration(seconds: index)).toIso8601String(),
  'updatedAt': '2026-11-01T00:00:00.000Z',
  'lastOpenedAt': null,
  'openedCount': index % 5,
};

double _milliseconds(Stopwatch watch) => watch.elapsedMicroseconds / 1000;

Map<String, double> _distribution(List<double> samples) {
  final sorted = [...samples]..sort();
  return {
    'min': sorted.first,
    'median': sorted[sorted.length ~/ 2],
    'p95': sorted[(sorted.length * .95).ceil() - 1],
    'max': sorted.last,
  };
}

Directory _workspace() {
  var directory = Directory.current.absolute;
  while (!Directory(
    '${directory.path}/packages/handy_bookmark_engine',
  ).existsSync()) {
    if (directory.parent.path == directory.path) {
      throw StateError('Run benchmark from Handy Suite workspace');
    }
    directory = directory.parent;
  }
  return directory;
}

void main() {
  test(
    'measure native SQLite at 100, 1000, 10000 and 50000 bookmarks',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'handy-save-benchmark-',
      );
      final results = <Map<String, dynamic>>[];
      String? sqliteVersion;
      try {
        for (final count in [100, 1000, 10000, 50000]) {
          final path = '${temporary.path}/$count.sqlite';
          NativeBookmarkStore? store;
          try {
            final timer = Stopwatch()..start();
            store = await NativeBookmarkStore.open(
              path,
              operationTimeout: const Duration(minutes: 2),
            );
            final emptyStartup = _milliseconds(timer);
            final records = List.generate(count, _bookmark);
            timer.reset();
            await store.write(
              upserts: records,
              settings: {
                'collections': [
                  {
                    'id': 'reading',
                    'name': 'Reading',
                    'parentId': null,
                    'position': 0,
                  },
                ],
              },
            );
            final seed = _milliseconds(timer);
            await store.close();
            timer.reset();
            store = await NativeBookmarkStore.open(
              path,
              operationTimeout: const Duration(minutes: 2),
            );
            final populatedStartup = _milliseconds(timer);
            // Warm SQLite caches and JIT before repeated latency measurements.
            await store.search({
              'text': 'Benchmark',
              'tags': ['topic-3'],
            });
            final search = <double>[], pagination = <double>[];
            for (var sample = 0; sample < 12; sample++) {
              timer.reset();
              final found = await store.search({
                'text': 'Benchmark',
                'tags': ['topic-3'],
              }, limit: 50);
              search.add(_milliseconds(timer));
              expect(found['total'], count ~/ 10);
              timer.reset();
              final page = await store.search(
                {},
                offset: math.max(0, count - 100),
                limit: 100,
              );
              pagination.add(_milliseconds(timer));
              expect(page['bookmarks'], hasLength(100));
            }
            timer.reset();
            final snapshot = await store.read();
            final readAll = _milliseconds(timer);
            timer.reset();
            final json = jsonEncode(snapshot);
            final jsonEncodeMs = _milliseconds(timer);
            timer.reset();
            final decoded = jsonDecode(json) as Map;
            final jsonDecodeMs = _milliseconds(timer);
            expect(decoded['bookmarks'], hasLength(count));
            final inspector = sqlite3.open(path);
            late bool fts;
            try {
              sqliteVersion =
                  inspector.select('SELECT sqlite_version() AS v').single['v']
                      as String;
              fts = inspector
                  .select(
                    "SELECT name FROM sqlite_master WHERE name='bookmark_search'",
                  )
                  .isNotEmpty;
            } finally {
              inspector.close();
            }
            final integrity = await store.integrity();
            expect(integrity, 'ok');
            await store.close();
            store = null;
            final result = <String, dynamic>{
              'bookmarks': count,
              'emptyStartupMs': emptyStartup,
              'populatedStartupMs': populatedStartup,
              'seedTransactionMs': seed,
              'searchMs': _distribution(search),
              'lastPageMs': _distribution(pagination),
              'readAllMs': readAll,
              'jsonEncodeMs': jsonEncodeMs,
              'jsonDecodeMs': jsonDecodeMs,
              'jsonCharacters': json.length,
              'sqliteFileBytesAfterClose': await File(path).length(),
              'processRssBytesAfterRun': ProcessInfo.currentRss,
              'ftsAvailable': fts,
              'integrity': integrity,
            };
            results.add(result);
            // ignore: avoid_print
            print(jsonEncode(result));
          } finally {
            await store?.close();
          }
        }
        final evidence = File(
          '${_workspace().path}/docs/qa/evidence/save-store-benchmark.json',
        );
        await evidence.parent.create(recursive: true);
        await evidence.writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
            'platform': Platform.operatingSystem,
            'osVersion': Platform.operatingSystemVersion,
            'dartVersion': Platform.version,
            'sqliteVersion': sqliteVersion,
            'runner':
                'flutter test --no-pub tool/store_benchmark.dart --reporter expanded',
            'mode':
                'Flutter test VM; actual native SQLite library; synthetic local records',
            'samplesPerQuery': 12,
            'limitations':
                'Single Windows host; warm repeated queries; no UI scrolling, '
                'frame timing, mobile performance, or release-mode claims. RSS includes '
                'the entire test process and earlier samples; JSON measures serialization '
                'only, not complete portable archive import/export.',
            'results': results,
          }),
        );
      } finally {
        await temporary.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
