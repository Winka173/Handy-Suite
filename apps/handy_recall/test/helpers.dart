import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_notifications/controller.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_recall_app/app.dart';
import 'package:handy_recall_app/study/speaker.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:timezone/timezone.dart' as tz;

/// The fixed "now" of every Recall test: 1 Nov 2026, 09:00 local.
final now = DateTime(2026, 11, 1, 9);
String at(DateTime d) => DateTime.fromMillisecondsSinceEpoch(
  d.millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();

class Store implements DocumentRepository {
  String? text;
  bool fail = false;
  @override
  Future<String?> load() async => text;
  @override
  Future<void> save(String value) async {
    if (fail) throw Exception('disk unavailable');
    text = value;
  }
}

class Preferences implements PreferencesRepository {
  HandyPreferences value = HandyPreferences(locale: 'en');
  @override
  Future<HandyPreferences> load() async => value;
  @override
  Future<void> save(HandyPreferences next) async => value = next;
}

class Files implements HandyFiles {
  ImportedText? input;
  ImportedBytes? bytes;
  Completer<ImportedBytes?>? pending;
  String? output;
  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => input;
  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => pending != null ? await pending!.future : bytes;
  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async {
    output = text;
    return name;
  }

  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    output = utf8.decode(bytes);
    return name;
  }
}

class _Port implements NotificationsPort {
  @override
  Future<bool> allowed(bool request) async => true;
  @override
  Future<Map<int, String>> pending(String namespace) async => {};
  @override
  Future<void> schedule(String namespace, ReminderRequest request) async {}
  @override
  Future<void> cancel(int id) async {}
}

class _Settings implements ReminderSettingsStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

ReminderController testReminders() => ReminderController(
  'recall',
  dailyReview: true,
  port: _Port(),
  store: _Settings(),
  location: () async => tz.UTC,
);

/// Voices for tests: what a device has, and what was read.
class FakeSpeaker implements Speaker {
  List<String> voices;
  final spoken = <(String, String)>[];
  final rates = <double>[];
  FakeSpeaker([this.voices = const ['en-US', 'ja-JP', 'vi-VN']]);
  @override
  Future<List<String>> languages() async => voices;
  @override
  Future<bool> speak(String text, String language, {double rate = 1}) async {
    if (matchLanguage(language, voices) == null) return false;
    spoken.add((text, language));
    rates.add(rate);
    return true;
  }

  @override
  Future<void> stop() async {}
}

/// One deck "Skills" with one card due an hour ago.
RecallState fixture() => saveCard(
  saveDeck(emptyRecallState(), const RecallDeck(id: 'deck', name: 'Skills')),
  createCard(
    id: 'card',
    deckId: 'deck',
    front: 'Question',
    back: 'Answer',
    now: at(now.subtract(const Duration(hours: 1))),
  ),
);

Store stored(RecallState s) => Store()..text = exportRecallBackup(s);

Future<void> start(
  WidgetTester tester, {
  Store? store,
  Files? files,
  Preferences? prefs,
  Speaker? speaker,
  Size size = const Size(420, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RecallApp(
      documents: store ?? Store(),
      files: files ?? Files(),
      preferences: prefs ?? Preferences(),
      reminders: testReminders(),
      speaker: speaker ?? FakeSpeaker(),
      clock: () => now,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapKey(
  WidgetTester tester,
  String key, {
  bool settle = true,
}) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  settle ? await tester.pumpAndSettle() : await tester.pump();
}
