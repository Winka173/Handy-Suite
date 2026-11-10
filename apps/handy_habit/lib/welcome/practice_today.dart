import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import '../today/beads.dart';
import 'practice.dart';
import 'scenes.dart';

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
    final phone = Stack(
      key: canvas,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.canvas,
            borderRadius: BorderRadius.circular(24),
            border: MediaQuery.sizeOf(context).width >= 900
                ? Border.all(color: p.line, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(context, 'Today · Practice', 'Hôm nay · Bản tập'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              focus(
                m.step == 5,
                Row(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: m.finished ? .5 : 0),
                      duration: HandyMotion.of(context, HandyMotion.long),
                      builder: (context, v, _) => SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          value: v,
                          color: p.vermilion,
                          backgroundColor: p.line,
                          strokeWidth: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        tr(
                          context,
                          m.finished
                              ? '1 of 2 kept today'
                              : '0 of 2 kept today',
                          m.finished
                              ? 'Hôm nay giữ được 1/2'
                              : 'Hôm nay giữ được 0/2',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tr(context, 'Drink water', 'Uống nước'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                tr(
                  context,
                  '${m.water} / ${m.goal} times',
                  '${m.water} / ${m.goal} lần',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: BeadWeek(completed: 5, color: p.ochre)),
                  const SizedBox(width: 16),
                  focus(
                    m.step == 0,
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        key: const Key('practice-bead'),
                        tooltip: tr(context, 'Check in', 'Ghi nhận'),
                        onPressed: m.step == 0 ? widget.onAdvance : null,
                        icon: Bead(
                          status: m.water > 0 ? 'progress' : 'open',
                          fill: m.water / m.goal,
                          size: 40,
                          color: p.ochre,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              focus(
                m.step == 1,
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: const Key('practice-undo'),
                    onPressed: m.step == 1 ? widget.onAdvance : null,
                    child: Text(tr(context, 'Undo', 'Hoàn tác')),
                  ),
                ),
              ),
              focus(
                m.step == 2,
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton(
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(tr(context, 'Read a little', 'Đọc một chút')),
                  ),
                  Bead(
                    status: m.finished ? 'completed' : 'open',
                    fill: m.finished ? 1 : 0,
                    size: 40,
                    color: p.vermilion,
                  ),
                ],
              ),
              const Divider(height: 28),
              Text(
                tr(context, 'A small morning', 'Buổi sáng nhỏ'),
                style: Theme.of(context).textTheme.titleMedium,
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
              child: CustomPaint(
                painter: _Spotlight(window!, p.canvas, p.ochre),
              ),
            ),
          ),
        if (window != null && !m.done)
          Positioned(
            left: 12,
            right: 12,
            top: window!.center.dy <= phoneHeight / 2
                ? window!.bottom + 12
                : null,
            bottom: window!.center.dy > phoneHeight / 2
                ? phoneHeight - window!.top + 12
                : null,
            child: IgnorePointer(
              child: Semantics(
                key: Key('practice-instruction-${m.step}'),
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border.all(color: p.ochre),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    words,
                    style: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
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
        phone,
        const SizedBox(height: 16),
        if (m.done)
          Semantics(
            liveRegion: true,
            child: Text(
              words,
              key: Key('practice-instruction-${m.step}'),
              style: TextStyle(fontWeight: FontWeight.w700, color: p.anchor),
            ),
          ),
        if (!m.done)
          TextButton(
            key: const Key('welcome-do-it'),
            onPressed: widget.onAdvance,
            child: Text(tr(context, 'Do it for me', 'Làm giúp tôi')),
          ),
      ],
    );
  }
}

class _Spotlight extends CustomPainter {
  final Rect window;
  final Color ground, highlight;
  _Spotlight(this.window, this.ground, this.highlight);
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
    canvas.drawPath(path, Paint()..color = ground.withValues(alpha: .66));
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
      old.window != window ||
      old.ground != ground ||
      old.highlight != highlight;
}
