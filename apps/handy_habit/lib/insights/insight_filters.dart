import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'smart_review.dart';
import '../ui/words.dart';

int insightFilterCount(InsightFilter f) =>
    [
      f.collection,
      f.dayPart,
      f.direction,
      f.outcome,
    ].where((s) => s.isNotEmpty).length +
    (f.weekday == 0 ? 0 : 1);

class InsightFilters extends StatelessWidget {
  final HabitState state;
  final InsightFilter value;
  final ValueChanged<InsightFilter> onChanged;
  const InsightFilters({
    super.key,
    required this.state,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    String t(String en, String vi) => tr(context, en, vi);
    Widget chip(
      String id,
      String title,
      String selected,
      Map<String, String> options,
      ValueChanged<String> change,
    ) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ActionChip(
        key: Key('smart-filter-$id'),
        label: Text(selected.isEmpty ? title : options[selected] ?? title),
        avatar: selected.isEmpty ? null : const Icon(Icons.check, size: 16),
        onPressed: () async {
          final chosen = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            constraints: const BoxConstraints(maxWidth: 560),
            builder: (c) => ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(c).height * .72,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                children: [
                  Text(title, style: Theme.of(c).textTheme.titleLarge),
                  for (final e in options.entries)
                    ListTile(
                      key: Key('smart-option-$id-${e.key}'),
                      title: Text(e.value),
                      selected: selected == e.key,
                      minVerticalPadding: 12,
                      leading: Icon(
                        selected == e.key
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      onTap: () => Navigator.pop(c, e.key),
                    ),
                ],
              ),
            ),
          );
          if (chosen != null) change(chosen);
        },
      ),
    );
    InsightFilter replace({
      String? collection,
      String? part,
      String? direction,
      String? outcome,
      int? weekday,
    }) => InsightFilter(
      collection: collection ?? value.collection,
      dayPart: part ?? value.dayPart,
      direction: direction ?? value.direction,
      outcome: outcome ?? value.outcome,
      weekday: weekday ?? value.weekday,
    );
    final count = insightFilterCount(value);
    return Row(
      children: [
        Semantics(
          label: t('Filters · $count', 'Bộ lọc · $count'),
          child: Tooltip(
            message: t('Active filters', 'Bộ lọc đang dùng'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_list, size: 20),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  key: const Key('smart-filter-count'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip(
                  'collection',
                  t('Collection', 'Nhóm'),
                  value.collection,
                  {
                    '': t('All collections', 'Mọi nhóm'),
                    for (final h in state.liveHabits)
                      if (h.category.isNotEmpty) h.category: h.category,
                  },
                  (v) => onChanged(replace(collection: v)),
                ),
                chip(
                  'time',
                  t('Time of day', 'Buổi'),
                  value.dayPart,
                  {
                    '': t('Any time', 'Mọi buổi'),
                    for (final p in [
                      'morning',
                      'afternoon',
                      'evening',
                      'anytime',
                    ])
                      p: dayPartText(context, p),
                  },
                  (v) => onChanged(replace(part: v)),
                ),
                chip(
                  'direction',
                  t('Direction', 'Hướng'),
                  value.direction,
                  {
                    '': t('Build and reduce', 'Xây và giảm'),
                    'build': t('Build', 'Xây'),
                    'reduce': t('Reduce', 'Giảm'),
                  },
                  (v) => onChanged(replace(direction: v)),
                ),
                chip(
                  'weekday',
                  t('Weekday', 'Thứ'),
                  value.weekday == 0 ? '' : '${value.weekday}',
                  {
                    '': t('All weekdays', 'Mọi thứ'),
                    for (var i = 1; i <= 7; i++) '$i': weekdayLong(context, i),
                  },
                  (v) => onChanged(replace(weekday: int.tryParse(v) ?? 0)),
                ),
                chip(
                  'outcome',
                  t('Outcome', 'Kết quả'),
                  value.outcome,
                  {
                    '': t('All outcomes', 'Mọi kết quả'),
                    'kept': t('Kept', 'Đã giữ'),
                    'missed': t('Missed', 'Đã lỡ'),
                    'unknown': t('Unknown', 'Chưa rõ'),
                  },
                  (v) => onChanged(replace(outcome: v)),
                ),
              ],
            ),
          ),
        ),
        TextButton(
          key: const Key('smart-filter-clear'),
          onPressed: count == 0 ? null : () => onChanged(const InsightFilter()),
          child: Text(t('Clear', 'Xóa')),
        ),
      ],
    );
  }
}
