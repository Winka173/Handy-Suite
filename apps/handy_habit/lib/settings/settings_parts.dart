import 'package:handy_ui/kit.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

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
        animationStyle: AnimationStyle(
          duration: HandyMotion.of(context),
          reverseDuration: HandyMotion.of(context),
        ),
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
  'studio',
  'showMoodToday',
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

/// A readable place and its current offset; historical check-in days stay fixed.
String habitZoneLabel(BuildContext context, String zone, DateTime now) {
  final minutes = location(
    zone,
  ).timeZone(now.millisecondsSinceEpoch).offset.inMinutes;
  final hours = minutes.abs() ~/ 60;
  final remainder = minutes.abs() % 60;
  final offset = minutes == 0
      ? 'GMT'
      : 'GMT${minutes < 0 ? '−' : '+'}$hours${remainder == 0 ? '' : ':${remainder.toString().padLeft(2, '0')}'}';
  final name = switch (zone) {
    'Asia/Ho_Chi_Minh' ||
    'Asia/Saigon' => tr(context, 'Vietnam time', 'Giờ Việt Nam'),
    'UTC' ||
    'Etc/UTC' ||
    'Etc/GMT' => tr(context, 'Coordinated universal time', 'Giờ quốc tế'),
    _ => zone.split('/').last.replaceAll('_', ' '),
  };
  return '$name ($offset)';
}
