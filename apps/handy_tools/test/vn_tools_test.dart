import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_tools/bench/bench_page.dart';
import 'package:handy_tools/bench/intent.dart';
import 'package:handy_tools/subtitles/subtitle_controller.dart';
import 'package:handy_tools/subtitles/subtitle_panel.dart';
import 'package:handy_ui/kit.dart';
import 'pilot_test.dart' show MemoryPreferences, start, enter;

NavigatorState _nav(WidgetTester t) =>
    Navigator.of(t.element(find.byType(BenchPage)));

Future<void> go(
  WidgetTester t,
  String id, [
  Map<String, String> values = const {},
]) async {
  _nav(t).pushNamed('/tool/$id', arguments: values);
  await t.pumpAndSettle();
}

Future<void> type(WidgetTester t, String key, String text) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.enterText(find.byKey(Key(key)), text);
  await t.pumpAndSettle();
}

Future<void> tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).first);
  await t.pumpAndSettle();
  await t.tap(find.text(text).first);
  await t.pumpAndSettle();
}

class HistoryStore implements DocumentRepository {
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
    return 'file:///user-chosen/$name';
  }

  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => null;
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async => null;
}

void main() {
  group('salary', () {
    testWidgets('gross to net: the payslip adds up and names its rules', (
      t,
    ) async {
      await start(t);
      await go(t, 'salary', {'date': '2026-11-02'});
      expect(
        find.text(
          'Enter the gross or the take-home pay — the payslip appears here.',
        ),
        findsOneWidget,
      );
      await type(t, 'field-amount', '30.000.000');
      expect(find.text('Take-home'), findsOneWidget);
      expect(find.text('26,215,000 đ'), findsOneWidget);
      expect(find.text('-2,400,000 đ'), findsOneWidget);
      expect(find.text('Bracket 2 · 10% × 1,350,000'), findsOneWidget);
      expect(find.text('-635,000 đ'), findsOneWidget);
      final note = t.widget<Text>(find.byKey(const Key('rows-note'))).data!;
      expect(note, contains('Rules from 2026-07-01'));
      expect(note, contains('NĐ 161/2026'));
      expect(note, contains('50,600,000 đ'));
    });

    testWidgets('net to gross, and every rule can be overridden', (t) async {
      await start(t, size: const Size(400, 2400));
      await go(t, 'salary', {'date': '2026-11-02'});
      await tapText(t, 'Net → gross');
      await type(t, 'field-amount', '26215000');
      expect(find.text('Gross to pay'), findsOneWidget);
      expect(find.text('30,000,000 đ'), findsOneWidget);
      expect(find.byKey(const Key('field-personal')), findsNothing);
      await t.tap(find.byKey(const Key('advanced-toggle')));
      await t.pumpAndSettle();
      // The empty override shows the table value it stands for.
      expect(find.text('15.500.000'), findsOneWidget);
      await type(t, 'field-personal', '11000000');
      expect(find.text('Rules from 2026-07-01 · 1 changed'), findsOneWidget);
      final note = t.widget<Text>(find.byKey(const Key('rows-note'))).data!;
      expect(note, contains('You changed 1 values'));
      await type(t, 'field-brackets', '10=5; nope');
      expect(find.byKey(const Key('tool-error')), findsOneWidget);
    });

    testWidgets('rules before the table starts are refused, not guessed', (
      t,
    ) async {
      await start(t);
      await go(t, 'salary', {'date': '2020-01-01', 'amount': '1000'});
      expect(find.byKey(const Key('tool-error')), findsOneWidget);
      expect(find.textContaining('2024-07-01'), findsOneWidget);
    });

    testWidgets('typed on the bench: "salary 30,000,000"', (t) async {
      await start(t);
      await enter(t, 'salary 30,000,000');
      expect(find.byKey(const Key('reading-salary')), findsOneWidget);
      expect(find.text('Take-home'), findsOneWidget);
    });
  });

  group('number in words', () {
    testWidgets('the invoice line in both languages', (t) async {
      await start(t);
      await go(t, 'number-words');
      await type(t, 'field-number', '1.200.000');
      expect(
        t.widget<Text>(find.byKey(const Key('words-main'))).data,
        'Một triệu hai trăm nghìn đồng chẵn',
      );
      expect(
        t.widget<Text>(find.byKey(const Key('words-other'))).data,
        'One million two hundred thousand dong',
      );
      expect(find.text('In words · read as 1,200,000'), findsOneWidget);
      await tapText(t, 'lẻ, ngàn');
      await type(t, 'field-number', '1105');
      expect(
        t.widget<Text>(find.byKey(const Key('words-main'))).data,
        'Một ngàn một trăm lẻ năm đồng chẵn',
      );
    });

    testWidgets('a decimal amount in đồng is an error; as a number it reads', (
      t,
    ) async {
      await start(t);
      await go(t, 'number-words', {'number': '2,5'});
      expect(find.byKey(const Key('tool-error')), findsOneWidget);
      await tapText(t, 'Number only');
      expect(
        t.widget<Text>(find.byKey(const Key('words-main'))).data,
        'hai phẩy năm',
      );
    });

    testWidgets('typed on the bench: "1,250,000 in words"', (t) async {
      await start(t);
      await enter(t, '1,250,000 in words');
      expect(find.byKey(const Key('reading-number-words')), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const Key('words-main'))).data,
        'Một triệu hai trăm năm mươi nghìn đồng chẵn',
      );
    });
  });

  group('lunar calendar', () {
    testWidgets('solar to lunar', (t) async {
      await start(t);
      await go(t, 'lunar', {'date': '2026-09-25'});
      expect(find.text('15/8/2026'), findsOneWidget);
      expect(find.text('Bính Ngọ'), findsOneWidget);
      expect(find.byKey(const Key('field-lday')), findsNothing);
    });

    testWidgets('lunar leap month to solar, and a leap month that is not', (
      t,
    ) async {
      await start(t);
      await go(t, 'lunar', {
        'direction': 'lunar',
        'lday': '1',
        'lmonth': '6',
        'lyear': '2025',
        'leap': 'yes',
      });
      expect(find.byKey(const Key('field-date')), findsNothing);
      expect(find.text('2025-07-25'), findsOneWidget);
      expect(find.text('1/6/2025 (leap)'), findsOneWidget);
      await type(t, 'field-lyear', '2026');
      expect(find.byKey(const Key('tool-error')), findsOneWidget);
      expect(find.textContaining('no leap month'), findsOneWidget);
    });

    testWidgets('typed on the bench: "2026-09-25 lunar"', (t) async {
      await start(t);
      await enter(t, '2026-09-25 lunar');
      expect(find.byKey(const Key('reading-lunar')), findsOneWidget);
      expect(find.text('15/8/2026'), findsOneWidget);
    });
  });

  group('case', () {
    testWidgets('one tool, four modes', (t) async {
      await start(t);
      await go(t, 'case');
      await type(t, 'field-text', 'xin CHÀO. thế giới');
      expect(find.text('XIN CHÀO. THẾ GIỚI'), findsOneWidget);
      await tapText(t, 'Title');
      expect(find.text('Xin Chào. Thế Giới'), findsOneWidget);
      await tapText(t, 'Sentence');
      expect(find.text('Xin chào. Thế giới'), findsOneWidget);
      await tapText(t, 'lower');
      expect(find.text('xin chào. thế giới'), findsOneWidget);
    });

    testWidgets('an old link to title-case opens case in that mode', (t) async {
      await start(t);
      await go(t, 'title-case', {'text': 'a b'});
      expect(find.text('A B'), findsOneWidget);
    });

    testWidgets('old pins and saved chains still work', (t) async {
      final repo = MemoryPreferences()
        ..state = HandyPreferences(favorites: ['uppercase']);
      await start(t, repo: repo);
      expect(find.byKey(const Key('pinned-case')), findsOneWidget);
      await enter(t, 'b\na');
      await t.tap(find.byKey(const Key('transform-uppercase')));
      await t.pumpAndSettle();
      expect(find.text('B\nA'), findsOneWidget);
      expect(textTransforms, contains('sentence-case'));
    });
  });

  group('VietQR transfer', () {
    testWidgets('bank, account, amount: the code reads back what it pays', (
      t,
    ) async {
      await start(t, size: const Size(400, 1400));
      await go(t, 'qr');
      await t.tap(find.byKey(const Key('qr-mode-bank')));
      await t.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      await t.tap(find.byKey(const Key('qr-bank')));
      await t.pumpAndSettle();
      await t.enterText(
        find.descendant(
          of: find.byKey(const Key('qr-bank')),
          matching: find.byType(TextField),
        ),
        'Vietcombank',
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Vietcombank · VCB').last);
      await t.pumpAndSettle();
      await type(t, 'qr-field-0', '0123456789');
      await type(t, 'qr-field-1', '150.000');
      await type(t, 'qr-field-2', 'Tiền nhà');
      expect(find.byType(Image), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const Key('qr-readback'))).data,
        'Vietcombank · 0123456789 · 150,000 đ · "Tien nha"',
      );
      await type(t, 'qr-field-0', '12-3');
      expect(find.byType(Image), findsNothing);
      expect(find.text('Account: 6–19 letters or digits'), findsOneWidget);
    });
  });

  group('subtitles', () {
    const source = '1\n00:00:01,000 --> 00:00:02,000\nPRIVATE_SUBTITLE\n';

    Future<SubtitleFiles> show(WidgetTester t, {ExportHistory? history}) async {
      final files = SubtitleFiles();
      await t.pumpWidget(
        MaterialApp(
          theme: buildHandyTheme(const Color(0xFFE8590C), Brightness.light),
          home: Scaffold(
            body: ListView(
              children: [
                SubtitlePanel(
                  files: files,
                  history:
                      history ??
                      ExportHistory('tools', documents: HistoryStore()),
                  wait: Duration.zero,
                  header: (context, actions) => Row(children: actions),
                ),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      return files;
    }

    Future<void> press(WidgetTester t, String key) async {
      t
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .clearSnackBars();
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(Key(key)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(Key(key)));
      await t.pumpAndSettle();
    }

    testWidgets('history stores no body; a cancelled save records nothing', (
      t,
    ) async {
      final store = HistoryStore();
      final history = ExportHistory('tools', documents: store);
      final files = await show(t, history: history);
      await t.enterText(find.byKey(const Key('subtitle-input')), source);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('subtitle-summary')), findsOneWidget);
      files.cancelExport = true;
      await press(t, 'subtitle-export');
      expect(await history.load(), isEmpty);
      files.cancelExport = false;
      await press(t, 'subtitle-export');
      expect(
        (await history.load()).single.matches(utf8.encode(files.exported!)),
        isTrue,
      );
      expect((await history.load()).single.tool, 'subtitle-srt');
      expect(store.text, isNot(contains('PRIVATE_SUBTITLE')));
      store.fail = true;
      await press(t, 'subtitle-export');
      expect(files.exported, contains('PRIVATE_SUBTITLE'));
      expect(
        find.text('Subtitles saved; export history could not be updated.'),
        findsOneWidget,
      );
    });

    testWidgets('open, shift and convert: the saved file reads back right', (
      t,
    ) async {
      final files = await show(t)
        ..source = const ImportedText('a.srt', source);
      await press(t, 'subtitle-import');
      expect(find.text('Stays SRT'), findsOneWidget);
      await t.enterText(find.byKey(const Key('subtitle-offset')), '500');
      await t.pumpAndSettle();
      await t.tap(find.text('WebVTT'));
      await t.pumpAndSettle();
      expect(find.text('SRT → WebVTT'), findsOneWidget);
      expect(find.text('00:01.500'), findsOneWidget);
      expect(find.text('was 00:01.000'), findsOneWidget);
      await press(t, 'subtitle-later');
      expect(find.text('00:02.000'), findsOneWidget);
      await press(t, 'subtitle-export');
      expect(files.exported, startsWith('WEBVTT'));
      final cues = parseSubtitles(files.exported!);
      expect(cues.single.startMs, 2000);
      expect(cues.single.endMs, 3000);
      expect(cues.single.text, 'PRIVATE_SUBTITLE');
    });

    testWidgets('a shift before zero or a broken file blocks Save', (t) async {
      final files = await show(t);
      await t.enterText(find.byKey(const Key('subtitle-input')), source);
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('subtitle-offset')), '-2000');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('subtitle-problem')), findsOneWidget);
      expect(
        t
            .widget<ButtonStyleButton>(find.byKey(const Key('subtitle-export')))
            .onPressed,
        isNull,
      );
      await t.enterText(find.byKey(const Key('subtitle-offset')), '0');
      await t.enterText(
        find.byKey(const Key('subtitle-input')),
        '$source\n2\n00:00:05,000 --> 00:00:04,000\nbad',
      );
      await t.pumpAndSettle();
      expect(find.text('Invalid subtitle cue'), findsOneWidget);
      expect(files.exported, isNull);
    });
  });

  group('subtitle controller', () {
    test('the whole file is checked again before output', () async {
      final c = SubtitleController(wait: Duration.zero);
      c.load('WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHi');
      expect(c.sourceFormat, 'vtt');
      expect(c.format, 'vtt');
      expect(c.verified(), startsWith('WEBVTT'));
      c.setFormat('srt');
      expect(c.verified(), '1\n00:00:01,000 --> 00:00:02,000\nHi\n');
      c.setShift('x');
      expect(c.verified, throwsFormatException);
      c.load('');
      expect(c.verified, throwsFormatException);
      c.dispose();
    });
    test('clock reads minutes, hours and signs', () {
      expect(subtitleClock(1500), '00:01.500');
      expect(subtitleClock(3723456), '01:02:03.456');
      expect(subtitleClock(-500), '−00:00.500');
    });
  });
}
