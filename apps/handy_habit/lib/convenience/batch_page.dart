import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/form.dart';
import '../ui/sheet.dart';
import '../pro/entitlements.dart';
import '../insights/insight_dates.dart';

class HabitBatchPage extends StatefulWidget {
  final HabitScope scope;
  const HabitBatchPage({super.key, required this.scope});
  @override
  State<HabitBatchPage> createState() => _HabitBatchPageState();
}

class _HabitBatchPageState extends State<HabitBatchPage> {
  final ids = <String>{};
  HabitScope get scope => widget.scope;
  Future<void> preview() async {
    if (!scope.pro(context)) {
      await openHabitPro(context, HabitProFeature.convenience);
      return;
    }
    await showHabitForm(
      context,
      title: tr(context, 'Batch changes', 'Sửa nhiều'),
      fields: [
        HabitField(
          'action',
          'Change',
          'Thay đổi',
          kind: FieldKind.choice,
          options: {
            'archive': tr(context, 'Archive', 'Lưu trữ'),
            'collection': tr(context, 'Move to collection', 'Chuyển nhóm'),
            'pause': tr(context, 'Holiday pause', 'Nghỉ lễ'),
            'reminder': tr(context, 'Reminder time', 'Giờ nhắc'),
          },
        ),
        HabitField(
          'collection',
          'Collection',
          'Nhóm',
          when: (v) => v['action'] == 'collection',
        ),
        HabitField(
          'from',
          'First day off',
          'Ngày nghỉ đầu',
          kind: FieldKind.date,
          when: (v) => v['action'] == 'pause',
        ),
        HabitField(
          'until',
          'Last day off',
          'Ngày nghỉ cuối',
          kind: FieldKind.date,
          when: (v) => v['action'] == 'pause',
        ),
        HabitField(
          'time',
          'New reminder time',
          'Giờ nhắc mới',
          kind: FieldKind.time,
          when: (v) => v['action'] == 'reminder',
          helpEn:
              'Only existing reminders change. Disabled reminders stay off.',
          helpVi: 'Chỉ đổi lịch nhắc hiện có. Lịch đang tắt vẫn tắt.',
        ),
      ],
      initial: {
        'action': 'archive',
        'collection': '',
        'from': scope.today,
        'until': scope.today,
        'time': '08:00',
      },
      saveLabel: tr(context, 'Preview', 'Xem trước'),
      save: (v) async {
        final revision = scope.state.revision, action = v['action'] as String;
        final value = switch (action) {
          'collection' => v['collection'] as String,
          'pause' => v['from'] as String,
          'reminder' => v['time'] as String,
          _ => '',
        };
        final selected = Set<String>.from(ids);
        final before = scope.state;
        final after = batchHabits(
          before,
          selected,
          action,
          value,
          until: v['until'] as String,
          expectedRevision: revision,
          today: scope.today,
        );
        if (!mounted) return;
        await openSheet<void>(
          context,
          (_) => _BatchPreview(
            scope: scope,
            before: before,
            after: after,
            ids: selected,
            action: action,
            value: value,
            until: v['until'] as String,
            revision: revision,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => HandyPage(
    title: tr(context, 'Batch changes', 'Sửa nhiều'),
    children: [
      Text(
        tr(
          context,
          'Choose habits, then review every change before applying.',
          'Chọn thói quen, rồi xem từng thay đổi trước khi áp dụng.',
        ),
      ),
      if (!scope.pro(context))
        const HabitProBadge(feature: HabitProFeature.convenience),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: () => setState(
              () => ids.addAll(scope.state.liveHabits.map((h) => h.id)),
            ),
            child: Text(tr(context, 'Select all', 'Chọn tất cả')),
          ),
          TextButton(
            onPressed: () => setState(ids.clear),
            child: Text(tr(context, 'Clear', 'Bỏ chọn')),
          ),
          FilledButton(
            key: const Key('batch-preview'),
            onPressed: ids.isEmpty ? null : preview,
            child: Text(
              tr(
                context,
                'Review ${ids.length} habits',
                'Xem ${ids.length} thói quen',
              ),
            ),
          ),
        ],
      ),
      for (final h in scope.state.liveHabits)
        CheckboxListTile(
          key: Key('batch-${h.id}'),
          title: Text(h.title),
          subtitle: Text(h.category),
          value: ids.contains(h.id),
          onChanged: (v) =>
              setState(() => v == true ? ids.add(h.id) : ids.remove(h.id)),
        ),
      if (scope.state.liveHabits.isEmpty)
        HandyEmpty(
          title: tr(context, 'Create a habit first', 'Hãy tạo thói quen trước'),
        ),
    ],
  );
}

class _BatchPreview extends StatefulWidget {
  final HabitScope scope;
  final HabitState before, after;
  final Set<String> ids;
  final String action, value, until;
  final int revision;
  const _BatchPreview({
    required this.scope,
    required this.before,
    required this.after,
    required this.ids,
    required this.action,
    required this.value,
    required this.until,
    required this.revision,
  });
  @override
  State<_BatchPreview> createState() => _BatchPreviewState();
}

class _BatchPreviewState extends State<_BatchPreview> {
  bool busy = false;
  String error = '';
  bool get hasChanges => switch (widget.action) {
    'archive' => widget.before.liveHabits.any(
      (h) => widget.ids.contains(h.id) && !h.archived,
    ),
    'collection' => widget.before.liveHabits.any(
      (h) => widget.ids.contains(h.id) && h.category != widget.value.trim(),
    ),
    'reminder' => objects(widget.before.settings['reminders'] ?? []).any(
      (r) =>
          r['type'] == 'habit' &&
          widget.ids.contains(r['target']) &&
          r['time'] != widget.value,
    ),
    _ => true,
  };
  String changes(BuildContext c, Habit h) => switch (widget.action) {
    'collection' => tr(
      c,
      h.category.isEmpty && widget.value.trim().isEmpty
          ? 'Still without a collection'
          : h.category == widget.value.trim()
          ? 'Already in ${widget.value.trim()}'
          : widget.value.trim().isEmpty
          ? 'Will leave ${h.category}'
          : 'Moves to ${widget.value.trim()}',
      h.category.isEmpty && widget.value.trim().isEmpty
          ? 'Vẫn chưa có nhóm'
          : h.category == widget.value.trim()
          ? 'Đã ở nhóm ${widget.value.trim()}'
          : widget.value.trim().isEmpty
          ? 'Sẽ rời nhóm ${h.category}'
          : 'Chuyển sang nhóm ${widget.value.trim()}',
    ),
    'pause' => tr(
      c,
      'Paused ${insightDates(c, widget.value, widget.until)}',
      'Tạm nghỉ ${insightDates(c, widget.value, widget.until)}',
    ),
    'reminder' =>
      [
            for (final r in objects(widget.before.settings['reminders'] ?? []))
              if (r['type'] == 'habit' && r['target'] == h.id)
                tr(
                  c,
                  'Reminder moves from ${r['time']} to ${widget.value}',
                  'Đổi giờ nhắc từ ${r['time']} sang ${widget.value}',
                ),
          ].join(', ').isEmpty
          ? tr(c, 'No reminder to change', 'Không có lịch nhắc để đổi')
          : [
              for (final r in objects(
                widget.before.settings['reminders'] ?? [],
              ))
                if (r['type'] == 'habit' && r['target'] == h.id)
                  tr(
                    c,
                    'Reminder moves from ${r['time']} to ${widget.value}',
                    'Đổi giờ nhắc từ ${r['time']} sang ${widget.value}',
                  ),
            ].join(', '),
    _ =>
      h.archived
          ? tr(c, 'Already archived', 'Đã lưu trữ')
          : tr(c, 'Will be archived', 'Sẽ lưu trữ'),
  };
  @override
  Widget build(BuildContext c) => SheetFrame(
    title: tr(c, 'Review changes', 'Xem lại thay đổi'),
    busy: busy,
    error: error,
    children: [
      if (!hasChanges)
        Text(
          tr(
            c,
            'These habits already have these values. Nothing to apply.',
            'Các thói quen đã có giá trị này. Không cần áp dụng.',
          ),
        ),
      Text(
        tr(
          c,
          '${widget.ids.length} habits · one Undo after saving',
          '${widget.ids.length} thói quen · hoàn tác một lần sau khi lưu',
        ),
      ),
      for (final h in widget.before.liveHabits.where(
        (h) => widget.ids.contains(h.id),
      ))
        ListTile(title: Text(h.title), subtitle: Text(changes(c, h))),
    ],
    primary: FilledButton(
      key: const Key('batch-apply'),
      onPressed: busy || !hasChanges
          ? null
          : () async {
              if (!widget.scope.pro(c)) {
                await openHabitPro(c, HabitProFeature.convenience);
                return;
              }
              setState(() => busy = true);
              try {
                await widget.scope.controller.change(
                  (s) => batchHabits(
                    s,
                    widget.ids,
                    widget.action,
                    widget.value,
                    until: widget.until,
                    expectedRevision: widget.revision,
                    today: widget.scope.today,
                  ),
                  automation: false,
                );
                if (c.mounted) {
                  widget.scope.announce(
                    c,
                    tr(c, 'Batch saved.', 'Đã lưu thay đổi.'),
                  );
                  Navigator.pop(c);
                }
              } catch (e) {
                if (mounted)
                  setState(
                    () => error = tr(
                      c,
                      'Nothing changed. Close and preview again.',
                      'Chưa thay đổi gì. Đóng và xem trước lại.',
                    ),
                  );
              }
              if (mounted) setState(() => busy = false);
            },
      child: Text(tr(c, 'Apply changes', 'Áp dụng thay đổi')),
    ),
  );
}
