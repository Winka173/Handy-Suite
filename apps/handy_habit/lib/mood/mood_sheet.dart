import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/form.dart';
import '../ui/sheet.dart';

String moodLabel(BuildContext context, int value) => tr(
  context,
  const ['Very low', 'Low', 'Okay', 'Good', 'Very good'][value - 1],
  const ['Rất buồn', 'Buồn', 'Bình thường', 'Vui', 'Rất vui'][value - 1],
);

Future<void> openMood(
  BuildContext context,
  HabitScope scope,
  String day,
) async {
  final saved = await Navigator.pushNamed<bool>(context, '/mood/$day');
  if (saved == true && context.mounted) {
    scope.announce(
      context,
      tr(context, 'Mood updated.', 'Đã cập nhật tâm trạng.'),
    );
  }
}

/// No keyboard or required text on entry. A labelled choice commits immediately.
class MoodSheet extends StatefulWidget {
  final HabitScope scope;
  final String day;
  const MoodSheet({super.key, required this.scope, required this.day});
  @override
  State<MoodSheet> createState() => _MoodSheetState();
}

class _MoodSheetState extends State<MoodSheet> {
  late final original = moodOn(
    widget.scope.state,
    widget.day,
    includeDeleted: true,
  );
  bool details = false, busy = false;
  String error = '';
  HabitScope get scope => widget.scope;
  MoodEntry? get liveOriginal => original?.deleted == false ? original : null;
  Future<void> save(int value) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await scope.controller.change(
        (s) => saveMood(
          s,
          widget.day,
          value,
          energy: liveOriginal?.energy,
          note: liveOriginal?.note ?? '',
          tags: liveOriginal?.tags ?? [],
          now: scope.clock(),
          expectedRevision: original?.revision ?? 0,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(
          () => error = tr(
            context,
            'Not saved. Try again. ${errorText(context, e)}',
            'Chưa lưu. Hãy thử lại. ${errorText(context, e)}',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await scope.controller.change(
        (s) => deleteMood(
          s,
          widget.day,
          now: scope.clock(),
          expectedRevision: original!.revision,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(
          () => error = tr(
            context,
            'Not deleted. Try again. ${errorText(context, e)}',
            'Chưa xóa. Hãy thử lại. ${errorText(context, e)}',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = tr(context, 'Mood', 'Tâm trạng');
    if (details)
      return HabitForm(
        key: const Key('mood-details-form'),
        title: formatDay(context, widget.day),
        helpTopic: 'mood',
        fields: [
          HabitField(
            'mood',
            'Mood',
            'Tâm trạng',
            kind: FieldKind.choice,
            options: {for (var n = 1; n <= 5; n++) '$n': moodLabel(context, n)},
          ),
          HabitField(
            'energy',
            'Energy (optional)',
            'Năng lượng (tùy chọn)',
            kind: FieldKind.choice,
            required: false,
            options: {
              '': tr(context, 'Not recorded', 'Không ghi'),
              for (var n = 1; n <= 5; n++)
                '$n': tr(context, '$n of 5', '$n trên 5'),
            },
          ),
          const HabitField(
            'note',
            'Note (optional)',
            'Ghi chú (tùy chọn)',
            kind: FieldKind.note,
            required: false,
          ),
          const HabitField(
            'tags',
            'Tags (optional)',
            'Nhãn (tùy chọn)',
            kind: FieldKind.note,
            required: false,
            helpEn:
                'Separate with commas. Up to 8 distinct tags, 40 characters each.',
            helpVi:
                'Ngăn bằng dấu phẩy. Tối đa 8 nhãn khác nhau, mỗi nhãn 40 ký tự.',
          ),
        ],
        initial: {
          'mood': original == null || original!.deleted
              ? ''
              : '${original!.mood}',
          'energy': liveOriginal?.energy == null
              ? ''
              : '${liveOriginal!.energy}',
          'note': liveOriginal?.note ?? '',
          'tags': liveOriginal?.tags.join(', ') ?? '',
        },
        save: (v) async {
          final value = int.tryParse('${v['mood']}');
          if (value == null)
            throw FormatException(
              tr(context, 'Choose a mood.', 'Chọn tâm trạng.'),
            );
          final tags = '${v['tags']}'.trim().isEmpty
              ? <String>[]
              : '${v['tags']}'.split(',').map((t) => t.trim()).toList();
          if (tags.length > 8 ||
              tags.toSet().length != tags.length ||
              tags.any((t) => t.isEmpty || t.length > 40)) {
            throw FormatException(
              tr(
                context,
                'Use up to 8 distinct tags, 40 characters each.',
                'Dùng tối đa 8 nhãn khác nhau, mỗi nhãn 40 ký tự.',
              ),
            );
          }
          await scope.controller.change(
            (s) => saveMood(
              s,
              widget.day,
              value,
              energy: int.tryParse('${v['energy']}'),
              note: '${v['note']}',
              tags: tags,
              now: scope.clock(),
              expectedRevision: original?.revision ?? 0,
            ),
          );
        },
        draftContent: (context, values, patch) => Text(
          tr(
            context,
            'Notes stay in your local data and backups you choose to export.',
            'Ghi chú nằm trong dữ liệu cục bộ và bản sao lưu bạn chọn xuất.',
          ),
        ),
      );
    return SheetFrame(
      title: title,
      busy: busy,
      error: error,
      showCancel: false,
      actions: [
        IconButton(
          tooltip: tr(context, 'How to use', 'Cách dùng'),
          onPressed: busy
              ? null
              : () => Navigator.pushNamed(context, '/help/mood'),
          icon: const Icon(Icons.help_outline),
        ),
      ],
      primary: TextButton(
        key: const Key('mood-skip'),
        onPressed: busy ? null : () => Navigator.maybePop(context),
        child: Text(tr(context, 'Skip', 'Bỏ qua')),
      ),
      children: [
        Text(
          formatDay(context, widget.day),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            context,
            'Tap a feeling to save. Details are optional.',
            'Chạm một cảm nhận để lưu. Chi tiết là tùy chọn.',
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var n = 1; n <= 5; n++)
              OutlinedButton(
                key: Key('mood-choice-$n'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: busy ? null : () => save(n),
                child: Text(moodLabel(context, n)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (original != null && !original!.deleted) ...[
          Text(
            tr(
              context,
              'Recorded: ${moodLabel(context, original!.mood)}',
              'Đã ghi: ${moodLabel(context, original!.mood)}',
            ),
          ),
          if (original!.note.isNotEmpty) Text(original!.note),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('mood-details'),
            onPressed: busy ? null : () => setState(() => details = true),
            child: Text(
              tr(context, 'Add or edit details', 'Thêm hoặc sửa chi tiết'),
            ),
          ),
        ),
        if (original != null && !original!.deleted)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('mood-delete'),
              onPressed: busy ? null : remove,
              child: Text(tr(context, 'Delete entry', 'Xóa bản ghi')),
            ),
          ),
        if (original != null && !original!.deleted)
          Text(
            tr(
              context,
              'Deleted entries can be restored in Progress.',
              'Có thể khôi phục bản ghi đã xóa ở Tiến trình.',
            ),
          ),
        Text(
          tr(
            context,
            'Always optional. This does not affect your habits.',
            'Luôn tùy chọn. Không ảnh hưởng đến thói quen.',
          ),
        ),
      ],
    );
  }
}
