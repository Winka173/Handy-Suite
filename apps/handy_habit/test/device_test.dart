import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/home_widget.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'ui_test.dart' show seeded;

void main() {
  const day = '2024-01-08';

  test('the widget lists what is left and checks in from the line', () {
    final s = seeded().copy({
      'habits': [
        ...seeded().habits.map((h) => h.toJson()),
        Habit(
          id: 'w',
          title: 'Water',
          created: '2024-01-01',
          type: 'quantity',
          unit: 'l',
          schedules: [Schedule(id: 'x', from: '2024-01-01', target: 2000)],
        ).toJson(),
      ],
    });
    final view = habitWidgetView(s, day, vi: true);
    expect(view.value, 'Còn 2 việc');
    expect(view.rows.map((r) => r.$2), {
      'handy-habit://checkin/h',
      'handy-habit://habit/w',
    });
  });

  test('done, empty and resting days say so', () {
    final done = record(
      seeded(),
      HabitEvent(id: 'e', habit: 'h', day: day, value: 1000),
      today: day,
    );
    expect(habitWidgetView(done, day, vi: false).value, 'All done');
    expect(habitWidgetView(done, day, vi: false).rows, isEmpty);
    expect(
      habitWidgetView(
        seeded().copy({'habits': [], 'routines': []}),
        day,
        vi: true,
      ).value,
      'Chưa có thói quen',
    );
    final resting = putPause(
      seeded(),
      Pause(id: 'p', from: day, until: '2024-01-12'),
      today: day,
    );
    final view = habitWidgetView(resting, day, vi: true);
    expect(view.value, 'Đang nghỉ');
    expect(view.detail, 'Đến hết 12/01');
  });
}
