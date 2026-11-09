import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

void main() {
  test('a board photo is kept, replaced cleanly, and outlives tidying', () {
    var s = createFromTemplate(
      BoardsState(),
      templateById('semester')!,
      answers: {'title': 'Semester 1'},
      examples: true,
      now: DateTime(2026, 11, 9),
    );
    final board = s.rows('boards').single.id;
    final a = Uint8List.fromList([1, 2, 3]), small = Uint8List.fromList([4]);
    s = setBoardPhoto(s, board, bytes: a, preview: small);
    final first = s.get('boards', board).str('coverPhoto');
    expect(s.files[first], a);
    s = setBoardPhoto(s, board, bytes: a, preview: small, ext: 'png');
    expect(s.files.containsKey(first), isFalse, reason: 'old photo removed');
    final second = s.get('boards', board).str('coverPhoto');
    // Deleting a card for good tidies files, never the board's photo.
    final card = topTasks(s, board: board).first.id;
    s = trashTasks(s, {card});
    s = permanentlyDelete(s, {card}, confirmed: true);
    expect(s.files.containsKey(second), isTrue);
    s = setBoardPhoto(s, board);
    expect(s.get('boards', board).data['coverPhoto'], isNull);
    expect(s.files.containsKey(second), isFalse);
  });
}
