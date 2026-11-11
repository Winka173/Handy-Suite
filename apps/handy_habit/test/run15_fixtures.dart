import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'run14_test.dart' as f;

HabitState convenienceSeed({String locale = 'en'}) {
  final vi = locale == 'vi', base = f.run14Seed(locale: locale);
  final water = Habit(
    id: 'water',
    title: vi ? 'Uống nước' : 'Water',
    type: 'count',
    created: '2024-01-01',
    category: vi ? 'Sức khỏe' : 'Health',
    schedules: [Schedule(id: 'water-goal', from: '2024-01-01', target: 8000)],
  );
  final rule = ConvenienceRule(
    id: 'morning-water',
    name: vi ? 'Nước sau buổi sáng' : 'Water after morning',
    kind: 'routine',
    source: base.routines.single.id,
    target: 'water',
  );
  final s = base.copy({
    'habits': [...base.habits.map((h) => h.toJson()), water.toJson()],
    'settings': {
      ...base.settings,
      'savedFilters': [
        {
          'id': 'filter1',
          'name': vi ? 'Tập trung hôm nay' : 'Everyday focus',
          'area': 'habits',
          'values': {'search': '', 'archived': false, 'order': 'manual'},
        },
        {
          'id': 'filter2',
          'name': vi ? 'Nhìn lại tháng 1' : 'January review',
          'area': 'progress',
          'values': {'kind': 'month', 'anchor': '2024-01-08', 'habit': null},
        },
      ],
      'convenienceRules': [
        rule.toJson(),
        ConvenienceRule(
          id: 'holiday',
          name: vi ? 'Kỳ nghỉ nhẹ nhàng' : 'A gentle holiday',
          kind: 'holiday',
          source: vi ? 'Vận động' : 'Movement',
          from: '2024-02-01',
          until: '2024-02-07',
          enabled: false,
        ).toJson(),
      ],
    },
  });
  final session = startSession(
    s.routines.single,
    '2024-01-08',
    DateTime.utc(2024, 1, 8),
  );
  final before = s.copy({
    'sessions': [session.toJson()],
  });
  final completed = before.copy({
    'sessions': [
      session.copy({'status': 'finished', 'anchor': null}).toJson(),
    ],
  });
  return recordChange(
    completed,
    evaluateConvenience(before, completed, '2024-01-08'),
    actor: 'demo',
  );
}
