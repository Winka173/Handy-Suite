import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import '../today/beads.dart';
import 'practice.dart';

class PracticeToday extends StatefulWidget {
  final HabitPractice practice;
  final VoidCallback onAdvance;
  const PracticeToday({
    super.key,
    required this.practice,
    required this.onAdvance,
  });
  @override
  State<PracticeToday> createState() => _PracticeTodayState();
}

class _PracticeTodayState extends State<PracticeToday> {
  final canvas = GlobalKey(), target = GlobalKey();
  Rect? window;
  double phoneHeight = 0;
  Future<void> adjustGoal() async {
    var value = '3';
    final picked = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(tr(context, 'Daily goal', 'Mục tiêu mỗi ngày')),
        content: TextFormField(
          key: const Key('practice-goal-value'),
          initialValue: value,
          onChanged: (text) => value = text,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: tr(context, 'Each day, at least', 'Mỗi ngày tối thiểu'),
            helperText: tr(context, 'Try 8 times', 'Thử 8 lần'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Cancel', 'Hủy')),
          ),
          FilledButton(
            key: const Key('practice-goal-save'),
            onPressed: () {
              if (value.trim() == '8') Navigator.pop(context, true);
            },
            child: Text(tr(context, 'Save', 'Lưu')),
          ),
        ],
      ),
    );
    if (picked == true && mounted) widget.onAdvance();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = target.currentContext?.findRenderObject() as RenderBox?;
      final parent = canvas.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || parent == null || !box.hasSize) return;
      final next = box.localToGlobal(Offset.zero, ancestor: parent) & box.size;
      if (window != next || phoneHeight != parent.size.height)
        setState(() {
          window = next;
          phoneHeight = parent.size.height;
        });
    });
    final m = widget.practice, p = HabitPalette.of(context);
    Widget focus(bool active, Widget child) =>
        KeyedSubtree(key: active ? target : null, child: child);
    final words = tr(
      context,
      [
        'Tap today’s bead.',
        'Undo takes that check-in back.',
        'Adjust the daily goal from 3 to 8 times.',
        'Start a tiny routine.',
        'Complete its reading step.',
        'See the ring and reading bead fill.',
        'Practice complete. Nothing was saved.',
      ][m.step],
      [
        'Chạm hạt hôm nay.',
        'Hoàn tác lần vừa ghi.',
        'Đổi mục tiêu mỗi ngày từ 3 lên 8 lần.',
        'Bắt đầu quy trình nhỏ.',
        'Hoàn thành bước đọc sách.',
        'Xem vòng và hạt đọc sách đầy lên.',
        'Đã tập xong. Không lưu gì thật.',
      ][m.step],
    );
    final theme = Theme.of(context);
    final waterColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF86B5FF)
        : const Color(0xFF2563EB);
    Widget habitRow(
      String title,
      String subtitle,
      Color color, {
      bool water = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < 6; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Bead(
                          status: i == 3 ? 'missed' : 'completed',
                          fill: 1,
                          size: 18,
                          color: color,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox.square(
            dimension: 48,
            child: water
                ? IconButton(
                    key: const Key('practice-bead'),
                    tooltip: tr(context, 'Check in', 'Ghi nhận'),
                    onPressed: m.step == 0 ? widget.onAdvance : null,
                    icon: Stack(
                      alignment: Alignment.center,
                      children: [
                        Bead(
                          status: 'progress',
                          fill: m.water / m.goal,
                          size: 40,
                          color: color,
                        ),
                        Icon(Icons.add, size: 20, color: color),
                      ],
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Bead(
                        status: m.finished ? 'completed' : 'open',
                        fill: 1,
                        size: 40,
                        color: color,
                      ),
                      if (m.finished)
                        Icon(
                          Icons.check,
                          size: 20,
                          color: color.computeLuminance() > .179
                              ? Colors.black
                              : Colors.white,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
    final phone = Stack(
      key: canvas,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          decoration: BoxDecoration(
            color: p.canvas,
            borderRadius: BorderRadius.circular(28),
            border: MediaQuery.sizeOf(context).width >= 900
                ? Border.all(color: p.control, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(context, 'Good morning.', 'Chào buổi sáng.'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: p.anchor,
                ),
              ),
              const SizedBox(height: 12),
              focus(
                m.step == 5,
                Row(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: m.finished ? .5 : 0),
                      duration: HandyMotion.of(context, HandyMotion.long),
                      builder: (context, value, _) => Bead(
                        status: 'progress',
                        fill: value,
                        size: 44,
                        color: p.vermilion,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(
                              context,
                              m.finished
                                  ? '1 of 2 kept today'
                                  : '0 of 2 kept today',
                              m.finished
                                  ? 'Hôm nay giữ được 1/2'
                                  : 'Hôm nay giữ được 0/2',
                            ),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: p.vermilion,
                            ),
                          ),
                          Text(
                            tr(
                              context,
                              m.finished ? '1 left to do.' : '2 left to do.',
                              m.finished ? 'Còn 1 việc.' : 'Còn 2 việc.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(context, 'Monday, 2 November', 'Thứ Hai, 2 tháng 11'),
                style: TextStyle(color: p.ochre),
              ),
              const SizedBox(height: 20),
              Text(
                tr(context, 'Habits', 'Thói quen'),
                style: theme.textTheme.titleMedium,
              ),
              focus(
                m.step == 0,
                habitRow(
                  tr(context, 'Drink water', 'Uống nước'),
                  tr(
                    context,
                    '${m.water} / ${m.goal} times',
                    '${m.water} / ${m.goal} lần',
                  ),
                  waterColor,
                  water: true,
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: focus(
                  m.step == 1,
                  TextButton(
                    key: const Key('practice-undo'),
                    onPressed: m.step == 1 ? widget.onAdvance : null,
                    child: Text(tr(context, 'Undo', 'Hoàn tác')),
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: focus(
                  m.step == 2,
                  OutlinedButton(
                    key: const Key('practice-goal'),
                    onPressed: m.step == 2 ? adjustGoal : null,
                    child: Text(
                      tr(
                        context,
                        'Daily goal: ${m.goal} times · Edit',
                        'Mục tiêu: ${m.goal} lần · Sửa',
                      ),
                    ),
                  ),
                ),
              ),
              habitRow(
                tr(context, 'Read a little', 'Đọc một chút'),
                tr(context, 'Every day', 'Mỗi ngày'),
                p.ochre,
              ),
              const Divider(height: 24),
              Text(
                tr(context, 'A small morning', 'Buổi sáng nhỏ'),
                style: theme.textTheme.titleMedium,
              ),
              Text(
                tr(
                  context,
                  m.finished
                      ? '1 of 1 steps complete'
                      : 'Read a little · 1 step',
                  m.finished ? 'Đã xong 1/1 bước' : 'Đọc một chút · 1 bước',
                ),
              ),
              const SizedBox(height: 12),
              focus(
                m.step == 3 || m.step == 4,
                FilledButton(
                  key: Key(m.running ? 'practice-complete' : 'practice-start'),
                  onPressed: m.step == 3 || m.step == 4
                      ? widget.onAdvance
                      : null,
                  child: Text(
                    tr(
                      context,
                      m.running
                          ? 'Done step'
                          : m.finished
                          ? 'Completed'
                          : 'Start routine',
                      m.running
                          ? 'Xong bước'
                          : m.finished
                          ? 'Đã hoàn thành'
                          : 'Bắt đầu quy trình',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (window != null && !m.done)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _Spotlight(window!, p.ochre)),
            ),
          ),
        if (window != null && !m.done)
          Positioned(
            left: 12,
            right: 12,
            top: window!.center.dy <= phoneHeight / 2
                ? window!.bottom + 16
                : null,
            bottom: window!.center.dy > phoneHeight / 2
                ? phoneHeight - window!.top + 16
                : null,
            child: IgnorePointer(
              child: Semantics(
                key: Key('practice-instruction-${m.step}'),
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border.all(color: p.ochre),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    words,
                    style: TextStyle(
                      color: p.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: p.ink,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Padding(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width >= 900 ? 6 : 0,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: phone,
            ),
          ),
        ),
        if (m.done)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Semantics(
              liveRegion: true,
              child: Text(
                words,
                key: Key('practice-instruction-${m.step}'),
                style: TextStyle(fontWeight: FontWeight.w700, color: p.anchor),
              ),
            ),
          ),
      ],
    );
  }
}

class _Spotlight extends CustomPainter {
  final Rect window;
  final Color highlight;
  _Spotlight(this.window, this.highlight);
  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      window.inflate(4),
      const Radius.circular(12),
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .64));
    canvas.drawRRect(
      hole,
      Paint()
        ..color = highlight.withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..color = highlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_Spotlight old) =>
      old.window != window || old.highlight != highlight;
}
