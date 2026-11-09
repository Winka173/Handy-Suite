import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/ui/item_marks.dart';
import 'new_flows_test.dart' show boot, settle;

void main() {
  testWidgets('cards show favourite, new, a note and how often opened', (
    t,
  ) async {
    final (c, _) = await boot(t);
    final first = c.library!.bookmarks.first;
    final other = c.library!.bookmarks.last;
    await c.update(
      (l) => l.copyWith(
        bookmarks: [
          for (final b in l.bookmarks)
            b.id == first.id
                ? b.copyWith(
                    isFavorite: true,
                    note: 'ask Lan',
                    openedCount: 4,
                    isRead: true,
                  )
                : b,
        ],
      ),
    );
    await settle(t);
    final recent = find.byKey(ValueKey('recent-${first.id}'));
    await t.ensureVisible(recent);
    await settle(t);
    expect(find.byKey(Key('mark-favourite-${first.id}')), findsOneWidget);
    // Opened, so no longer new; the others were just saved and are.
    expect(find.byKey(Key('mark-new-${first.id}')), findsNothing);
    expect(find.byKey(Key('mark-new-${other.id}')), findsWidgets);
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsWidgets);
    expect(find.byIcon(Icons.visibility_outlined), findsWidgets);
    expect(isNewSave(other, DateTime.now()), isTrue);
  });
}
