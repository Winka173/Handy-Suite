import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';

class HabitTrashPage extends StatelessWidget {
  final HabitScope scope;
  const HabitTrashPage({super.key, required this.scope});

  Future<void> _delete(
    BuildContext context,
    HabitTrash entry,
    String title,
  ) async {
    final ok = await confirmHandy(
      context,
      title: tr(
        context,
        'Delete "$title" for good?',
        'Xóa vĩnh viễn "$title"?',
      ),
      message: tr(
        context,
        entry.kind == 'habit'
            ? 'Its records are removed and routine links are cleared. Past routine snapshots stay. This cannot be undone.'
            : 'The routine is removed. Past runs stay in history. This cannot be undone.',
        entry.kind == 'habit'
            ? 'Các lần ghi bị xóa và liên kết quy trình bị bỏ. Các bước trong phiên cũ vẫn giữ. Không hoàn tác được.'
            : 'Quy trình bị xóa. Phiên đã chạy vẫn giữ trong lịch sử. Không hoàn tác được.',
      ),
      confirmLabel: tr(context, 'Delete for good', 'Xóa vĩnh viễn'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await scope.write(
      context,
      (s) => deleteTrash(s, entry.id),
      remember: false,
      done: (c) => tr(c, 'Deleted for good.', 'Đã xóa vĩnh viễn.'),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final s = scope.state,
          entries = s.trash.toList()
            ..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      return Scaffold(
        appBar: AppBar(title: Text(tr(context, 'Trash', 'Thùng rác'))),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width >= 840 ? 24 : 16,
                vertical: 16,
              ),
              children: [
                Text(
                  tr(
                    context,
                    'Deleted habits and routines stay for 30 days. Restore keeps their records and links. Archive is separate and has no expiry.',
                    'Thói quen và quy trình đã xóa được giữ 30 ngày. Khôi phục giữ các lần ghi và liên kết. Lưu trữ riêng và không hết hạn.',
                  ),
                ),
                const SizedBox(height: HandySpace.l),
                HandyReveal(
                  child: entries.isEmpty
                      ? HandyEmpty(
                          title: tr(
                            context,
                            'The trash is empty',
                            'Thùng rác trống',
                          ),
                        )
                      : Column(
                          children: [
                            for (final t in entries)
                              HandyAppear(
                                key: ValueKey(t.id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: HandySpace.m,
                                  ),
                                  child: Builder(
                                    builder: (context) {
                                      final title = t.kind == 'habit'
                                          ? s.habits
                                                .firstWhere(
                                                  (h) => h.id == t.entity,
                                                )
                                                .title
                                          : s.routines
                                                .firstWhere(
                                                  (r) => r.id == t.entity,
                                                )
                                                .title;
                                      final kind = t.kind == 'habit'
                                          ? tr(context, 'Habit', 'Thói quen')
                                          : tr(context, 'Routine', 'Quy trình');
                                      final left = formatFigure(
                                        context,
                                        '${t.daysLeft(scope.clock())}',
                                      );
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              HandyDot(
                                                t.kind == 'habit'
                                                    ? scope.habitHue(t.entity)
                                                    : scope.routineHue(
                                                        t.entity,
                                                      ),
                                              ),
                                              const SizedBox(
                                                width: HandySpace.s,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.titleMedium,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '$kind · ${tr(context, t.daysLeft(scope.clock()) == 1 ? '$left day left' : '$left days left', 'còn $left ngày')}',
                                          ),
                                          Wrap(
                                            spacing: HandySpace.m,
                                            children: [
                                              FilledButton(
                                                key: Key(
                                                  'trash-restore-${t.id}',
                                                ),
                                                onPressed: scope.controller.busy
                                                    ? null
                                                    : () => scope.write(
                                                        context,
                                                        (s) => restoreTrash(
                                                          s,
                                                          t.id,
                                                          scope.clock(),
                                                        ),
                                                        done: (c) => tr(
                                                          c,
                                                          'Restored "$title".',
                                                          'Đã khôi phục "$title".',
                                                        ),
                                                      ),
                                                child: Semantics(
                                                  label: tr(
                                                    context,
                                                    'Restore $title',
                                                    'Khôi phục $title',
                                                  ),
                                                  child: Text(
                                                    tr(
                                                      context,
                                                      'Restore',
                                                      'Khôi phục',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                key: Key(
                                                  'trash-delete-${t.id}',
                                                ),
                                                onPressed: scope.controller.busy
                                                    ? null
                                                    : () => _delete(
                                                        context,
                                                        t,
                                                        title,
                                                      ),
                                                child: Semantics(
                                                  label: tr(
                                                    context,
                                                    'Delete $title for good',
                                                    'Xóa vĩnh viễn $title',
                                                  ),
                                                  child: Text(
                                                    tr(
                                                      context,
                                                      'Delete for good',
                                                      'Xóa vĩnh viễn',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
