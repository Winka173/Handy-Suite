part of '../handy_habit_engine.dart';

class TemplateCollection {
  final String en, vi, descriptionEn, descriptionVi;
  final int icon, color;
  const TemplateCollection(
    this.en,
    this.vi,
    this.descriptionEn,
    this.descriptionVi,
    this.icon,
    this.color,
  );
}

/// Habit palette: ochre, leaf, clay, blue; never status red for a miss.
const templateCollections = <String, TemplateCollection>{
  'fitness': TemplateCollection(
    'Fitness',
    'Vận động',
    'Start with movement that fits your day.',
    'Bắt đầu với vận động vừa sức mỗi ngày.',
    0xe1e1,
    0xff4d7c0f,
  ),
  'nutrition': TemplateCollection(
    'Nutrition',
    'Ăn uống',
    'Make one meal or drink a little more intentional.',
    'Chăm chút hơn cho một bữa ăn hay thức uống.',
    0xf316,
    0xffa16207,
  ),
  'sleep': TemplateCollection(
    'Sleep',
    'Giấc ngủ',
    'Give yourself a gentler end to the day.',
    'Khép lại ngày nhẹ nhàng hơn.',
    0xeecb,
    0xff8b5e3c,
  ),
  'mindfulness': TemplateCollection(
    'Mindfulness',
    'Tĩnh tâm',
    'A small pause to notice how you feel.',
    'Dành một khoảng lặng để lắng nghe mình.',
    0xe56f,
    0xff4d7c0f,
  ),
  'learning': TemplateCollection(
    'Learning',
    'Học tập',
    'A short practice you can come back to.',
    'Một buổi học ngắn để dễ quay lại mỗi ngày.',
    0xf33c,
    0xff2563eb,
  ),
  'reading': TemplateCollection(
    'Reading',
    'Đọc sách',
    'A few pages are a good place to begin.',
    'Vài trang sách cũng là khởi đầu tốt.',
    0xf1c2,
    0xffa16207,
  ),
  'focus': TemplateCollection(
    'Productivity / Focus',
    'Công việc / Tập trung',
    'Leave room for one task at a time.',
    'Dành thời gian cho từng việc một.',
    0xf44a,
    0xff2563eb,
  ),
  'care': TemplateCollection(
    'Personal care',
    'Chăm sóc bản thân',
    'Make a little time to take care of yourself.',
    'Dành chút thời gian chăm sóc mình.',
    0xf3bb,
    0xff8b5e3c,
  ),
  'home': TemplateCollection(
    'Home',
    'Nhà cửa',
    'One small area, then you can stop.',
    'Dọn một góc nhỏ rồi nghỉ cũng được.',
    0xf107,
    0xffa16207,
  ),
  'relationships': TemplateCollection(
    'Relationships',
    'Người thân',
    'Keep in touch in a way that feels natural.',
    'Giữ liên lạc bằng những điều giản dị.',
    0xe488,
    0xff8b5e3c,
  ),
  'finance': TemplateCollection(
    'Finance',
    'Tiền bạc',
    'A quiet check on where your money goes.',
    'Dành chút thời gian xem tiền đi đâu.',
    0xf336,
    0xff4d7c0f,
  ),
  'digital': TemplateCollection(
    'Digital wellbeing',
    'Dùng thiết bị vừa đủ',
    'Make some room away from the screen.',
    'Dành thêm chút thời gian rời màn hình.',
    0xf286,
    0xff2563eb,
  ),
  'reduce': TemplateCollection(
    'Reduce',
    'Giảm bớt',
    'These limits are starting ideas. Choose what fits you; record incidents when they happen.',
    'Giới hạn chỉ là gợi ý. Chọn mức phù hợp và ghi khi có lần xảy ra.',
    0xe518,
    0xffa16207,
  ),
};

/// Audited against each template's action; collections still own category icons.
/// Material code points are data here; the app keeps static IconData references.
const habitTemplateIcons = <String, int>{
  'water-morning': 0xf0695, // water_drop_outlined
  'make-bed': 0xeec7, // bed_outlined
  'stretch': 0xe56f, // self_improvement
  'plan-day': 0xf00d, // edit_outlined
  'tidy-desk': 0xf06ea, // desk_outlined
  'journal': 0xf00d, // edit_outlined
  'prep-tomorrow': 0xf02c, // event_available_outlined
  'gratitude': 0xe25c, // favorite_outline
  'walk': 0xe1e1, // directions_walk
  'steps': 0xe1e1, // directions_walk
  'workout': 0xe28d, // fitness_center
  'pushups': 0xe28d, // fitness_center
  'read': 0xf1c2, // menu_book_outlined
  'language': 0xe67b, // translate
  'review-cards': 0xf3f6, // style_outlined
  'deep-work': 0xf44a, // timer_outlined
  'bed-time': 0xeecb, // bedtime_outlined
  'no-caffeine': 0xef68, // coffee_outlined
  'wind-down': 0xeecb, // bedtime_outlined
  'same-wake': 0xe072, // alarm
  'cleanse': 0xf3bb, // spa_outlined
  'sunscreen': 0xf4bc, // wb_sunny_outlined
  'moisturise': 0xf3bb, // spa_outlined
  'water': 0xf0695, // water_drop_outlined
  'phone-free-meal': 0xf316, // restaurant_outlined
  'social-cap': 0xf286, // phone_android_outlined
  'inbox-zero': 0xe3c4, // mail_outline
  'screen-off': 0xf286, // phone_android_outlined
  'dishes': 0xf149, // kitchen_outlined
  'ten-minute-tidy': 0xf107, // home_outlined
  'laundry': 0xf180, // local_laundry_service_outlined
  'plants': 0xf4da, // yard_outlined
  'vegetables': 0xf316, // restaurant_outlined
  'breathe': 0xe56f, // self_improvement
  'call-family': 0xe488, // people_outline
  'kind-message': 0xe155, // chat_bubble_outline
  'money-check': 0xf336, // savings_outlined
  'save-small': 0xf336, // savings_outlined
  'sugary-drinks': 0xf179, // local_drink_outlined
  'smoking': 0xf3ab, // smoking_rooms_outlined
  'late-snacks': 0xf316, // restaurant_outlined
  'social-checks': 0xf286, // phone_android_outlined
  'impulse-buys': 0xf37d, // shopping_bag_outlined
  'phone-bed': 0xf286, // phone_android_outlined
};

String presetCollection(String id, String group) => switch (id) {
  'water' || 'water-morning' => 'nutrition',
  'read' => 'reading',
  'journal' || 'gratitude' => 'mindfulness',
  'plan-day' || 'tidy-desk' || 'deep-work' || 'prep-tomorrow' => 'focus',
  'make-bed' => 'home',
  _ => switch (group) {
    'workout' => 'fitness',
    'study' => 'learning',
    'sleep' => 'sleep',
    'skincare' => 'care',
    'digital' => 'digital',
    'house' => 'home',
    _ => 'care',
  },
};

/// Fold both catalog languages for accent-insensitive search, including đ.
String templateSearchKey(String value) {
  var result = value.toLowerCase();
  const accents = {
    'a': 'àáảãạăằắẳẵặâầấẩẫậ',
    'e': 'èéẻẽẹêềếểễệ',
    'i': 'ìíỉĩị',
    'o': 'òóỏõọôồốổỗộơờớởỡợ',
    'u': 'ùúủũụưừứửữự',
    'y': 'ỳýỷỹỵ',
    'd': 'đ',
  };
  for (final entry in accents.entries) {
    for (final rune in entry.value.runes) {
      result = result.replaceAll(String.fromCharCode(rune), entry.key);
    }
  }
  return result.replaceAll(RegExp(r'[\u0300-\u036f]'), '').trim();
}

bool templateMatches(String query, Iterable<String> content) {
  final haystack = templateSearchKey(content.join(' '));
  return templateSearchKey(
    query,
  ).split(RegExp(r'\s+')).every(haystack.contains);
}

/// Stable catalog IDs; instantiate with fresh IDs only inside a save draft.
class RoutineTemplateInfo {
  final String id, collection, en, vi;
  final List<(String, String, int)> steps;
  final List<int> weekdays;
  const RoutineTemplateInfo(
    this.id,
    this.collection,
    this.en,
    this.vi,
    this.steps, {
    this.weekdays = const [1, 2, 3, 4, 5, 6, 7],
  });
  int get icon =>
      id == 'morning' ? 0xf4bc : templateCollections[collection]!.icon;
  int get seconds => steps.fold(0, (n, s) => n + s.$3);
  Routine instantiate({bool vietnamese = false}) => Routine(
    id: uid(),
    title: vietnamese ? vi : en,
    category: vietnamese
        ? templateCollections[collection]!.vi
        : templateCollections[collection]!.en,
    weekdays: weekdays,
    color: templateCollections[collection]!.color,
    icon: icon,
    steps: [
      for (final step in steps)
        RoutineStep(
          id: uid(),
          title: vietnamese ? step.$2 : step.$1,
          seconds: step.$3,
          minimum: min(60, step.$3),
        ),
    ],
  );
}

const routineTemplateCatalog = [
  RoutineTemplateInfo(
    'morning',
    'care',
    'A gentle morning',
    'Buổi sáng nhẹ nhàng',
    [
      ('Drink some water', 'Uống chút nước', 60),
      ('Stretch gently', 'Giãn cơ nhẹ', 300),
      ('Choose today’s first task', 'Chọn việc đầu tiên hôm nay', 120),
    ],
  ),
  RoutineTemplateInfo(
    'bedtime',
    'sleep',
    'Settle in for sleep',
    'Chuẩn bị đi ngủ',
    [
      ('Put things away', 'Cất đồ', 180),
      ('Prepare for tomorrow', 'Chuẩn bị ngày mai', 300),
      ('Wind down without a screen', 'Thư giãn không màn hình', 600),
    ],
  ),
  RoutineTemplateInfo(
    'study',
    'learning',
    'One study session',
    'Một buổi học',
    [
      ('Prepare your desk', 'Chuẩn bị bàn học', 120),
      ('Focus on one topic', 'Học một chủ đề', 1500),
      ('Write what you learned', 'Ghi điều đã học', 180),
    ],
    weekdays: [1, 2, 3, 4, 5],
  ),
  RoutineTemplateInfo(
    'warmup',
    'fitness',
    'Before a workout',
    'Trước buổi tập',
    [
      ('Get ready', 'Chuẩn bị', 120),
      ('Move gently', 'Vận động nhẹ', 300),
      ('Choose your pace', 'Chọn cường độ vừa sức', 60),
    ],
  ),
  RoutineTemplateInfo('house', 'home', 'Reset one room', 'Dọn lại một phòng', [
    ('Choose a small area', 'Chọn một góc nhỏ', 60),
    ('Tidy up', 'Sắp xếp', 600),
    ('Put tools away', 'Cất dụng cụ', 120),
  ]),
  RoutineTemplateInfo(
    'reading',
    'reading',
    'Make room for a book',
    'Dành thời gian đọc sách',
    [
      ('Choose a book', 'Chọn sách', 60),
      ('Read a little', 'Đọc một chút', 900),
      ('Keep one thought', 'Ghi lại một ý', 120),
    ],
  ),
  RoutineTemplateInfo(
    'skincare',
    'care',
    'Evening skincare',
    'Chăm da buổi tối',
    [
      ('Remove make-up if needed', 'Tẩy trang nếu cần', 120),
      ('Wash your face', 'Rửa mặt', 120),
      ('Moisturise', 'Dưỡng ẩm', 60),
    ],
  ),
  RoutineTemplateInfo('screen', 'digital', 'A screen break', 'Nghỉ màn hình', [
    ('Stand up', 'Đứng dậy', 60),
    ('Look into the distance', 'Nhìn ra xa', 60),
    ('Have some water', 'Uống chút nước', 60),
  ]),
  RoutineTemplateInfo(
    'exercise',
    'fitness',
    'A short exercise session',
    'Một buổi tập ngắn',
    [
      ('Warm up gently', 'Khởi động nhẹ', 300),
      ('Move at your own pace', 'Tập vừa sức', 1200),
      ('Cool down', 'Thả lỏng', 300),
    ],
    weekdays: [1, 3, 5],
  ),
  RoutineTemplateInfo(
    'recovery',
    'mindfulness',
    'A slower recovery day',
    'Một ngày nghỉ nhẹ nhàng',
    [
      ('Check how you feel', 'Lắng nghe cơ thể', 120),
      ('Stretch comfortably', 'Giãn cơ thoải mái', 300),
      ('Rest quietly', 'Nghỉ yên tĩnh', 600),
    ],
  ),
  RoutineTemplateInfo(
    'weekend',
    'home',
    'A weekend reset',
    'Sắp xếp lại cuối tuần',
    [
      ('Tidy one corner', 'Dọn một góc', 600),
      ('Check next week’s plans', 'Xem kế hoạch tuần tới', 300),
      ('Make room for a break', 'Dành thời gian nghỉ', 600),
    ],
    weekdays: [7],
  ),
];
