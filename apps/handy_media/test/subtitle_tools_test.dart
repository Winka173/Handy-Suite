import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart' show kitTheme;
import 'package:handy_files/handy_files.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_media/subtitles/subtitle_page.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:handy_storage/export_history.dart';
import 'package:handy_storage/documents.dart';

class SubtitleHistoryStore implements DocumentRepository {
  String? text;
  bool fail = false;
  @override
  Future<String?> load() async => text;
  @override
  Future<void> save(String value) async {
    if (fail) throw StateError('Disk full');
    text = value;
  }
}

class SubtitleFiles implements HandyFiles {
  ImportedText? source;
  String? exported;
  bool cancelExport = false;
  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => source;
  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async {
    if (cancelExport) return null;
    exported = text;
    return 'saved';
  }

  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => throw UnsupportedError('Unused binary import');
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async => throw UnsupportedError('Unused binary export');
}

void main() {
  testWidgets(
    'subtitle export history stores no body and canceled export creates no entry',
    (tester) async {
      final historyStore = SubtitleHistoryStore(), files = SubtitleFiles();
      final history = ExportHistory('media', documents: historyStore);
      await tester.pumpWidget(
        MaterialApp(
          theme: kitTheme,
          home: Scaffold(
            body: SubtitlePage(files: files, history: history),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const source = '1\n00:00:01,000 --> 00:00:02,000\nPRIVATE_SUBTITLE\n';
      await tester.enterText(find.byKey(const Key('subtitle-input')), source);
      Future<void> press(String key) async {
        tester
            .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
            .clearSnackBars();
        await tester.pumpAndSettle();
        final f = find.byKey(Key(key));
        if (f.evaluate().isEmpty)
          await tester.scrollUntilVisible(
            f,
            160,
            scrollable: find.byType(Scrollable).first,
          );
        await Scrollable.ensureVisible(tester.element(f), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      files.cancelExport = true;
      await press('subtitle-export');
      expect(await history.load(), isEmpty);
      files.cancelExport = false;
      await press('subtitle-export');
      expect(
        (await history.load()).single.matches(utf8.encode(files.exported!)),
        isTrue,
      );
      expect(historyStore.text, isNot(contains('PRIVATE_SUBTITLE')));
      historyStore.fail = true;
      await press('subtitle-export');
      expect(files.exported, contains('PRIVATE_SUBTITLE'));
      expect(
        find.text('Subtitles exported; history could not be saved.'),
        findsOneWidget,
      );
    },
  );
  const source = '1\n00:00:01,000 --> 00:00:02,000\nHello\n';
  Future<void> show(WidgetTester tester, SubtitleFiles files) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kitTheme,
        home: Scaffold(
          body: SubtitlePage(
            files: files,
            history: ExportHistory('media', documents: SubtitleHistoryStore()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('import, offset, VTT export reopens with actual cue content', (
    tester,
  ) async {
    final files = SubtitleFiles()
      ..source = const ImportedText('sample.srt', source);
    await show(tester, files);
    await press(tester, find.byKey(const Key('subtitle-import')));
    await tester.enterText(find.byKey(const Key('subtitle-offset')), '500');
    await press(tester, find.text('WebVTT'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('00:01.500'), findsOneWidget);
    expect(find.text('was 00:01.000'), findsOneWidget);
    await press(tester, find.byKey(const Key('subtitle-export')));
    expect(files.exported, startsWith('WEBVTT'));
    final cues = parseSubtitles(files.exported!);
    expect(cues.single.startMs, 1500);
    expect(cues.single.endMs, 2500);
    expect(cues.single.text, 'Hello');
  });
  testWidgets(
    'cancel preserves source/output; invalid timing removes stale export',
    (tester) async {
      final files = SubtitleFiles()..cancelExport = true;
      await show(tester, files);
      await tester.enterText(find.byKey(const Key('subtitle-input')), source);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await press(tester, find.byKey(const Key('subtitle-export')));
      expect(find.text('Export canceled'), findsOneWidget);
      expect(files.exported, isNull);
      await tester.ensureVisible(find.byKey(const Key('subtitle-input')));
      await press(tester, find.byKey(const Key('subtitle-import')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('subtitle-input')))
            .controller!
            .text,
        source,
      );
      await tester.enterText(find.byKey(const Key('subtitle-offset')), '-2000');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Subtitle offset out of range'), findsOneWidget);
      expect(
        tester
            .widget<ButtonStyleButton>(find.byKey(const Key('subtitle-export')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('subtitle-input')))
            .controller!
            .text,
        source,
      );
    },
  );
  test('UTF-8 limit counts bytes rather than UTF-16 code units', () {
    expect(
      () => parseSubtitles(
        '1\n00:00:01,000 --> 00:00:02,000\n${'\u20ac' * 340000}',
      ),
      throwsFormatException,
    );
    expect(
      () => renderSubtitles([SubtitleCue(0, 1, '\u20ac' * 340000)]),
      throwsFormatException,
    );
  });
}
