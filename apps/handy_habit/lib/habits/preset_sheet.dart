import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import 'habit_editor.dart';

/// A new habit: one of the presets by group, or a blank one. A preset only
/// fills the editor; nothing is saved until the person saves it there.
Future<bool> addHabit(BuildContext context, HabitScope scope) async {
  final taken = {for (final h in scope.state.habits) h.title.toLowerCase()};
  final choice = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .75,
      maxChildSize: .95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          HandySpace.l,
          0,
          HandySpace.l,
          HandySpace.xxl,
        ),
        children: [
          Semantics(
            header: true,
            child: Text(
              tr(context, 'New habit', 'Thói quen mới'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: HandySpace.s),
          Text(
            tr(
              context,
              'Start from one below and change anything, or write your own.',
              'Chọn một gợi ý rồi sửa tuỳ ý, hoặc tự đặt.',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: HandySpace.m),
          FilledButton.tonalIcon(
            key: const Key('preset-blank'),
            onPressed: () => Navigator.pop(context, 'blank'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(tr(context, 'Write my own', 'Tự đặt từ đầu')),
          ),
          for (final MapEntry(key: group, value: (en, vi))
              in habitPresetGroups.entries) ...[
            HandyLabel(tr(context, en, vi)),
            Wrap(
              spacing: HandySpace.s,
              runSpacing: HandySpace.s,
              children: [
                for (final p in habitPresets.where((p) => p.group == group))
                  if (!taken.contains(tr(context, p.en, p.vi).toLowerCase()))
                    ActionChip(
                      key: Key('preset-${p.id}'),
                      label: Text(tr(context, p.en, p.vi)),
                      onPressed: () => Navigator.pop(context, p),
                    ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return false;
  return openHabitEditor(
    context,
    scope,
    null,
    choice is HabitPreset ? choice : null,
  );
}
