import 'package:handy_ui/kit.dart';
import 'palette.dart';
import 'studio_style.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import '../habits/habit_appearance.dart';

/// Preview shares the applied palette, spacing, icon set and bead vocabulary.
class StudioPreview extends StatelessWidget {
  final StudioStyle style;
  final Habit? habit;
  const StudioPreview({super.key, required this.style, this.habit});
  @override
  Widget build(BuildContext context) {
    final p = HabitPalette.of(context);
    return Container(
      key: const Key('studio-preview'),
      padding: const EdgeInsets.all(16),
      color: p.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, 'Today · preview', 'Hôm nay · xem trước'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            tr(
              context,
              'Two small starts. One day.',
              'Hai khởi đầu nhỏ. Một ngày.',
            ),
          ),
          for (final (en, vi, icon, mark) in [
            (
              habit?.title ?? 'Read 6 pages',
              habit?.title ?? 'Đọc 6 trang',
              studioExtraIcons[style.icons[habit?.id]] ??
                  (habit == null
                      ? Icons.menu_book_outlined
                      : hasHabitIcon(habit!)
                      ? habitIcon(habit!.icon)
                      : Icons.circle),
              habit == null ? p.vermilion : habitMark(context, habit!),
            ),
            (
              'Walk outside',
              'Đi bộ ngoài trời',
              Icons.directions_walk,
              p.vermilion,
            ),
          ])
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: EdgeInsets.all(style.spacing == 'airy' ? 20 : 12),
              decoration: BoxDecoration(
                color: style.layout == 'cards' ? p.surface : null,
                border: style.layout == 'cards'
                    ? Border.all(color: p.control)
                    : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 22, color: mark),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tr(context, en, vi))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < 5 ? mark : null,
                              border: Border.all(color: mark),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            tr(context, 'Routine · Read quietly', 'Quy trình · Đọc yên tĩnh'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (style.runner == 'beads') const LinearProgressIndicator(value: .5),
          Text('05:00', style: Theme.of(context).textTheme.headlineSmall),
          Text(
            style.runner == 'quiet'
                ? tr(context, 'Quiet timer', 'Đồng hồ tĩnh')
                : tr(context, 'Bead progress', 'Tiến độ chuỗi hạt'),
          ),
        ],
      ),
    );
  }
}
