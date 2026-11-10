import 'package:handy_ui/kit.dart';

/// Values stay below their labels, including on narrow enlarged-text screens.
class HabitSettingChoice extends StatelessWidget {
  final String id, title, value;
  final Map<String, String> options;
  final Future<void> Function(String) onChanged;
  const HabitSettingChoice({
    super.key,
    required this.id,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => HandyTile(
    key: Key(id),
    title: title,
    subtitle: options[value] ?? value,
    onTap: () async {
      final picked = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(title),
          children: [
            for (final o in options.entries)
              SimpleDialogOption(
                key: Key('$id-${o.key}'),
                onPressed: () => Navigator.pop(context, o.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(o.value)),
                      if (o.key == value) const Icon(Icons.check),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
      if (picked != null) await onChanged(picked);
    },
  );
}

class HabitSettingToggle extends StatelessWidget {
  final String id, title;
  final bool value;
  final Future<void> Function(bool) onChanged;
  const HabitSettingToggle({
    super.key,
    required this.id,
    required this.title,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    key: Key(id),
    title: Text(title),
    subtitle: Text(
      value ? tr(context, 'On', 'Bật') : tr(context, 'Off', 'Tắt'),
    ),
    value: value,
    onChanged: (v) => onChanged(v),
  );
}

const habitPreferenceKeys = {
  'theme',
  'locale',
  'density',
  'reducedMotion',
  'weekStart',
  'dayBoundaryMinutes',
  'backfill',
  'defaultGoal',
  'defaultSchedule',
  'routineAutoTimer',
  'routineHaptics',
  'confirmRoutineExit',
};
