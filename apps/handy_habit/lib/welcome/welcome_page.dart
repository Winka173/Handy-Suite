import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'practice.dart';
import '../design/palette.dart';
import 'practice_today.dart';
import 'scenes.dart';

/// The guide cannot reach real data. Only first-launch completion is supplied
/// by its caller; replay supplies a plain route pop.
class HabitWelcomePage extends StatefulWidget {
  final Future<void> Function() onDone;
  const HabitWelcomePage({super.key, required this.onDone});
  @override
  State<HabitWelcomePage> createState() => _HabitWelcomePageState();
}

class _HabitWelcomePageState extends State<HabitWelcomePage> {
  int stage = 0;
  bool gathered = false, busy = false;
  String? error;
  final practice = HabitPractice();
  Future<void> finish() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onDone();
    } catch (_) {
      if (mounted)
        setState(
          () => error = tr(
            context,
            'Could not save. Try again.',
            'Chưa lưu được. Hãy thử lại.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void back() {
    if (busy) return;
    if (stage == 2) {
      setState(() => stage = 1);
    } else if (stage == 1 && practice.step > 0) {
      setState(practice.back);
    } else if (stage == 1) {
      setState(() => stage = 0);
    } else if (gathered) {
      setState(() => gathered = false);
    } else {
      finish();
    }
  }

  void next() {
    if (busy) return;
    if (stage == 0 && !gathered) {
      setState(() => gathered = true);
    } else if (stage == 1 && !practice.done) {
      setState(practice.advance);
    } else if (stage < 2) {
      setState(() => stage++);
    } else {
      finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = tr(
      context,
      stage == 0
          ? (gathered
                ? 'Small actions. Visible days.'
                : 'Good intentions drift away.')
          : stage == 1
          ? 'Try a day in Habit.'
          : 'A missed day keeps its place.',
      stage == 0
          ? (gathered ? 'Việc nhỏ. Ngày rõ ràng.' : 'Ý định tốt rồi nhạt dần.')
          : stage == 1
          ? 'Thử một ngày cùng Habit.'
          : 'Ngày lỡ vẫn có chỗ của mình.',
    );
    final body = tr(
      context,
      stage == 0
          ? (gathered
                ? 'The same intentions become bead strings. Fill today’s bead and build a practice, day by day. On your device, without an account.'
                : 'A note to drink water. A reading streak left behind. An empty calendar. It is easy to lose sight of the little things.')
          : stage == 1
          ? 'This is a pretend Today. Nothing here changes your habits, statistics or backups.'
          : 'A hollow bead is a day, not a failure. Your current streak may restart; your best streak and consistency still tell your story.',
      stage == 0
          ? (gathered
                ? 'Những ý định ấy thành chuỗi hạt. Lấp hạt hôm nay, tạo nếp từng ngày. Ngay trên máy, không cần tài khoản.'
                : 'Tờ nhắc uống nước. Chuỗi đọc sách bỏ dở. Lịch còn trống. Những điều nhỏ dễ trôi khỏi tầm mắt.')
          : stage == 1
          ? 'Đây là Hôm nay để tập. Không đổi thói quen, thống kê hay sao lưu thật.'
          : 'Hạt rỗng là một ngày, không phải thất bại. Chuỗi hiện tại có thể bắt đầu lại; chuỗi tốt nhất và độ đều đặn vẫn kể hành trình của bạn.',
    );
    final label = tr(
      context,
      stage == 2
          ? 'Start'
          : stage == 1
          ? 'Next'
          : gathered
          ? 'Show me how'
          : 'Bring them into today',
      stage == 2
          ? 'Bắt đầu'
          : stage == 1
          ? 'Tiếp'
          : gathered
          ? 'Chỉ tôi cách dùng'
          : 'Gom về hôm nay',
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Handy Habit', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            title,
            key: Key('welcome-title-$stage-$gathered'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 16),
        Text(body),
        if (error != null) HandyNotice(error!, tone: HandyTone.error),
      ],
    );
    final action = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stage != 1 || practice.done) ...[
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('welcome-next'),
            onPressed: busy ? null : next,
            child: Text(label),
          ),
        ],
      ],
    );
    final scene = stage == 0
        ? HabitStoryScene(gathered: gathered)
        : stage == 1
        ? PracticeToday(
            practice: practice,
            onAdvance: () => setState(practice.advance),
          )
        : const MissedDayScene();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): back,
          const SingleActivator(LogicalKeyboardKey.enter): next,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                    child: Row(
                      children: [
                        IconButton(
                          key: const Key('welcome-back'),
                          tooltip: tr(context, 'Back', 'Quay lại'),
                          onPressed: busy ? null : back,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        Expanded(
                          child: Semantics(
                            label: tr(
                              context,
                              'Stage ${stage + 1} of 3',
                              'Giai đoạn ${stage + 1}/3',
                            ),
                            child: LinearProgressIndicator(
                              value: (stage + 1) / 3,
                              minHeight: 5,
                              color: HabitPalette.of(context).vermilion,
                              backgroundColor: HabitPalette.of(context).line,
                            ),
                          ),
                        ),
                        TextButton(
                          key: const Key('welcome-skip'),
                          onPressed: busy ? null : finish,
                          child: Text(tr(context, 'Skip', 'Bỏ qua')),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        if (box.maxWidth >= 900)
                          return Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(32),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1120,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 390,
                                          ),
                                          child: stage == 0
                                              ? SizedBox(
                                                  height: 420,
                                                  child: scene,
                                                )
                                              : scene,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 64),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [words, action],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        return SingleChildScrollView(
                          padding: EdgeInsets.all(stage == 1 ? 12 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (stage != 1 || practice.done)
                                words
                              else
                                Text(
                                  tr(
                                    context,
                                    'Practice · nothing is saved',
                                    'Bản tập · không lưu gì thật',
                                  ),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              const SizedBox(height: 16),
                              stage == 0
                                  ? SizedBox(height: 320, child: scene)
                                  : scene,
                              action,
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
