import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/home_widget.dart';
import 'package:handy_habit/widget_data.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

Habit habit(String id, {String type = 'binary', int target = 1000}) => Habit(
  id: id,
  title: 'Habit $id',
  created: '2024-01-06',
  schedules: [
    Schedule(id: 's$id', from: '2024-01-06', kind: 'daily', target: target),
  ],
  type: type,
  unit: type == 'duration' ? 'min' : '',
);

void main() {
  const today = '2024-01-08';
  test('a new habit has six beads, the days before it faint', () {
    final h = habit('a');
    final s = HabitState(habits: [h]);
    final d = habitBeadData(
      'h0_',
      h,
      today,
      HabitIndex.of(s),
      names: true,
      neutral: 'Habit',
    );
    expect(d['h0_beads'], 'xxxxoo');
    expect(d['h0_mode'], 'tap');
    expect(d['h0_fill'], '0');
  });

  test('counts fill a share per tap; minutes open the app', () {
    final count = habit('c', type: 'count', target: 4000);
    final minutes = habit('m', type: 'duration', target: 20000);
    final s = HabitState(habits: [count, minutes]);
    final i = HabitIndex.of(s);
    expect(
      habitBeadData('', count, today, i, names: true, neutral: '')['step'],
      '25',
    );
    expect(widgetTapMode(minutes, today, i), 'open');
  });

  test('a full day opens the app instead of adding more', () {
    final h = habit('a');
    final s = HabitState(
      habits: [h],
      events: [HabitEvent(id: 'e', habit: 'a', day: today, value: 1000)],
    );
    expect(widgetTapMode(h, today, HabitIndex.of(s)), 'open');
  });

  test('week and year are Pro; the year grid is sixteen weeks', () {
    final h = habit('a');
    final s = HabitState(habits: [h]);
    final views = habitWidgetViews(s, today, vi: false, pro: false);
    expect(views['week']!.toData()['pro'], '0');
    expect(views['week']!.uri, contains('pro'));
    final pro = habitWidgetViews(s, today, vi: false, pro: true);
    expect(pro['year']!.toData()['grid']!.length, 16 * 7);
    expect(pro['today']!.toData()['h0_id'], 'a');
  });

  test('names can be hidden on the home screen', () {
    final h = habit('a');
    final s = HabitState(habits: [h], settings: {'widgetShowNames': false});
    final data = habitWidgetViews(
      s,
      today,
      vi: false,
      pro: true,
    )['today']!.toData();
    expect(data['h0_name'], isNot(contains('Habit a')));
  });
}
