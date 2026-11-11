part of '../handy_habit_engine.dart';

/// A habit to start from: every value goes into the normal editor, where
/// the person changes what they like before saving. Times and amounts are
/// examples, never rules.
class HabitPreset {
  final String id, group, en, vi;

  /// binary, count, duration (minutes) or quantity.
  final String type;
  final String unitEn, unitVi;
  final String direction, window;
  final int limit;
  final String? collectionId;

  /// The daily minimum, in whole units (pages, glasses, minutes).
  final num target;

  /// daily, weekdays (with [weekdays]) or weekly (with [perWeek]).
  final String schedule;
  final List<int> weekdays;
  final int perWeek;
  const HabitPreset(
    this.id,
    this.group,
    this.en,
    this.vi, {
    this.type = 'binary',
    this.direction = 'build',
    this.window = 'day',
    this.limit = 0,
    this.collectionId,
    this.unitEn = '',
    this.unitVi = '',
    this.target = 1,
    this.schedule = 'daily',
    this.weekdays = const [1, 2, 3, 4, 5],
    this.perWeek = 3,
  });

  String get collection => collectionId ?? presetCollection(id, group);
  int get color => templateCollections[collection]!.color;
  int get icon =>
      habitTemplateIcons[id] ?? templateCollections[collection]!.icon;
  String get descriptionEn => templateCollections[collection]!.descriptionEn;
  String get descriptionVi => templateCollections[collection]!.descriptionVi;

  /// The editor's stored target: thousandths of a unit.
  int get stored => type == 'binary' ? 1000 : (target * 1000).round();
}

/// Groups in the order the chooser shows them.
const habitPresetGroups = {
  'morning': ('Morning', 'Buổi sáng'),
  'evening': ('Evening', 'Buổi tối'),
  'workout': ('Workout', 'Vận động'),
  'study': ('Study', 'Học tập'),
  'sleep': ('Sleep', 'Giấc ngủ'),
  'skincare': ('Skincare', 'Chăm da'),
  'digital': ('Screen time', 'Màn hình'),
  'house': ('Housework', 'Việc nhà'),
};

const habitPresets = [
  HabitPreset(
    'water-morning',
    'morning',
    'A glass of water on waking',
    'Một ly nước khi thức dậy',
  ),
  HabitPreset('make-bed', 'morning', 'Make the bed', 'Gấp chăn màn'),
  HabitPreset(
    'stretch',
    'morning',
    'Stretch for five minutes',
    'Giãn cơ',
    type: 'duration',
    target: 5,
  ),
  HabitPreset(
    'plan-day',
    'morning',
    'Write three things for today',
    'Ghi ba việc cho hôm nay',
  ),
  HabitPreset('tidy-desk', 'evening', 'Clear the desk', 'Dọn bàn làm việc'),
  HabitPreset(
    'journal',
    'evening',
    'Write a few lines',
    'Viết vài dòng nhật ký',
    type: 'duration',
    target: 5,
  ),
  HabitPreset(
    'prep-tomorrow',
    'evening',
    'Get ready for tomorrow',
    'Chuẩn bị cho ngày mai',
  ),
  HabitPreset(
    'gratitude',
    'evening',
    'One good thing today',
    'Một điều tốt hôm nay',
  ),
  HabitPreset('walk', 'workout', 'Walk', 'Đi bộ', type: 'duration', target: 20),
  HabitPreset(
    'steps',
    'workout',
    'Steps',
    'Bước chân',
    type: 'quantity',
    unitEn: 'steps',
    unitVi: 'bước',
    target: 4000,
  ),
  HabitPreset(
    'workout',
    'workout',
    'Work out',
    'Tập luyện',
    type: 'duration',
    target: 30,
    schedule: 'weekly',
    perWeek: 3,
  ),
  HabitPreset(
    'pushups',
    'workout',
    'Push-ups',
    'Chống đẩy',
    type: 'count',
    target: 10,
  ),
  HabitPreset(
    'read',
    'study',
    'Read',
    'Đọc sách',
    type: 'quantity',
    unitEn: 'pages',
    unitVi: 'trang',
    target: 10,
  ),
  HabitPreset(
    'language',
    'study',
    'Language practice',
    'Luyện ngoại ngữ',
    type: 'duration',
    target: 15,
  ),
  HabitPreset('review-cards', 'study', 'Review flashcards', 'Ôn thẻ ghi nhớ'),
  HabitPreset(
    'deep-work',
    'study',
    'Focused study',
    'Học tập trung',
    type: 'duration',
    target: 25,
    schedule: 'weekdays',
  ),
  HabitPreset('bed-time', 'sleep', 'In bed on time', 'Lên giường đúng giờ'),
  HabitPreset(
    'no-caffeine',
    'sleep',
    'No coffee after 2 pm',
    'Không cà phê sau 14 giờ',
  ),
  HabitPreset(
    'wind-down',
    'sleep',
    'Wind down without a screen',
    'Thư giãn không màn hình',
    type: 'duration',
    target: 20,
  ),
  HabitPreset('same-wake', 'sleep', 'Up at the same time', 'Dậy cùng một giờ'),
  HabitPreset(
    'cleanse',
    'skincare',
    'Wash your face, evening',
    'Rửa mặt buổi tối',
  ),
  HabitPreset('sunscreen', 'skincare', 'Sunscreen', 'Kem chống nắng'),
  HabitPreset('moisturise', 'skincare', 'Moisturise', 'Dưỡng ẩm'),
  HabitPreset(
    'water',
    'skincare',
    'Drink water through the day',
    'Uống nước trong ngày',
    type: 'quantity',
    unitEn: 'glasses',
    unitVi: 'ly',
    target: 6,
  ),
  HabitPreset(
    'phone-free-meal',
    'digital',
    'Meals without the phone',
    'Ăn không cầm điện thoại',
  ),
  HabitPreset(
    'social-cap',
    'digital',
    'Social apps under 30 minutes',
    'Mạng xã hội dưới 30 phút',
  ),
  HabitPreset(
    'inbox-zero',
    'digital',
    'Clear the inbox',
    'Dọn hộp thư',
    schedule: 'weekdays',
  ),
  HabitPreset(
    'screen-off',
    'digital',
    'Screens off an hour before bed',
    'Tắt màn hình trước khi ngủ một tiếng',
  ),
  HabitPreset('dishes', 'house', 'Do the dishes', 'Rửa bát'),
  HabitPreset(
    'ten-minute-tidy',
    'house',
    'Ten-minute tidy',
    'Dọn dẹp mười phút',
    type: 'duration',
    target: 10,
  ),
  HabitPreset(
    'laundry',
    'house',
    'Laundry',
    'Giặt đồ',
    schedule: 'weekly',
    perWeek: 2,
  ),
  HabitPreset(
    'plants',
    'house',
    'Water the plants',
    'Tưới cây',
    schedule: 'weekdays',
    weekdays: [1, 4],
  ),
  HabitPreset(
    'vegetables',
    'morning',
    'Add vegetables to a meal',
    'Thêm rau vào một bữa ăn',
    collectionId: 'nutrition',
  ),
  HabitPreset(
    'breathe',
    'evening',
    'Take a breathing break',
    'Dừng lại hít thở',
    type: 'duration',
    target: 2,
    collectionId: 'mindfulness',
  ),
  HabitPreset(
    'call-family',
    'evening',
    'Call someone you care about',
    'Gọi người thân',
    schedule: 'weekdays',
    weekdays: [7],
    collectionId: 'relationships',
  ),
  HabitPreset(
    'kind-message',
    'evening',
    'Send a thoughtful message',
    'Nhắn một lời quan tâm',
    schedule: 'weekly',
    perWeek: 2,
    collectionId: 'relationships',
  ),
  HabitPreset(
    'money-check',
    'evening',
    'Check this week’s spending',
    'Xem chi tiêu tuần này',
    schedule: 'weekdays',
    weekdays: [7],
    collectionId: 'finance',
  ),
  HabitPreset(
    'save-small',
    'evening',
    'Set a little money aside',
    'Để dành một khoản nhỏ',
    schedule: 'weekdays',
    weekdays: [5],
    collectionId: 'finance',
  ),
  HabitPreset(
    'sugary-drinks',
    'digital',
    'Fewer sugary drinks',
    'Bớt nước ngọt',
    type: 'count',
    direction: 'reduce',
    window: 'week',
    limit: 3,
    collectionId: 'reduce',
  ),
  HabitPreset(
    'smoking',
    'digital',
    'Cut back on cigarettes',
    'Bớt hút thuốc',
    type: 'count',
    direction: 'reduce',
    limit: 5,
    collectionId: 'reduce',
  ),
  HabitPreset(
    'late-snacks',
    'digital',
    'Less late-night snacking',
    'Bớt ăn khuya',
    type: 'count',
    direction: 'reduce',
    window: 'week',
    limit: 2,
    collectionId: 'reduce',
  ),
  HabitPreset(
    'social-checks',
    'digital',
    'Check social media less often',
    'Bớt mở mạng xã hội',
    type: 'count',
    direction: 'reduce',
    limit: 3,
    collectionId: 'reduce',
  ),
  HabitPreset(
    'impulse-buys',
    'digital',
    'Fewer impulse purchases',
    'Bớt mua ngẫu hứng',
    type: 'count',
    direction: 'reduce',
    window: 'week',
    limit: 1,
    collectionId: 'reduce',
  ),
  HabitPreset(
    'phone-bed',
    'digital',
    'No phone checks in bed',
    'Không mở điện thoại trên giường',
    type: 'count',
    direction: 'reduce',
    limit: 0,
    collectionId: 'reduce',
  ),
];
