import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/form.dart';
import '../pro/entitlements.dart';

class SavedFilters extends StatelessWidget {
  final HabitScope scope;
  final String area;
  final Json values;
  final ValueChanged<Json> onApply;
  const SavedFilters({
    super.key,
    required this.scope,
    required this.area,
    required this.values,
    required this.onApply,
  });
  @override
  Widget build(BuildContext context) {
    final saved = objects(
      scope.state.settings['savedFilters'] ?? [],
    ).where((f) => f['area'] == area);
    bool allowed() {
      if (scope.pro(context)) return true;
      openHabitPro(context, HabitProFeature.convenience);
      return false;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton.icon(
          key: Key('save-filter-$area'),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: Text(tr(context, 'Save this view', 'Lưu bộ lọc này')),
          onPressed: () async {
            if (!allowed()) return;
            await showHabitForm(
              context,
              title: tr(context, 'Name this view', 'Đặt tên bộ lọc'),
              fields: const [HabitField('name', 'Name', 'Tên')],
              initial: const {'name': ''},
              save: (v) async {
                if (!scope.pro(context)) throw StateError('Pro required');
                await scope.controller.change(
                  (s) => s.copy({
                    'settings': {
                      ...s.settings,
                      'savedFilters': [
                        ...objects(s.settings['savedFilters'] ?? []),
                        {
                          'id': uid(),
                          'name': text(v['name'], max: 100).trim(),
                          'area': area,
                          'values': values,
                        },
                      ],
                    },
                  }),
                  automation: false,
                );
              },
            );
          },
        ),
        if (!scope.pro(context))
          const HabitProBadge(feature: HabitProFeature.convenience),
        for (final f in saved)
          InputChip(
            label: Text(f['name'] as String),
            onPressed: () {
              if (allowed())
                onApply(Map<String, dynamic>.from(f['values'] as Map));
            },
            deleteButtonTooltipMessage: tr(
              context,
              'Remove saved view',
              'Xóa bộ lọc đã lưu',
            ),
            onDeleted: () {
              if (allowed())
                scope.write(
                  context,
                  (s) => s.copy({
                    'settings': {
                      ...s.settings,
                      'savedFilters': [
                        for (final row in objects(
                          s.settings['savedFilters'] ?? [],
                        ))
                          if (row['id'] != f['id']) row,
                      ],
                    },
                  }),
                );
            },
          ),
      ],
    );
  }
}
