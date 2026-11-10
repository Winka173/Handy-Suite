import 'dart:async';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import 'entitlements.dart';
import 'feature_demo.dart';

/// A disposable plan, evaluated by the real engine; no controller or repository.
(String, List<RoutineStep>) demoPlan(
  BuildContext c,
  HabitProFeature f,
  bool after,
) {
  String t(String en, String vi) => tr(c, en, vi);
  RoutineStep step(String id, String title, [StepLogic? logic]) =>
      RoutineStep(id: id, title: title, seconds: 300, minimum: 0, logic: logic);
  final walk = t('Walk', 'Đi bộ'), stretch = t('Stretch', 'Giãn cơ');
  if (f == HabitProFeature.blocks || f == HabitProFeature.presets) {
    final saved = StepBlock(
      id: 'demo',
      title: 'demo',
      steps: [step('walk', walk), step('stretch', stretch)],
    );
    final steps = after
        ? [
            if (f == HabitProFeature.blocks)
              step('read', t('Read', 'Đọc sách')),
            ...saved.insert(instance: 'preview'),
          ]
        : [step('read', t('Read', 'Đọc sách'))];
    return (
      after
          ? f == HabitProFeature.blocks
                ? t(
                    'Inserted a copy · original unchanged',
                    'Đã chèn bản sao · giữ nguyên bản gốc',
                  )
                : t(
                    'Saved plan replaces draft steps',
                    'Phương án đã lưu thay các bước nháp',
                  )
          : t(
              'Draft before choosing saved steps',
              'Nháp trước khi chọn bước đã lưu',
            ),
      steps,
    );
  }
  final logic = switch (f) {
    HabitProFeature.days => StepLogic(weekdays: [1, 2, 3, 4, 5]),
    HabitProFeature.unfinished => StepLogic(habitNotDone: 'water'),
    HabitProFeature.timeLeft => StepLogic(minimumRemaining: 600),
    HabitProFeature.choices => StepLogic(branch: 'movement', option: 'A'),
    HabitProFeature.dependencies => StepLogic(dependencies: ['first']),
    HabitProFeature.stacking => StepLogic(stackAfter: 'first'),
    HabitProFeature.durations => StepLogic(durations: {6: 900}),
    _ => StepLogic(),
  };
  final prerequisite =
      f == HabitProFeature.dependencies || f == HabitProFeature.stacking;
  final source = [
    if (prerequisite) step('first', t('Drink water', 'Uống nước')),
    step('walk', walk, logic),
    if (f == HabitProFeature.choices)
      step('stretch', stretch, StepLogic(branch: 'movement', option: 'B')),
  ];
  final day = after ? '2026-11-14' : '2026-11-09';
  var run = startSession(
    Routine(id: 'demo', title: 'demo', steps: source),
    day,
    DateTime.utc(2026, 11, 9),
    budgetSeconds: after ? 300 : 1200,
  );
  run = evaluateRoutine(
    run.copy({
      'steps': [for (final s in run.steps) StepRun(plan: s.plan).toJson()],
      'inputs': {
        ...run.inputs,
        'habitTargets': {'water': 1000},
        'doneHabits': [if (after) 'water'],
      },
      'choices': {
        if (f == HabitProFeature.choices) 'movement': after ? 'B' : 'A',
      },
    }),
  );
  if (prerequisite) {
    run = evaluateRoutine(
      run.copy({
        'steps': [
          run.steps.first.copy({
            'status': after ? 'completed' : 'skipped',
          }).toJson(),
          for (final s in run.steps.skip(1)) s.toJson(),
        ],
      }),
    );
  }
  final input = switch (f) {
    HabitProFeature.days || HabitProFeature.durations =>
      after ? t('Saturday', 'Thứ Bảy') : t('Monday', 'Thứ Hai'),
    HabitProFeature.unfinished =>
      after
          ? t('Water goal already reached', 'Đã đạt mục tiêu uống nước')
          : t('Water goal unfinished', 'Chưa đạt mục tiêu uống nước'),
    HabitProFeature.timeLeft =>
      after
          ? t('5 min left · needs 10', 'Còn 5 phút · cần 10')
          : t('20 min left · needs 10', 'Còn 20 phút · cần 10'),
    HabitProFeature.choices =>
      after
          ? t('Path B selected', 'Đã chọn nhánh B')
          : t('Path A selected', 'Đã chọn nhánh A'),
    _ =>
      after
          ? t('Water step completed', 'Bước uống nước đã xong')
          : t('Water step skipped', 'Đã bỏ qua bước uống nước'),
  };
  return (
    input,
    [
      for (final s in run.steps)
        s.plan.copy({
          'note': s.status == 'skipped'
              ? t('Skipped', 'Bỏ qua')
              : s.status == 'completed'
              ? t('Done', 'Xong')
              : t('Ready', 'Sẵn sàng'),
        }),
    ],
  );
}

class HabitProDemo extends StatefulWidget {
  final HabitProFeature feature;
  const HabitProDemo({super.key, required this.feature});
  @override
  State<HabitProDemo> createState() => _HabitProDemoState();
}

class _HabitProDemoState extends State<HabitProDemo> {
  bool after = false, playing = false;
  bool initialized = false;
  Timer? timer;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      after = MediaQuery.disableAnimationsOf(context);
      initialized = true;
      if (!MediaQuery.disableAnimationsOf(context))
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) play();
        });
    }
  }

  void play() {
    timer?.cancel();
    final reduce = MediaQuery.disableAnimationsOf(context);
    setState(() {
      after = reduce;
      playing = !reduce;
    });
    if (!reduce)
      timer = Timer(const Duration(milliseconds: 800), () {
        if (mounted)
          setState(() {
            after = true;
            playing = false;
          });
      });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = HabitPalette.of(context);
    final advanced = widget.feature.index < 9;
    final frame = advanced ? demoPlan(context, widget.feature, after) : null;
    return Container(
      key: Key('pro-demo-${widget.feature.name}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.raised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, 'Example · nothing is saved', 'Ví dụ · không lưu gì'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (!advanced) featureDemo(context, widget.feature, after),
          if (advanced)
            Semantics(
              liveRegion: true,
              child: Text(
                frame!.$1,
                key: const Key('pro-demo-input'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          const SizedBox(height: 8),
          if (advanced)
            HandySwap(
              child: Column(
                key: ValueKey(frame!.$1),
                children: [
                  for (final s in frame.$2)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.drag_handle, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s.title)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${s.seconds ~/ 60} ${tr(context, 'min', 'phút')}${s.note.isEmpty ? '' : ' · ${s.note}'}',
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                key: const Key('pro-demo-play'),
                onPressed: playing ? null : play,
                icon: const Icon(Icons.play_arrow),
                label: Text(tr(context, 'Play again', 'Xem lại')),
              ),
              TextButton(
                key: const Key('pro-demo-toggle'),
                onPressed: playing
                    ? null
                    : () => setState(() => after = !after),
                child: Text(
                  tr(context, 'Try the other case', 'Thử trường hợp khác'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
