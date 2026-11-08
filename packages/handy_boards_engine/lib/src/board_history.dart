part of '../handy_boards_engine.dart';

// Board history (Pro): what happened on a board, newest first, read only.
// It is the cards' own history put together (the same real events as the
// free Card history: created, moved, finished, reopened, dates, category,
// subtasks, fields, archive, trash), never a picture or a reconstruction.
// It starts when the app began keeping history; a card deleted for good
// takes its events with it.

/// Every recorded event of the cards on [board], newest first, from [since]
/// (local day) on when given.
List<BoardRecord> boardHistory(BoardsState s, String board, {DateTime? since}) {
  final cards = {
    for (final t in s.rows('tasks'))
      if (t.str('board') == board) t.id,
  };
  final from = since == null ? null : calendarDay(since);
  return [
    for (final e in s.rows('events'))
      if (cards.contains(e.str('task')) &&
          (from == null ||
              !calendarDay(
                DateTime.parse(e.str('at')).toLocal(),
              ).isBefore(from)))
        e,
  ]..sort((a, b) => b.str('at').compareTo(a.str('at')));
}

/// Earlier builds kept daily board pictures in `templates`
/// (`kind: 'snapshot'`); board history no longer uses them, so they go.
BoardsState dropBoardPictures(BoardsState s) {
  final old = {
    for (final r in s.rows('templates'))
      if (r.str('kind') == 'snapshot') r.id,
  };
  return old.isEmpty ? s : s.remove('templates', old);
}
