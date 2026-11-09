import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'kanban_app_test.dart';

void main() {
  testWidgets('tapping the dates opens time; Custom sets every 2 weeks', (
    t,
  ) async {
    final c = await boot(t, studyState());
    await tap(t, find.text('Semester 1').first);
    await settle(t);
    // The semester template lays the board out by week: tap its dates.
    await tap(t, find.byKey(const Key('week-setup')));
    expect(find.byKey(const Key('timeline-custom')), findsOneWidget);
    await tap(t, find.byKey(const Key('timeline-custom')));
    expect(find.text('Every 2 weeks'), findsOneWidget);
    await tap(t, find.byKey(const Key('span-apply')));
    await settle(t);
    final b = c.state!.get('boards', board);
    expect(boardTimeline(b), 'week');
    expect(timelineCount(b), 2);
    expect(find.text('This span'), findsOneWidget);
  });
}
