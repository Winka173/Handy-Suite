import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as image;
part 'src/image.dart';
part 'src/csv.dart';
part 'src/cloze.dart';
part 'src/notes.dart';
part 'src/paste.dart';

String _now() => DateTime.fromMillisecondsSinceEpoch(
  DateTime.now().millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();

/// The backup schema this build writes. Version 1 files (no notes, cloze or
/// reverse cards, plain pictures or read-aloud languages) still load.
const recallSchemaVersion = 2;

const recallDeckLimit = 500,
    recallCardLimit = 20000,
    recallBackupBytes = 16000000,
    recallTextLimit = 20000;
Map<String, dynamic> _record(Object? value) {
  if (value is! Map || value.keys.any((k) => k is! String))
    throw const FormatException('Invalid recall record');
  return Map<String, dynamic>.from(value);
}

String _text(Object? value, int maximum, {bool required = true}) {
  if (value is! String ||
      value.length > maximum ||
      (required && value.trim().isEmpty))
    throw const FormatException('Invalid recall text');
  return value.trim();
}

String _id(Object? value) {
  final id = _text(value, 100);
  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id))
    throw const FormatException('Invalid recall ID');
  return id;
}

String _instant(Object? value) {
  final s = _text(value, 40);
  if (!RegExp(
    r'^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d{1,3})?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)$',
  ).hasMatch(s))
    throw const FormatException('Invalid recall timestamp');
  final day = s.substring(0, 10),
      parsedDay = DateTime.tryParse('${day}T00:00:00.000Z');
  if (day.compareTo('0001-01-01') < 0 ||
      parsedDay == null ||
      parsedDay.toIso8601String().substring(0, 10) != day)
    throw const FormatException('Invalid recall calendar date');
  final date = DateTime.tryParse(s);
  if (date == null) throw const FormatException('Invalid recall timestamp');
  return date.toUtc().toIso8601String();
}

double _number(Object? value, double min, double max, {bool integer = false}) {
  if (value is! num ||
      !value.isFinite ||
      value < min ||
      value > max ||
      (integer && value != value.truncate()))
    throw const FormatException('Invalid recall scheduling value');
  return value.toDouble();
}

bool _flag(Object? value) {
  if (value == null) return false;
  if (value is! bool) throw const FormatException('Invalid recall flag');
  return value;
}

/// A BCP 47 language tag for reading aloud ("ja-JP", "vi"), or '' for none.
String _language(Object? value) {
  if (value == null || value == '') return '';
  if (value is! String ||
      value.length > 35 ||
      !RegExp(r'^[A-Za-z]{2,3}(?:[-_][A-Za-z0-9]{1,8})*$').hasMatch(value))
    throw const FormatException('Invalid read-aloud language');
  return value;
}

class RecallDeck {
  final String id, name;

  /// New cards in this deck also get a reverse card (answer → question).
  final bool reverse;

  /// Read-aloud language of the question side and of the answer side; ''
  /// when that side is not read aloud.
  final String speakFront, speakBack;
  const RecallDeck({
    required this.id,
    required this.name,
    this.reverse = false,
    this.speakFront = '',
    this.speakBack = '',
  });
  factory RecallDeck.fromJson(Object? value) {
    final r = _record(value);
    return RecallDeck(
      id: _id(r['id']),
      name: _text(r['name'], 200),
      reverse: _flag(r['reverse']),
      speakFront: _language(r['speakFront']),
      speakBack: _language(r['speakBack']),
    );
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (reverse) 'reverse': true,
    if (speakFront.isNotEmpty) 'speakFront': speakFront,
    if (speakBack.isNotEmpty) 'speakBack': speakBack,
  };
  RecallDeck copyWith(Map<String, Object?> changes) =>
      RecallDeck.fromJson({...toJson(), ...changes});
}

class RecallCard {
  final String id, deckId, front, back, dueAt, lastReviewedAt;
  final double intervalDays, ease;
  final int reviewCount, lapses;
  final RecallImage? image;

  /// The note this card was made from, shared with its sibling cards (the
  /// reverse card, the other cloze numbers); '' when the card stands alone.
  final String note;

  /// Which cloze this card asks (`{{c2::…}}` is 2); 0 for a plain card.
  final int cloze;

  /// Asks the answer side and expects the question side.
  final bool reversed;
  const RecallCard._({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.dueAt,
    required this.lastReviewedAt,
    required this.intervalDays,
    required this.ease,
    required this.reviewCount,
    required this.lapses,
    this.image,
    this.note = '',
    this.cloze = 0,
    this.reversed = false,
  });
  factory RecallCard.fromJson(Object? value) {
    final r = _record(value);
    final card = RecallCard._(
      id: _id(r['id']),
      deckId: _id(r['deckId']),
      front: _text(r['front'], recallTextLimit, required: false),
      back: _text(r['back'], recallTextLimit, required: false),
      dueAt: _instant(r['dueAt']),
      lastReviewedAt: r['lastReviewedAt'] == ''
          ? ''
          : _instant(r['lastReviewedAt']),
      intervalDays: _number(r['intervalDays'], 0, 36500),
      ease: _number(r['ease'], 1.3, 3.5),
      reviewCount: _number(r['reviewCount'], 0, 1000000, integer: true).toInt(),
      lapses: _number(r['lapses'], 0, 1000000, integer: true).toInt(),
      image: r.containsKey('image') ? RecallImage.fromJson(r['image']) : null,
      note: r['note'] == null || r['note'] == '' ? '' : _id(r['note']),
      cloze: _number(r['cloze'] ?? 0, 0, 999, integer: true).toInt(),
      reversed: _flag(r['reversed']),
    );
    if (card.front.isEmpty && card.image == null)
      throw const FormatException('A card needs a question or a picture');
    if (card.back.isEmpty && card.image == null && card.cloze == 0)
      throw const FormatException('A card needs an answer');
    if (card.cloze > 0 &&
        (card.reversed || !clozeNumbers(card.front).contains(card.cloze)))
      throw const FormatException('Cloze card does not match its text');
    if (card.image != null &&
        card.image!.masks.isNotEmpty &&
        (card.reversed || card.image!.side != 'front'))
      throw const FormatException(
        'Covered picture parts belong on the question side',
      );
    if (card.lapses > card.reviewCount ||
        (card.reviewCount == 0 && card.lastReviewedAt.isNotEmpty) ||
        (card.reviewCount > 0 && card.lastReviewedAt.isEmpty))
      throw const FormatException('Inconsistent review history');
    if (card.lastReviewedAt.isNotEmpty &&
        card.dueAt.compareTo(card.lastReviewedAt) < 0)
      throw const FormatException('Due time cannot precede latest review');
    return card;
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'deckId': deckId,
    'front': front,
    'back': back,
    'dueAt': dueAt,
    'intervalDays': intervalDays,
    'reviewCount': reviewCount,
    'lapses': lapses,
    'ease': ease,
    'lastReviewedAt': lastReviewedAt,
    if (image != null) 'image': image!.toJson(),
    if (note.isNotEmpty) 'note': note,
    if (cloze > 0) 'cloze': cloze,
    if (reversed) 'reversed': true,
  };

  /// The side asked and the side expected, as this card shows them. A cloze
  /// card asks its text with one cloze blanked (see [clozeSpans]).
  String get question => reversed ? back : front;
  String get answer => reversed ? front : back;

  /// The picture shows with the question (with its covers), not only with
  /// the answer.
  bool get imageOnQuestion =>
      image != null && (image!.side == 'front') != reversed;

  RecallCard copyWith(Map<String, Object?> changes) {
    final value = {...toJson(), ...changes};
    for (final k in ['image', 'note', 'cloze', 'reversed']) {
      if (value[k] == null) value.remove(k);
    }
    return RecallCard.fromJson(value);
  }
}

class RecallState {
  final List<RecallDeck> decks;
  final List<RecallCard> cards;
  RecallState({
    Iterable<RecallDeck> decks = const [],
    Iterable<RecallCard> cards = const [],
  }) : decks = List.unmodifiable(decks),
       cards = List.unmodifiable(cards);
  Map<String, Object?> toJson() => {
    'version': recallSchemaVersion,
    'decks': decks.map((d) => d.toJson()).toList(),
    'cards': cards.map((c) => c.toJson()).toList(),
  };
}

RecallState emptyRecallState() => RecallState();
RecallState validateRecallState(Object? value) {
  final r = _record(value), d = r['decks'], c = r['cards'];
  if ((r['version'] != 1 && r['version'] != recallSchemaVersion) ||
      d is! List ||
      c is! List ||
      d.length > recallDeckLimit ||
      c.length > recallCardLimit)
    throw const FormatException(
      'Unsupported recall backup or collection limit exceeded',
    );
  final decks = d.map(RecallDeck.fromJson).toList(),
      cards = c.map(RecallCard.fromJson).toList(),
      deckIds = decks.map((d) => d.id).toSet();
  if (deckIds.length != decks.length ||
      cards.map((c) => c.id).toSet().length != cards.length)
    throw const FormatException('Duplicate recall IDs');
  if (cards.any((c) => !deckIds.contains(c.deckId)))
    throw const FormatException('Card refers to missing deck');
  return RecallState(decks: decks, cards: cards);
}

RecallCard createCard({
  required String id,
  required String deckId,
  required String front,
  required String back,
  RecallImage? image,
  String? now,
  String note = '',
  int cloze = 0,
  bool reversed = false,
}) => RecallCard.fromJson({
  'id': id,
  'deckId': deckId,
  'front': front,
  'back': back,
  'dueAt': now ?? _now(),
  'intervalDays': 0,
  'reviewCount': 0,
  'lapses': 0,
  'ease': 2.5,
  'lastReviewedAt': '',
  if (image != null) 'image': image.toJson(),
  if (note.isNotEmpty) 'note': note,
  if (cloze > 0) 'cloze': cloze,
  if (reversed) 'reversed': true,
});
RecallState saveDeck(RecallState state, RecallDeck deck) =>
    validateRecallState({
      'version': recallSchemaVersion,
      'decks': state.decks.any((d) => d.id == deck.id)
          ? state.decks
                .map((d) => d.id == deck.id ? deck.toJson() : d.toJson())
                .toList()
          : [...state.decks.map((d) => d.toJson()), deck.toJson()],
      'cards': state.cards.map((c) => c.toJson()).toList(),
    });
RecallState removeDeck(RecallState state, String id) => validateRecallState(
  RecallState(
    decks: state.decks.where((d) => d.id != id),
    cards: state.cards.where((c) => c.deckId != id),
  ).toJson(),
);
RecallState saveCard(RecallState state, RecallCard card) =>
    validateRecallState({
      'version': recallSchemaVersion,
      'decks': state.decks.map((d) => d.toJson()).toList(),
      'cards': state.cards.any((c) => c.id == card.id)
          ? state.cards
                .map((c) => c.id == card.id ? card.toJson() : c.toJson())
                .toList()
          : [...state.cards.map((c) => c.toJson()), card.toJson()],
    });
RecallState removeCard(RecallState state, String id) => validateRecallState(
  RecallState(
    decks: state.decks,
    cards: state.cards.where((c) => c.id != id),
  ).toJson(),
);
RecallCard reviewCard(RecallCard input, String rating, {String? now}) {
  final card = RecallCard.fromJson(input.toJson()),
      reviewedAt = _instant(now ?? _now());
  if (!['again', 'hard', 'good', 'easy'].contains(rating))
    throw const FormatException('Unknown recall rating');
  if (card.lastReviewedAt.isNotEmpty &&
      reviewedAt.compareTo(card.lastReviewedAt) < 0)
    throw const FormatException('Review time cannot move backwards');
  if (card.reviewCount >= 1000000)
    throw const FormatException('Review limit reached');
  double interval, ease = card.ease;
  if (rating == 'again') {
    interval = 1 / 144;
    ease = math.max(1.3, ease - 0.2);
  } else if (rating == 'hard') {
    interval = math.max(1, card.intervalDays * 1.2);
    ease = math.max(1.3, ease - 0.15);
  } else if (rating == 'easy') {
    interval = math.max(4, card.intervalDays * ease * 1.3);
    ease = math.min(3.5, ease + 0.15);
  } else {
    interval = card.intervalDays < 1
        ? 1
        : card.intervalDays == 1
        ? 3
        : card.intervalDays * ease;
  }
  interval = math.min(36500, interval);
  final due = DateTime.parse(reviewedAt)
      .add(Duration(milliseconds: (interval * 86400000).round()))
      .toUtc()
      .toIso8601String();
  return card.copyWith({
    'intervalDays': interval,
    'ease': ease,
    'lastReviewedAt': reviewedAt,
    'dueAt': due,
    'reviewCount': card.reviewCount + 1,
    'lapses': card.lapses + (rating == 'again' ? 1 : 0),
  });
}

List<RecallCard> dueCards(RecallState state, {String? now, String? deckId}) {
  final time = _instant(now ?? _now());
  final result = state.cards
      .where(
        (c) =>
            (deckId == null || deckId.isEmpty || c.deckId == deckId) &&
            c.dueAt.compareTo(time) <= 0,
      )
      .toList();
  result.sort((a, b) {
    final due = a.dueAt.compareTo(b.dueAt);
    return due != 0 ? due : a.id.compareTo(b.id);
  });
  return result;
}

Map<String, int> recallStats(RecallState state, {String? now, String? deckId}) {
  final cards = state.cards
      .where((c) => deckId == null || deckId.isEmpty || c.deckId == deckId)
      .toList();
  return {
    'total': cards.length,
    'due': dueCards(state, now: now, deckId: deckId).length,
    'newCards': cards.where((c) => c.reviewCount == 0).length,
    'reviewed': cards.where((c) => c.reviewCount > 0).length,
    'lapses': cards.fold(0, (sum, c) => sum + c.lapses),
  };
}

void _backupSize(String source) {
  if (source.length > recallBackupBytes ||
      utf8.encode(source).length > recallBackupBytes)
    throw const FormatException('Recall backup is too large');
}

String exportRecallBackup(RecallState state) {
  final source = const JsonEncoder.withIndent(
    '  ',
  ).convert(validateRecallState(state.toJson()).toJson());
  _backupSize(source);
  return source;
}

RecallState parseRecallBackup(String source) {
  _backupSize(source);
  return validateRecallState(jsonDecode(source));
}
