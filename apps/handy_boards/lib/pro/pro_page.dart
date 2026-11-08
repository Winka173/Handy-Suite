import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart';
import '../design/looks.dart';
import '../design/theme.dart';
import '../design/widget_styles.dart';
import 'pro.dart';
import 'pro_demos.dart';

/// What one Pro part is called and what it does, in a line and in full.
class ProPart {
  final ProFeature feature;
  final String title, line, body;
  const ProPart(this.feature, this.title, this.line, this.body);
}

/// Every Pro part, in the groups the page lists them in.
List<(String, List<ProPart>)> proGroups(BuildContext context) {
  String t(String en, String vi) => tr(context, en, vi);
  final looksPro = boardLooks.where((l) => l.pro).length;
  final stylesPro = widgetStyles.where((w) => w.pro).length;
  return [
    (
      t('Plan', 'Lên kế hoạch'),
      [
        ProPart(
          ProFeature.myWork,
          t('My Work across boards', 'Việc của tôi trên mọi bảng'),
          t(
            'Today and coming up, from every board',
            'Hôm nay và sắp tới, từ mọi bảng',
          ),
          t(
            'Today, left behind and coming up from every board in one list. Each card stays in its own board; a tap opens it there.',
            'Hôm nay, việc còn tồn và sắp tới của mọi bảng trong một danh sách. Thẻ vẫn nằm ở bảng của nó; chạm là mở đúng chỗ.',
          ),
        ),
        ProPart(
          ProFeature.carryOver,
          t('Smart carry-over', 'Tự chuyển việc tồn'),
          t('Unfinished work moves to today', 'Việc chưa xong tự về hôm nay'),
          t(
            'When a new day or week starts, review what was left behind, or let it move to today by itself, plus a Monday review. Only the day you plan to work changes, never a due date. Moving cards by hand stays free.',
            'Khi sang ngày hay tuần mới, xem lại việc còn tồn hoặc để app tự chuyển về hôm nay, kèm lời nhắc xem lại sáng thứ Hai. Chỉ đổi ngày làm, không bao giờ đổi hạn nộp. Chuyển bằng tay vẫn miễn phí.',
          ),
        ),
        ProPart(
          ProFeature.repeat,
          t('Repeating cards', 'Thẻ lặp lại'),
          t(
            'Rent, reports, workouts come back',
            'Tiền nhà, báo cáo, buổi tập tự quay lại',
          ),
          t(
            'A finished card comes back on its rhythm: every few days, on chosen weekdays, or a day of the month. Taking a repeat off is always free.',
            'Thẻ đã xong tự quay lại theo nhịp: mỗi vài ngày, vào các thứ đã chọn, hoặc một ngày trong tháng. Bỏ lặp lúc nào cũng miễn phí.',
          ),
        ),
        ProPart(
          ProFeature.digest,
          t('Board digest', 'Tóm tắt các bảng'),
          t(
            'One morning note for every board',
            'Một thông báo buổi sáng cho mọi bảng',
          ),
          t(
            'Daily or on one day a week: one line per board with work, empty boards skipped, quiet hours kept. With "Hide card names" it gives only the totals.',
            'Hằng ngày hoặc một ngày mỗi tuần: mỗi bảng có việc một dòng, bỏ qua bảng trống, theo giờ yên lặng. Bật "Ẩn tên thẻ" thì chỉ báo tổng.',
          ),
        ),
      ],
    ),
    (
      t('Automate', 'Tự động'),
      [
        ProPart(
          ProFeature.automation,
          t('Automation rules', 'Luật tự động'),
          t(
            'When this happens, the board does that',
            'Khi việc này xảy ra, bảng tự làm việc kia',
          ),
          t(
            'Write a rule as a sentence: when the last subtask is ticked, move the card to Done; when a card reaches Review, add its checklist; archive finished cards after a while. Each rule says what it did, and Undo always works.',
            'Viết luật như một câu: tick việc con cuối thì chuyển thẻ sang Xong; thẻ vào Review thì thêm danh sách kiểm; lưu trữ thẻ xong sau một thời gian. Mỗi luật ghi lại đã làm gì, và luôn hoàn tác được.',
          ),
        ),
        ProPart(
          ProFeature.cardTemplates,
          t('Card templates', 'Mẫu thẻ'),
          t('A card you repeat, in one tap', 'Thẻ hay lặp lại, một chạm là có'),
          t(
            'Save a card you make again and again (subtasks, note, category, when it is due) and make a fresh one in any column with a tap.',
            'Lưu một thẻ hay làm lại (việc con, ghi chú, nhóm, hạn sau mấy ngày) rồi tạo thẻ mới ở cột bất kỳ bằng một chạm.',
          ),
        ),
        ProPart(
          ProFeature.savedFilters,
          t('Saved filters', 'Bộ lọc đã lưu'),
          t('Your usual view, one tap away', 'Cách xem quen thuộc, một chạm'),
          t(
            'Keep a filter you use often, such as "Work, due this week", and bring it back with a tap. The other cards are only hidden, never changed.',
            'Giữ bộ lọc hay dùng, ví dụ "Công việc, hạn tuần này", và gọi lại bằng một chạm. Thẻ khác chỉ bị ẩn, không bị đổi.',
          ),
        ),
        ProPart(
          ProFeature.fields,
          t('Custom fields', 'Trường tuỳ chỉnh'),
          t(
            'Budget, link, yes/no on every card',
            'Ngân sách, link, có/không trên mỗi thẻ',
          ),
          t(
            'Make fields of your own for a board: text, number, date, yes/no, one choice, link. Fields that come with a template are free to fill; values you saved stay readable without Pro.',
            'Tạo trường riêng cho bảng: chữ, số, ngày, có/không, một lựa chọn, link. Trường đi kèm mẫu thì điền miễn phí; giá trị đã lưu vẫn xem được khi không còn Pro.',
          ),
        ),
      ],
    ),
    (
      t('Look', 'Giao diện'),
      [
        ProPart(
          ProFeature.templates,
          t(
            '$proTemplateCount more templates',
            'Thêm $proTemplateCount mẫu bảng',
          ),
          t(
            'Thesis, sprints, trips, events and more',
            'Luận văn, sprint, chuyến đi, sự kiện…',
          ),
          t(
            'Each with its own columns, categories, covers and example cards. Open any of them to see its board for free; Pro unlocks it before its questions, so nothing you type is wasted.',
            'Mỗi mẫu có cột, nhóm, ảnh bìa và thẻ ví dụ riêng. Mở mẫu nào cũng xem bảng miễn phí; Pro mở khoá trước khi trả lời câu hỏi, nên không phí công điền.',
          ),
        ),
        ProPart(
          ProFeature.covers,
          t('Every cover', 'Mọi ảnh bìa'),
          t('The whole cover library', 'Toàn bộ thư viện bìa'),
          t(
            'Every cover in every family. Free keeps a good selection in each; tap a cover to see it on your card before deciding.',
            'Mọi ảnh bìa trong mọi họ. Bản miễn phí vẫn có đủ bìa đẹp ở mỗi họ; chạm một bìa để xem ngay trên thẻ trước khi quyết định.',
          ),
        ),
        ProPart(
          ProFeature.looks,
          t('$looksPro board looks', '$looksPro nền bảng'),
          t('Grounds for light and dark', 'Nền cho cả sáng và tối'),
          t(
            'Paper, sage, blueprint, blush and more, made for light and dark. Try each on your own board first.',
            'Giấy, xô thơm, bản vẽ, phấn hồng và hơn thế, làm cho cả sáng và tối. Thử ngay trên bảng của bạn trước.',
          ),
        ),
        ProPart(
          ProFeature.widgetStyles,
          t('$stylesPro widget styles', '$stylesPro kiểu widget'),
          t(
            'Home-screen widgets in your colours',
            'Widget màn hình chính theo màu bạn chọn',
          ),
          t(
            'Linen, meadow, terracotta, harbour and more for every Boards widget, each easy to read. Preview them on your own widgets first.',
            'Vải lanh, đồng cỏ, gạch nung, bến cảng và hơn thế cho mọi widget, chữ luôn dễ đọc. Xem trước trên widget của bạn.',
          ),
        ),
      ],
    ),
    (
      t('Share and look back', 'Xuất và xem lại'),
      [
        ProPart(
          ProFeature.export,
          t('Designed exports and report', 'Bản xuất đẹp và báo cáo'),
          t(
            'Poster, printable, progress report',
            'Poster, bản in, báo cáo tiến độ',
          ),
          t(
            'Your board as a picture or PDF in poster and printable styles, or a report: open and done, eight weeks of finished cards, progress by category. Plain export and backups stay free.',
            'Bảng thành ảnh hoặc PDF kiểu poster và bản in, hoặc báo cáo: đang mở và đã xong, số thẻ xong 8 tuần, tiến độ theo nhóm. Xuất thường và sao lưu vẫn miễn phí.',
          ),
        ),
        ProPart(
          ProFeature.insights,
          t('Board insights', 'Thống kê bảng'),
          t('Done and late, by category', 'Xong và trễ theo từng nhóm'),
          t(
            'Per category: done, late and finished this week, counted from your own cards on this device.',
            'Theo từng nhóm: đã xong, trễ và xong trong tuần, đếm từ chính thẻ của bạn trên máy.',
          ),
        ),
        ProPart(
          ProFeature.history,
          t('Board history', 'Lịch sử bảng'),
          t('What happened, day by day', 'Chuyện gì đã xảy ra, theo từng ngày'),
          t(
            'Cards made, moved, finished, dates and categories changed, newest first. Read only.',
            'Thẻ được tạo, chuyển cột, xong, đổi ngày, đổi nhóm, mới nhất trước. Chỉ xem.',
          ),
        ),
      ],
    ),
  ];
}

/// Pro: a stage that plays the part that brought the person here, the
/// other parts by group (a tap plays one on the stage), Free beside Pro,
/// and one buy bar with the store's own price.
class ProPage extends StatefulWidget {
  final ProFeature? focus;
  const ProPage({super.key, this.focus});
  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> {
  final _scroll = ScrollController();
  late ProFeature _shown = widget.focus ?? ProFeature.templates;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _show(ProFeature f) {
    setState(() => _shown = f);
    if (!_scroll.hasClients) return;
    final d = HandyMotion.of(context, HandyMotion.long);
    // With less motion the page jumps; a zero-length animation asserts.
    if (d == Duration.zero) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(0, duration: d, curve: HandyMotion.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final groups = proGroups(context);
    final part = [
      for (final g in groups) ...g.$2,
    ].firstWhere((x) => x.feature == _shown);
    // The stage keeps the drawing's 16:9 up to the column's 720 px.
    final width = MediaQuery.sizeOf(context).width.clamp(0.0, 720.0) - 32;
    // A short (landscape) screen keeps room for the words under it.
    final tall = MediaQuery.sizeOf(context).height * .42;
    final stageHeight = (width * 9 / 16).clamp(150.0, tall.clamp(150.0, 340.0));
    Widget column(List<Widget> children) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Handy Boards Pro')),
      bottomNavigationBar: ProPurchase(
        store: LifetimeScope.maybeOf(context),
        canContinue: widget.focus != null,
      ),
      body: ListView(
        key: const Key('pro-page'),
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          column([
            if (widget.focus == null) ...[
              Semantics(
                header: true,
                child: Text(
                  tr(context, 'Pay once. Keep it.', 'Trả một lần. Dùng mãi.'),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  context,
                  'No subscription, no ads, no account. Your boards stay on your device either way.',
                  'Không thuê bao, không quảng cáo, không tài khoản. Bảng của bạn luôn ở trên máy.',
                ),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
            ],
            Container(
              key: const Key('pro-stage'),
              height: stageHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: p.sunk,
                borderRadius: BorderRadius.circular(BoardsRadii.tile),
              ),
              child: HandyDemoLoop(
                key: ValueKey(_shown),
                label: boardsProDemoLabel(context, _shown),
                replayLabel: tr(context, 'Play again', 'Xem lại'),
                builder: (context, t) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: boardsProDemo(context, _shown, t),
                ),
              ),
            ),
            const SizedBox(height: 14),
            HandySwap(
              child: Column(
                key: ValueKey(_shown),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      part.title,
                      key: const Key('pro-stage-title'),
                      style: widget.focus == null
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(part.body, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
            for (final g in groups) ...[
              const SizedBox(height: 28),
              Semantics(
                header: true,
                child: Text(g.$1, style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 6),
              for (final x in g.$2)
                _PartRow(
                  part: x,
                  shown: x.feature == _shown,
                  onTap: () => _show(x.feature),
                ),
            ],
            const SizedBox(height: 28),
            const _FreeAndPro(),
            const SizedBox(height: 20),
            Text(
              tr(
                context,
                'Always free: boards, cards, categories, subtasks, drag and drop, due dates, reminders, the week bar, search, backup and plain export. If Pro ever goes away, nothing you made is deleted; Pro looks fall back to the defaults and come back with Pro.',
                'Luôn miễn phí: bảng, thẻ, nhóm, việc con, kéo thả, hạn, lời nhắc, thanh tuần, tìm kiếm, sao lưu và xuất thường. Nếu không còn Pro, không gì bạn đã tạo bị xoá; kiểu Pro tạm về mặc định và trở lại khi có Pro.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
            ),
          ]),
        ],
      ),
    );
  }
}

/// One part in the list: its still frame, name and one line. A tap plays
/// it on the stage.
class _PartRow extends StatelessWidget {
  final ProPart part;
  final bool shown;
  final VoidCallback onTap;
  const _PartRow({
    required this.part,
    required this.shown,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    return Semantics(
      button: true,
      selected: shown,
      label: tr(
        context,
        '${part.title}. ${part.line}. Play it above',
        '${part.title}. ${part.line}. Xem diễn ở trên',
      ),
      excludeSemantics: true,
      child: InkWell(
        key: Key('pro-part-${part.feature.name}'),
        borderRadius: BorderRadius.circular(BoardsRadii.control),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 88,
                height: 50,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: p.sunk,
                  borderRadius: BorderRadius.circular(BoardsRadii.control),
                  border: Border.all(
                    color: shown ? p.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: boardsProDemo(context, part.feature, 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(part.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      part.line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                shown ? Icons.play_circle : Icons.play_circle_outline,
                color: shown ? p.primary : p.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Free beside Pro, each counted from the app's own catalogues.
class _FreeAndPro extends StatelessWidget {
  const _FreeAndPro();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    String t(String en, String vi) => tr(context, en, vi);
    final coversFree = coverCatalog.where((c) => !c.pro).length;
    final looksFree = boardLooks.where((l) => !l.pro).length;
    final stylesFree = widgetStyles.where((w) => !w.pro).length;
    final stylesPro = widgetStyles.length - stylesFree;
    final rows = [
      (
        t('Boards, cards, categories, subtasks', 'Bảng, thẻ, nhóm, việc con'),
        t('No limits', 'Không giới hạn'),
        t('No limits', 'Không giới hạn'),
      ),
      (
        t('Board templates', 'Mẫu bảng'),
        t(
          '$freeTemplateCount and a blank board',
          '$freeTemplateCount mẫu và bảng trống',
        ),
        t(
          'All ${freeTemplateCount + proTemplateCount}',
          'Cả ${freeTemplateCount + proTemplateCount} mẫu',
        ),
      ),
      (
        t('Covers', 'Ảnh bìa'),
        t('$coversFree', '$coversFree bìa'),
        t('All ${coverCatalog.length}', 'Cả ${coverCatalog.length} bìa'),
      ),
      (
        t('Board looks', 'Nền bảng'),
        t('$looksFree', '$looksFree nền'),
        t('All ${boardLooks.length}', 'Cả ${boardLooks.length} nền'),
      ),
      (
        t('Home-screen widgets', 'Widget màn hình chính'),
        t('All widgets, $stylesFree styles', 'Mọi widget, $stylesFree kiểu'),
        t('$stylesPro more styles', 'Thêm $stylesPro kiểu'),
      ),
      (
        t('Notifications', 'Thông báo'),
        t('Card reminders, Today\'s work', 'Nhắc thẻ, Việc hôm nay'),
        t('Board digest, Monday review', 'Tóm tắt các bảng, xem lại thứ Hai'),
      ),
      (
        t('Planning', 'Lên kế hoạch'),
        t(
          'Week bar, move to today by hand',
          'Thanh tuần, tự tay chuyển về hôm nay',
        ),
        t(
          'My Work, carry-over, repeating cards',
          'Việc của tôi, tự chuyển việc tồn, thẻ lặp lại',
        ),
      ),
      (
        t('Automation', 'Tự động'),
        '—',
        t(
          'Rules, saved filters, card templates, custom fields',
          'Luật, bộ lọc đã lưu, mẫu thẻ, trường tuỳ chỉnh',
        ),
      ),
      (
        t('Export', 'Xuất'),
        t('Plain picture, CSV, backups', 'Ảnh thường, CSV, sao lưu'),
        t('Poster, printable, report', 'Poster, bản in, báo cáo'),
      ),
      (
        t('Looking back', 'Xem lại'),
        '—',
        t('Insights, board history', 'Thống kê, lịch sử bảng'),
      ),
    ];
    Widget cell(String label, String value, {bool pro = false}) => Expanded(
      child: Semantics(
        label: label,
        child: Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: pro ? FontWeight.w600 : null,
          ),
        ),
      ),
    );
    Widget head(String s) => Expanded(
      child: Text(
        s,
        style: theme.textTheme.labelLarge?.copyWith(color: p.muted),
      ),
    );
    return Column(
      key: const Key('pro-free-and-pro'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            t('Free and Pro', 'Miễn phí và Pro'),
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Row(
            children: [
              head(t('Free', 'Miễn phí')),
              const SizedBox(width: 12),
              head('Pro'),
            ],
          ),
        ),
        for (final r in rows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: p.line)),
            ),
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.$1, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cell(t('Free', 'Miễn phí'), r.$2),
                      const SizedBox(width: 12),
                      cell('Pro', r.$3, pro: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
