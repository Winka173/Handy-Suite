import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'ui/words.dart';

/// Asks for a step's note; null when the person backed out.
Future<String?> askStepNote(BuildContext context, String note) async {
  final text = TextEditingController(text: note);
  final result = await showAdaptiveDialog<String>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(tr(context, 'Note for this step', 'Ghi chú cho bước này')),
      content: Material(
        type: MaterialType.transparency,
        child: TextField(
          key: const Key('step-note'),
          controller: text,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          maxLength: 4096,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Cancel', 'Hủy')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, text.text.trim()),
          child: Text(tr(context, 'Save', 'Lưu')),
        ),
      ],
    ),
  );
  text.dispose();
  return result;
}

Future<bool> confirmAbort(BuildContext context) => confirmHandy(
  context,
  title: tr(context, 'Stop this run?', 'Dừng phiên này?'),
  message: tr(
    context,
    'Steps already finished keep what they recorded. Undo a step first to take it back.',
    'Bước đã xong vẫn giữ phần đã ghi. Muốn gỡ thì hoàn tác bước trước.',
  ),
  confirmLabel: tr(context, 'Stop', 'Dừng'),
  destructive: true,
);

/// One step at a time: where it sits in the routine, its name, the clock,
/// and Done within reach of the thumb.
class RunnerView extends StatelessWidget {
  final RoutineSession session;
  final bool ready, acting, running, recoveryFailed, extra;
  final int elapsed, sessionElapsed, linkedValue, linkedTarget;
  final Habit? habit;
  final ValueChanged<bool> onExtra, onAutoNext;
  final ValueChanged<int> onMove;
  final VoidCallback onBack, onComplete, onSkip, onToggle, onExtend, onNote;
  final VoidCallback onUndo, onFinish, onAbort;
  const RunnerView({
    super.key,
    required this.session,
    required this.ready,
    required this.acting,
    required this.running,
    required this.elapsed,
    required this.sessionElapsed,
    required this.recoveryFailed,
    required this.habit,
    required this.linkedValue,
    required this.linkedTarget,
    required this.extra,
    required this.onExtra,
    required this.onBack,
    required this.onComplete,
    required this.onSkip,
    required this.onToggle,
    required this.onExtend,
    required this.onNote,
    required this.onAutoNext,
    required this.onMove,
    required this.onUndo,
    required this.onFinish,
    required this.onAbort,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final step = session.steps[session.cursor];
    final pending = step.status == 'pending';
    final resolved = session.steps.every((s) => s.status != 'pending');
    final planned = step.plan.seconds;
    final over = planned > 0 && elapsed > planned;
    final left =
        session.steps
            .where((s) => s.status == 'pending')
            .fold(0, (v, s) => v + s.plan.seconds) -
        (pending ? elapsed.clamp(0, planned) : 0);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: tr(context, 'Pause and go back', 'Tạm dừng và quay lại'),
          icon: const Icon(Icons.arrow_back),
          onPressed: acting ? null : onBack,
        ),
        title: Text(session.title),
        actions: [
          HandyMenuButton(
            items: [
              HandyMenuItem(
                Icons.sticky_note_2_outlined,
                tr(context, 'Note for this step', 'Ghi chú bước'),
                acting ? null : onNote,
                key: const Key('runner-note'),
              ),
              HandyMenuItem(
                Icons.more_time,
                tr(context, 'One more minute', 'Thêm 1 phút'),
                acting || !pending ? null : onExtend,
                key: const Key('runner-extend'),
              ),
              HandyMenuItem(
                session.autoNext
                    ? Icons.toggle_on_outlined
                    : Icons.toggle_off_outlined,
                session.autoNext
                    ? tr(
                        context,
                        'Stop moving on by itself',
                        'Thôi tự sang bước',
                      )
                    : tr(
                        context,
                        'Move on when time is up',
                        'Tự sang bước khi hết giờ',
                      ),
                acting ? null : () => onAutoNext(!session.autoNext),
                key: const Key('runner-auto'),
              ),
              HandyMenuItem(
                Icons.stop_circle_outlined,
                tr(context, 'Stop the run', 'Dừng phiên'),
                acting ? null : onAbort,
                destructive: true,
                key: const Key('runner-abort'),
              ),
            ],
          ),
        ],
      ),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(HandySpace.l),
                children: [
                  HandyContent(
                    maxWidth: 640,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Track(session: session),
                        const SizedBox(height: HandySpace.s),
                        Text(
                          tr(
                            context,
                            'Step ${session.cursor + 1} of ${session.steps.length} · ${clockText(left)} left in the plan',
                            'Bước ${session.cursor + 1}/${session.steps.length} · còn ${clockText(left)} theo kế hoạch',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: c.muted,
                          ),
                        ),
                        const SizedBox(height: HandySpace.xl),
                        Semantics(
                          header: true,
                          child: Text(
                            step.plan.title,
                            style: theme.textTheme.headlineMedium,
                          ),
                        ),
                        if (step.plan.note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: HandySpace.s),
                            child: Text(
                              step.plan.note,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        const SizedBox(height: HandySpace.xl),
                        Semantics(
                          liveRegion: false,
                          label: tr(
                            context,
                            '${clockText(elapsed)} so far',
                            'Đã chạy ${clockText(elapsed)}',
                          ),
                          excludeSemantics: true,
                          child: Text(
                            clockText(elapsed),
                            key: const Key('runner-clock'),
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontFeatures: tabular,
                              color: running ? c.accent : null,
                            ),
                          ),
                        ),
                        Text(
                          [
                            planned == 0
                                ? tr(
                                    context,
                                    'No timer: done when you say so',
                                    'Không đếm giờ: xong khi bạn bấm',
                                  )
                                : over
                                ? tr(
                                    context,
                                    '${clockText(elapsed - planned)} over the ${clockText(planned)} planned',
                                    'quá ${clockText(elapsed - planned)} so với ${clockText(planned)} dự kiến',
                                  )
                                : tr(
                                    context,
                                    'of ${clockText(planned)} planned',
                                    'trên ${clockText(planned)} dự kiến',
                                  ),
                            if (!running && pending)
                              tr(context, 'paused', 'đang dừng'),
                            if (!pending)
                              statusLabel(context, step.status).toLowerCase(),
                          ].join(' · '),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: c.muted,
                          ),
                        ),
                        if (session.recoveryWarning)
                          Padding(
                            padding: const EdgeInsets.only(top: HandySpace.l),
                            child: HandyNotice(
                              tr(
                                context,
                                'Paused while the app was away. The time is an estimate; big or backwards clock jumps were left out.',
                                'Đã tạm dừng khi app vắng mặt. Thời gian chỉ là ước tính; bỏ qua các bước nhảy đồng hồ lớn hoặc ngược.',
                              ),
                            ),
                          ),
                        if (recoveryFailed)
                          Padding(
                            padding: const EdgeInsets.only(top: HandySpace.l),
                            child: HandyNotice(
                              tr(
                                context,
                                'The pause could not be saved. Nothing was lost; go back and open the run again.',
                                'Chưa lưu được lúc tạm dừng. Không mất gì; hãy quay lại và mở lại phiên.',
                              ),
                              tone: HandyTone.error,
                            ),
                          ),
                        if (step.plan.habit != null)
                          Padding(
                            padding: const EdgeInsets.only(top: HandySpace.l),
                            child: _Linked(
                              habit: habit,
                              step: step.plan,
                              value: linkedValue,
                              target: linkedTarget,
                              extra: extra,
                              onExtra: acting ? null : onExtra,
                            ),
                          ),
                        const SizedBox(height: HandySpace.xl),
                        Wrap(
                          spacing: HandySpace.s,
                          runSpacing: HandySpace.s,
                          children: [
                            TextButton.icon(
                              key: const Key('runner-prev'),
                              onPressed: acting || session.cursor == 0
                                  ? null
                                  : () => onMove(-1),
                              icon: const Icon(Icons.chevron_left),
                              label: Text(
                                tr(context, 'Previous step', 'Bước trước'),
                              ),
                            ),
                            TextButton.icon(
                              key: const Key('runner-next'),
                              onPressed:
                                  acting ||
                                      session.cursor == session.steps.length - 1
                                  ? null
                                  : () => onMove(1),
                              icon: const Icon(Icons.chevron_right),
                              label: Text(tr(context, 'Next step', 'Bước sau')),
                            ),
                            if (!pending)
                              TextButton.icon(
                                key: const Key('runner-undo'),
                                onPressed: acting ? null : onUndo,
                                icon: const Icon(Icons.undo),
                                label: Text(
                                  tr(
                                    context,
                                    'Undo this step',
                                    'Hoàn tác bước này',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: !ready
          ? null
          : HandyBottomBar(
              child: resolved
                  ? FilledButton.icon(
                      key: const Key('runner-finish'),
                      onPressed: acting ? null : onFinish,
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(
                        tr(
                          context,
                          'Finish and see the run',
                          'Kết thúc và xem tổng kết',
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        OutlinedButton(
                          key: const Key('routine-pause'),
                          onPressed: acting || !pending ? null : onToggle,
                          child: Text(
                            running
                                ? tr(context, 'Pause', 'Tạm dừng')
                                : tr(context, 'Resume', 'Tiếp tục'),
                          ),
                        ),
                        if (step.plan.canSkip) ...[
                          const SizedBox(width: HandySpace.s),
                          TextButton(
                            key: const Key('runner-skip'),
                            onPressed: acting || !pending ? null : onSkip,
                            child: Text(tr(context, 'Skip', 'Bỏ qua')),
                          ),
                        ],
                        const SizedBox(width: HandySpace.s),
                        Expanded(
                          child: FilledButton(
                            key: const Key('routine-complete-step'),
                            onPressed: acting || !pending ? null : onComplete,
                            child: Text(tr(context, 'Done', 'Xong bước')),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}

/// The steps as one track: done in ink, the current one in the app's
/// hue, skipped struck through in grey, the rest pale.
class _Track extends StatelessWidget {
  final RoutineSession session;
  const _Track({required this.session});
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final ink = Theme.of(context).colorScheme.onSurface;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (final (i, s) in session.steps.indexed) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              flex: s.plan.seconds == 0
                  ? 30
                  : (s.plan.seconds ~/ 10).clamp(30, 1000),
              child: Container(
                height: i == session.cursor ? 10 : 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i == session.cursor
                      ? c.accent
                      : s.status == 'completed'
                      ? ink.withValues(alpha: .7)
                      : s.status == 'skipped'
                      ? ink.withValues(alpha: .25)
                      : c.raised,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What finishing this step records for its habit, and the choice to add
/// past a target already reached.
class _Linked extends StatelessWidget {
  final Habit? habit;
  final RoutineStep step;
  final int value, target;
  final bool extra;
  final ValueChanged<bool>? onExtra;
  const _Linked({
    required this.habit,
    required this.step,
    required this.value,
    required this.target,
    required this.extra,
    required this.onExtra,
  });
  @override
  Widget build(BuildContext context) {
    final h = habit;
    if (h == null)
      return HandyNotice(
        tr(
          context,
          'The linked habit no longer exists; this step records nothing.',
          'Thói quen liên kết không còn; bước này không ghi gì.',
        ),
      );
    if (h.archived)
      return HandyNotice(
        tr(
          context,
          'Linked habit is archived; this step records nothing.',
          'Thói quen liên kết đã lưu trữ; bước này không ghi gì.',
        ),
      );
    final reached = value >= target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyNotice(
          tr(
            context,
            'Counts for ${h.title}${h.type == 'binary' ? '' : ': +${figure(context, step.linkedValue)} ${unitOf(context, h)}'}. Today: ${progressText(context, h, value, target)}${reached ? ', target reached' : ''}.',
            'Tính cho ${h.title}${h.type == 'binary' ? '' : ': +${figure(context, step.linkedValue)} ${unitOf(context, h)}'}. Hôm nay: ${progressText(context, h, value, target)}${reached ? ', đã đạt mục tiêu' : ''}.',
          ),
        ),
        if (h.type != 'binary' && reached)
          CheckboxListTile.adaptive(
            key: const Key('runner-extra'),
            contentPadding: EdgeInsets.zero,
            title: Text(tr(context, 'Add it anyway', 'Vẫn cộng thêm')),
            value: extra,
            onChanged: onExtra == null ? null : (v) => onExtra!(v == true),
          ),
      ],
    );
  }
}
