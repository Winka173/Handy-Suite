part of '../handy_recall.dart';

/// The note a card belongs to: its own id when it stands alone.
String noteOf(RecallCard card) => card.note.isEmpty ? card.id : card.note;

/// [card] and every card made from the same note, in library order.
List<RecallCard> siblingsOf(RecallState state, RecallCard card) {
  final key = noteOf(card);
  return state.cards
      .where((c) => c.id == card.id || (c.note.isNotEmpty && c.note == key))
      .toList();
}

/// Which card of its note this is: 'f' asks the front, 'r' the back, 'c2'
/// the second cloze.
String _variant(RecallCard c) => c.cloze > 0
    ? 'c${c.cloze}'
    : c.reversed
    ? 'r'
    : 'f';

/// The cards a note's text makes: one per cloze number when it has clozes,
/// otherwise the front card and, with [reverse], the reverse card.
List<String> noteVariants(String front, {bool reverse = false}) {
  final numbers = clozeNumbers(front);
  return numbers.isNotEmpty
      ? [for (final n in numbers) 'c$n']
      : ['f', if (reverse) 'r'];
}

/// Writes one note: the text the editor holds becomes all of its cards.
/// Cards that stay (same variant) keep their id and schedule; new variants
/// (a reverse card switched on, a new cloze number) start new; variants that
/// went away (reverse switched off, a cloze removed) are dropped with their
/// history. [from] is the card being edited, or null for a new note.
RecallState saveNote(
  RecallState state, {
  required String deckId,
  RecallCard? from,
  required String front,
  required String back,
  RecallImage? image,
  bool reverse = false,
  required String Function() newId,
  String? now,
}) {
  final want = noteVariants(front, reverse: reverse);
  if (want.contains('r') && image != null && image.masks.isNotEmpty)
    throw const FormatException(
      'A picture with covered parts cannot have a reverse card / Thẻ ảnh có vùng che không thể có thẻ đảo chiều',
    );
  final existing = from == null ? <RecallCard>[] : siblingsOf(state, from);
  final note = want.length > 1
      ? (from == null ? newId() : noteOf(from))
      : (from?.note ?? '');
  final open = [...want];
  final cards = <Map<String, Object?>>[];
  for (final c in state.cards) {
    if (!existing.any((e) => e.id == c.id)) {
      cards.add(c.toJson());
      continue;
    }
    final v = _variant(c);
    if (!open.remove(v)) continue;
    cards.add(
      c.copyWith({
        'front': front,
        'back': back,
        'image': image?.toJson(),
        'note': note,
      }).toJson(),
    );
  }
  for (final v in open) {
    cards.add(
      createCard(
        id: newId(),
        deckId: from?.deckId ?? deckId,
        front: front,
        back: back,
        image: image,
        now: now,
        note: note,
        cloze: v.startsWith('c') ? int.parse(v.substring(1)) : 0,
        reversed: v == 'r',
      ).toJson(),
    );
  }
  return validateRecallState({
    'version': recallSchemaVersion,
    'decks': state.decks.map((d) => d.toJson()).toList(),
    'cards': cards,
  });
}

/// Deletes [card] and every sibling made from the same note.
RecallState removeNote(RecallState state, RecallCard card) {
  final gone = siblingsOf(state, card).map((c) => c.id).toSet();
  return validateRecallState(
    RecallState(
      decks: state.decks,
      cards: state.cards.where((c) => !gone.contains(c.id)),
    ).toJson(),
  );
}

/// [due] in review order: siblings of a note already [seen] this session,
/// or of a card ahead in the queue, wait at the back, so a reverse card does
/// not follow the card that just showed its answer.
List<RecallCard> reviewOrder(
  List<RecallCard> due, {
  Set<String> seen = const {},
}) {
  final first = <RecallCard>[], later = <RecallCard>[];
  final taken = <String>{...seen};
  for (final c in due) {
    (taken.add(noteOf(c)) ? first : later).add(c);
  }
  return [...first, ...later];
}
