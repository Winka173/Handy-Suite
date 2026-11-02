import 'package:handy_ui/kit.dart';
import 'link_tasks.dart';

String _summary(BuildContext c, LinkJobReport r) {
  final parts = <String>[];
  if (r.job == LinkJob.check) {
    // Only the kinds found; "work" is always said, even at 0.
    final found = [
      tr(c, '${r.count('ok')} work', '${r.count('ok')} mở được'),
      if (r.count('moved') > 0)
        tr(c, '${r.count('moved')} moved', '${r.count('moved')} đã chuyển'),
      if (r.count('gone') > 0)
        tr(c, '${r.count('gone')} gone', '${r.count('gone')} không còn'),
      if (r.count('unreachable') > 0)
        tr(
          c,
          '${r.count('unreachable')} could not tell',
          '${r.count('unreachable')} không xác định',
        ),
    ];
    parts.add(
      tr(
        c,
        'Checked ${r.done} links: ${found.join(', ')}.',
        'Đã kiểm tra ${r.done} link: ${found.join(', ')}.',
      ),
    );
  } else {
    parts.add(
      tr(
        c,
        'Saved ${r.count('saved')} of ${r.done} pages for offline reading.',
        'Đã lưu ${r.count('saved')}/${r.done} trang để đọc offline.',
      ),
    );
    if (r.count('noText') > 0)
      parts.add(
        tr(
          c,
          '${r.count('noText')} had no readable text.',
          '${r.count('noText')} trang không có chữ để giữ.',
        ),
      );
    if (r.count('failed') > 0)
      parts.add(
        tr(
          c,
          '${r.count('failed')} could not be read.',
          '${r.count('failed')} trang chưa đọc được.',
        ),
      );
  }
  if (r.cancelled)
    parts.add(
      tr(
        c,
        'Stopped; what was done is kept.',
        'Đã dừng; phần đã xong được giữ.',
      ),
    );
  if (r.overCap > 0)
    parts.add(
      tr(
        c,
        '${r.overCap} more were left for another run.',
        'Còn ${r.overCap} link cho lượt sau.',
      ),
    );
  return parts.join(' ');
}

/// The one network job in progress: what it is doing, how far, and Stop.
/// When it ends, one sentence of what it found, until closed.
class TaskStrip extends StatelessWidget {
  final LinkTasks tasks;
  final VoidCallback? onBroken;
  const TaskStrip({super.key, required this.tasks, this.onBroken});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: tasks,
    builder: (context, _) {
      final c = HandyColors.of(context);
      final theme = Theme.of(context);
      final last = tasks.last;
      Widget? body;
      if (tasks.running) {
        final what = tasks.job == LinkJob.check
            ? tr(context, 'Checking links', 'Đang kiểm tra link')
            : tr(context, 'Saving offline copies', 'Đang lưu bản đọc offline');
        body = Column(
          key: const Key('task-running'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '$what · ${tr(context, '${tasks.done} of ${tasks.total}', '${tasks.done}/${tasks.total}')}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('task-stop'),
                  onPressed: tasks.cancel,
                  child: Text(tr(context, 'Stop', 'Dừng')),
                ),
              ],
            ),
            const SizedBox(height: HandySpace.xs),
            LinearProgressIndicator(
              value: tasks.total == 0 ? null : tasks.done / tasks.total,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
              backgroundColor: c.select,
            ),
          ],
        );
      } else if (last != null && last.asked > 1) {
        body = Row(
          key: const Key('task-report'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_summary(context, last)),
              ),
            ),
            if (last.job == LinkJob.check &&
                last.broken > 0 &&
                onBroken != null)
              TextButton(
                key: const Key('task-broken'),
                onPressed: onBroken,
                child: Text(tr(context, 'See them', 'Xem')),
              ),
            IconButton(
              key: const Key('task-dismiss'),
              tooltip: tr(context, 'Close', 'Đóng'),
              icon: const Icon(Icons.close, size: 20),
              onPressed: tasks.dismiss,
            ),
          ],
        );
      }
      return HandyReveal(
        child: body == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(bottom: HandySpace.m),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    HandySpace.m,
                    HandySpace.xs,
                    HandySpace.xs,
                    HandySpace.s,
                  ),
                  decoration: BoxDecoration(
                    color: c.raised,
                    borderRadius: BorderRadius.circular(HandyRadius.control),
                  ),
                  child: body,
                ),
              ),
      );
    },
  );
}
