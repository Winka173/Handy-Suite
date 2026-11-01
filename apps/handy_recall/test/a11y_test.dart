import 'package:flutter_test/flutter_test.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

Future<void> meetsAll(WidgetTester tester, String state) async {
  for (final g in [
    textContrastGuideline,
    androidTapTargetGuideline,
    iOSTapTargetGuideline,
    labeledTapTargetGuideline,
  ]) {
    await expectLater(tester, meetsGuideline(g), reason: state);
  }
}

Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// Two decks, a long card and several due, to fill every screen.
RecallState library() {
  var s = saveDeck(
    fixture(),
    const RecallDeck(
      id: 'long',
      name: 'Từ vựng tiếng Nhật N3 — động từ nhóm 2 và các mẫu câu',
    ),
  );
  s = saveCard(
    s,
    createCard(
      id: 'c2',
      deckId: 'long',
      front:
          'Câu hỏi rất dài để kiểm tra việc xuống dòng trên màn hình hẹp của điện thoại',
      back: 'Một đáp án cũng dài không kém, có cả dấu tiếng Việt đầy đủ',
      now: at(now.subtract(const Duration(days: 2))),
    ),
  );
  return s;
}

void main() {
  for (final theme in ['light', 'dark']) {
    testWidgets(
      'today, review, deck, editor and settings meet guidelines ($theme)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await start(
          tester,
          store: stored(library()),
          prefs: Preferences()
            ..value = HandyPreferences(locale: 'vi', theme: theme),
        );
        await meetsAll(tester, 'today');
        await tapKey(tester, 'study-start');
        await meetsAll(tester, 'question');
        await tapKey(tester, 'review-show');
        await meetsAll(tester, 'answer');
        await back(tester);
        await tapKey(tester, 'deck-deck');
        await meetsAll(tester, 'deck');
        await tapKey(tester, 'card-new');
        await meetsAll(tester, 'editor');
        await tapKey(tester, 'card-close');
        await back(tester);
        await tapKey(tester, 'open-settings');
        await meetsAll(tester, 'settings');
        handle.dispose();
      },
    );
  }

  testWidgets('every Recall screen lays out at 320px without overflow', (
    tester,
  ) async {
    await start(tester, store: stored(library()), size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'study-start');
    await tapKey(tester, 'review-show');
    expect(tester.takeException(), isNull, reason: 'grade bar');
    await tapKey(tester, 'grade-good');
    await tapKey(tester, 'review-show');
    await tapKey(tester, 'grade-easy');
    expect(tester.takeException(), isNull, reason: 'done');
    await back(tester);
    await tapKey(tester, 'deck-long');
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'card-new');
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'card-close');
    await back(tester);
    await tapKey(tester, 'open-settings');
    expect(tester.takeException(), isNull);
  });
}
