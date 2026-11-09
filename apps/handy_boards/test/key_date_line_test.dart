import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/board/key_dates.dart';

void main() {
  testWidgets('the key date line says the time, and the hours on the day', (
    t,
  ) async {
    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final now = DateTime(2026, 12, 3, 3, 0);
    expect(
      keyDateLine(ctx, 'Exam', DateTime(2026, 12, 3), now, minute: 8 * 60 + 30),
      'Exam 3/12 at 8:30, in 5 h',
    );
    expect(
      keyDateLine(ctx, 'Exam', DateTime(2026, 12, 6), now, minute: 9 * 60),
      'Exam 6/12 at 9:00, in 3 days',
    );
    expect(
      keyDateLine(ctx, 'Break', DateTime(2026, 12, 20), now),
      'Break 20/12, in 17 days',
    );
  });
}
