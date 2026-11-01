import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_storage/documents.dart';
import 'schedule.dart' show stamp;

String newId() =>
    '${DateTime.now().millisecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';

/// Owns the study library on this device. Every change is written first and
/// only then shown, so a failed write leaves the screen and file as they were.
class RecallStore extends ChangeNotifier {
  final DocumentRepository documents;
  RecallStore(this.documents);

  RecallState? state;
  Object? error;
  bool get loaded => state != null;

  /// Injectable clock, so tests and screenshots can fix "now".
  DateTime Function() clock = DateTime.now;

  Future<void> load() async {
    error = null;
    notifyListeners();
    try {
      final text = await documents.load();
      state = text == null ? emptyRecallState() : parseRecallBackup(text);
    } catch (e) {
      // A corrupt file is kept as it is; the recovery page handles it.
      error = e;
    }
    notifyListeners();
  }

  Future<void> commit(RecallState next) async {
    await documents.save(exportRecallBackup(next));
    state = next;
    notifyListeners();
  }

  Future<void> saveDeckRecord(RecallDeck deck) =>
      commit(saveDeck(state!, deck));
  Future<void> removeDeckRecord(String id) => commit(removeDeck(state!, id));
  Future<void> saveCardRecord(RecallCard card) =>
      commit(saveCard(state!, card));
  Future<void> removeCardRecord(String id) => commit(removeCard(state!, id));

  /// Grades a card with the real scheduler and writes it before returning.
  Future<RecallCard> grade(RecallCard card, String rating) async {
    final next = reviewCard(card, rating, now: stamp(clock()));
    await commit(saveCard(state!, next));
    return next;
  }

  /// Adds every row of a CSV to [deckId]; a bad file adds nothing.
  Future<int> importCsv(String text, String deckId) async {
    final added = importCardsCsv(text, deckId, newId(), now: stamp(clock()));
    await commit(
      validateRecallState({
        ...state!.toJson(),
        'cards': [
          ...state!.cards.map((c) => c.toJson()),
          ...added.map((c) => c.toJson()),
        ],
      }),
    );
    return added.length;
  }
}
