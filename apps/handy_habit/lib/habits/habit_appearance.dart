import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../design/palette.dart';

// Static IconData keeps release icon tree-shaking working. Unknown legacy IDs
// still round-trip; the fallback is presentation only, never a migration.
const habitIcons = [
  Icons.check,
  Icons.menu_book_outlined,
  Icons.water_drop_outlined,
  Icons.directions_walk,
  Icons.bedtime_outlined,
  Icons.fitness_center,
  Icons.self_improvement,
  Icons.edit_outlined,
];
const habitIconLabels = [
  ('Complete', 'Hoàn thành'),
  ('Reading', 'Đọc sách'),
  ('Water', 'Uống nước'),
  ('Walking', 'Đi bộ'),
  ('Sleep', 'Ngủ'),
  ('Exercise', 'Tập luyện'),
  ('Mindfulness', 'Thư giãn'),
  ('Writing', 'Viết'),
];
const habitColors = [
  (0xff0d9488, 'Teal', 'Xanh ngọc'),
  (0xff2563eb, 'Blue', 'Xanh dương'),
  (0xff7c3aed, 'Purple', 'Tím'),
  (0xffb42318, 'Red', 'Đỏ'),
  (0xffa16207, 'Ochre', 'Vàng đất'),
  (0xff4d7c0f, 'Green', 'Xanh lá'),
];

const templateIcons = [
  Icons.alarm,
  Icons.bed_outlined,
  Icons.chat_bubble_outline,
  Icons.coffee_outlined,
  Icons.desk_outlined,
  Icons.event_available_outlined,
  Icons.favorite_outline,
  Icons.kitchen_outlined,
  Icons.local_drink_outlined,
  Icons.local_laundry_service_outlined,
  Icons.mail_outline,
  Icons.shopping_bag_outlined,
  Icons.smoking_rooms_outlined,
  Icons.style_outlined,
  Icons.translate,
  Icons.wb_sunny_outlined,
  Icons.yard_outlined,

  Icons.restaurant_outlined,
  Icons.school_outlined,
  Icons.timer_outlined,
  Icons.spa_outlined,
  Icons.home_outlined,
  Icons.people_outline,
  Icons.savings_outlined,
  Icons.phone_android_outlined,
  Icons.remove_circle_outline,
];

IconData habitIcon(int code) =>
    [
      ...habitIcons,
      ...templateIcons,
    ].where((i) => i.codePoint == code).firstOrNull ??
    Icons.check;

/// A completion glyph is not an identity. Legacy defaults have no chosen
/// appearance; show a stable palette dot instead of implying completion.
bool hasHabitIcon(Habit h) => [
  ...habitIcons,
  ...templateIcons,
].any((i) => i.codePoint == h.icon && i != Icons.check);

Color habitMark(BuildContext context, Habit h) {
  final legacy = !hasHabitIcon(h) && h.color == 0xff0d9488;
  final color = legacy
      ? HandyPalette.of(context, HandyPalette.forKey(h.id)).mark
      : Color(h.color);
  // Cover the row and the surrounding page, whichever requires more contrast.
  final theme = Theme.of(context);
  if (!legacy && h.color == 0xffb42318 && theme.brightness == Brightness.dark) {
    return HabitPalette.dark.vermilion;
  }
  final surface = theme.brightness == Brightness.dark
      ? theme.colorScheme.surface
      : theme.scaffoldBackgroundColor;
  return habitInk(color.toARGB32(), surface);
}

/// Adjust only the displayed ink when necessary; never mutate the saved hue.
Color habitInk(int saved, Color surface) {
  var hsl = HSLColor.fromColor(Color(saved).withValues(alpha: 1));
  final background = surface.computeLuminance();
  for (var i = 0; i < 21; i++) {
    final foreground = hsl.toColor().computeLuminance();
    final ratio = foreground > background
        ? (foreground + .05) / (background + .05)
        : (background + .05) / (foreground + .05);
    if (ratio >= 4.5) return hsl.toColor();
    hsl = hsl.withLightness(
      (hsl.lightness + (background > .5 ? -.05 : .05)).clamp(0, 1),
    );
  }
  return background > .5 ? Colors.black : Colors.white;
}

/// Appearance never changes a schedule, check-in, routine link or SRS-like
/// history. Cancel does not write, and stale editors cannot overwrite edits.
Future<void> editHabitAppearance(
  BuildContext context,
  HabitScope scope,
  Habit h,
) async {
  final chosen = await pickHabitAppearance(
    context,
    title: h.title,
    initialIcon: h.icon,
    initialColor: h.color,
  );
  if (!context.mounted ||
      chosen == null ||
      (chosen.icon == h.icon && chosen.color == h.color))
    return;
  await scope.write(context, (s) {
    final current = s.habits.where((v) => v.id == h.id).firstOrNull;
    if (!identical(current, h))
      throw StateError(
        'Habit changed; reopen its appearance / Thói quen đã đổi; hãy mở lại',
      );
    return s.copy({
      'habits': [
        for (final v in s.habits)
          {
            ...v.toJson(),
            if (v.id == h.id) 'icon': chosen.icon,
            if (v.id == h.id) 'color': chosen.color,
          },
      ],
    });
  }, done: (c) => tr(c, 'Appearance saved.', 'Đã lưu diện mạo.'));
}

/// Shared picker behaviour within Habit; selecting never writes a record.
Future<({int icon, int color})?> pickHabitAppearance(
  BuildContext context, {
  required String title,
  required int initialIcon,
  required int initialColor,
}) async {
  var icon = initialIcon, color = initialColor;
  final chosen = await showDialog<({int icon, int color})>(
    context: context,
    animationStyle: AnimationStyle(
      duration: HandyMotion.of(context),
      reverseDuration: HandyMotion.of(context),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
        title: Text(tr(ctx, 'Appearance', 'Diện mạo thói quen')),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: Icon(
                    habitIcon(icon),
                    color: habitInk(color, Theme.of(ctx).colorScheme.surface),
                  ),
                  title: Text(title),
                ),
                Text(tr(ctx, 'Icon', 'Biểu tượng')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < habitIcons.length; i++)
                      Semantics(
                        selected: icon == habitIcons[i].codePoint,
                        child: IconButton.outlined(
                          key: Key('habit-icon-$i'),
                          tooltip: tr(
                            ctx,
                            habitIconLabels[i].$1,
                            habitIconLabels[i].$2,
                          ),
                          isSelected: icon == habitIcons[i].codePoint,
                          onPressed: () =>
                              update(() => icon = habitIcons[i].codePoint),
                          icon: Icon(habitIcons[i]),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(tr(ctx, 'Color', 'Màu')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < habitColors.length; i++)
                      ChoiceChip(
                        key: Key('habit-color-$i'),
                        label: Text(
                          tr(ctx, habitColors[i].$2, habitColors[i].$3),
                        ),
                        avatar: Icon(
                          Icons.circle,
                          size: 16,
                          color: habitInk(
                            habitColors[i].$1,
                            Theme.of(ctx).colorScheme.surface,
                          ),
                        ),
                        selected: color == habitColors[i].$1,
                        onSelected: (_) =>
                            update(() => color = habitColors[i].$1),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(ctx, 'Cancel', 'Hủy')),
          ),
          FilledButton(
            key: const Key('habit-appearance-save'),
            onPressed: () => Navigator.pop(ctx, (icon: icon, color: color)),
            child: Text(tr(ctx, 'Save', 'Lưu')),
          ),
        ],
      ),
    ),
  );
  return chosen;
}
