import 'package:flutter/foundation.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import 'how_to_mocks.dart';

/// One step of a topic: what to do, and (often) a picture of where.
class _Step {
  final String words;
  final Widget? picture;
  const _Step(this.words, {this.picture});
}

/// One topic of How to use.
class _Topic {
  final String id;
  final IconData icon;
  final String title, summary;
  final List<_Step> steps;
  const _Topic(this.id, this.icon, this.title, this.summary, this.steps);
}

/// Keyboard shortcuts are told only where there is a keyboard.
bool get _computer =>
    kIsWeb ||
    !(defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

List<_Topic> _topics(BuildContext context) => [
  _Topic(
    'start',
    Icons.dashboard_customize_outlined,
    tr(context, 'Start a board', 'Bắt đầu một bảng'),
    tr(
      context,
      'Blank with three columns, or a ready template you can preview.',
      'Bảng trống ba cột, hoặc một mẫu có sẵn xem trước được.',
    ),
    [
      _Step(
        tr(
          context,
          'On Your boards, tap New board: a template, or a blank board with To Do, Doing and Done.',
          'Ở Bảng của bạn, bấm Bảng mới: chọn một mẫu, hoặc bảng trống với Cần làm, Đang làm, Xong.',
        ),
        picture: MockChips(
          ringed: 0,
          chips: [
            (Icons.add, tr(context, 'New board', 'Bảng mới')),
            (
              Icons.grid_view_outlined,
              tr(context, 'Explore templates', 'Xem các mẫu'),
            ),
          ],
        ),
      ),
      _Step(
        tr(
          context,
          'Each of the 30 templates shows its board first. Use this template asks two or three questions (name, subjects or work areas, a key date), then shows exactly the board you will get. Example cards are off unless you turn them on.',
          'Mỗi mẫu trong 30 mẫu đều cho xem bảng trước. Dùng mẫu này hỏi hai ba câu (tên, môn học hay mảng việc, một ngày quan trọng), rồi cho xem đúng bảng sẽ tạo. Thẻ ví dụ tắt sẵn, chỉ thêm khi bạn bật.',
        ),
      ),
      _Step(
        tr(
          context,
          'Each board keeps its own colour from its cover. Pin the ones you use most so they stay on top.',
          'Mỗi bảng có màu riêng theo ảnh bìa. Ghim những bảng dùng nhiều để chúng luôn ở trên cùng.',
        ),
        picture: const MockCovers(),
      ),
    ],
  ),
  _Topic(
    'cards',
    Icons.view_week_outlined,
    tr(context, 'Add and move cards', 'Thêm và chuyển thẻ'),
    tr(
      context,
      'A card is one piece of work; its column says how far along it is.',
      'Mỗi thẻ là một việc; cột cho biết việc đó tới đâu rồi.',
    ),
    [
      _Step(
        tr(
          context,
          'Tap Add card at the foot of a column, type, and press Enter to add the next one.',
          'Bấm Thêm thẻ ở chân một cột, gõ tên, nhấn Enter để thêm tiếp thẻ sau.',
        ),
        picture: const MockColumns(ringAdd: true),
      ),
      _Step(
        tr(
          context,
          'Press and hold a card, then drag it to another column or place. With a mouse, just drag. Undo in the message takes it back.',
          'Nhấn giữ một thẻ rồi kéo sang cột hoặc chỗ khác. Dùng chuột thì kéo luôn. Bấm Hoàn tác trong thông báo để trả lại.',
        ),
        picture: const MockColumns(drag: true),
      ),
      _Step(
        tr(
          context,
          'No drag needed: open the card and tap … › Move to…. On a phone, swipe sideways to see the next column.',
          'Không muốn kéo: mở thẻ rồi bấm … › Chuyển tới…. Trên điện thoại, vuốt ngang để sang cột kế.',
        ),
        picture: MockRows(
          title: tr(context, 'Card options', 'Tuỳ chọn thẻ'),
          rows: [
            (
              Icons.drive_file_move_outline,
              tr(context, 'Move to…', 'Chuyển tới…'),
            ),
            (Icons.copy_outlined, tr(context, 'Duplicate', 'Nhân bản')),
            (
              Icons.archive_outlined,
              tr(context, 'Archive card', 'Lưu trữ thẻ'),
            ),
          ],
        ),
      ),
      _Step(
        tr(
          context,
          'Columns are yours: … on a column renames it, marks it as the finished one, or deletes it. Add column sits after the last one.',
          'Cột là của bạn: … trên cột để đổi tên, đánh dấu là cột "đã xong", hoặc xoá. Thêm cột nằm sau cột cuối.',
        ),
      ),
    ],
  ),
  _Topic(
    'categories',
    Icons.donut_large_outlined,
    tr(context, 'Categories', 'Nhóm'),
    tr(
      context,
      'Subjects, rooms or people. A card keeps its category in every column.',
      'Môn học, phòng hay người. Thẻ giữ nhóm của nó ở mọi cột.',
    ),
    [
      _Step(
        tr(
          context,
          'The strip above the board shows each category with done/total, so you see where you stand at a glance.',
          'Dải phía trên bảng cho mỗi nhóm kèm số xong/tổng, nhìn là biết đang tới đâu.',
        ),
        picture: const MockStrip(),
      ),
      _Step(
        tr(
          context,
          'Tap a category to bring its cards forward: they get a ring, the others stay on the board. Only this one hides the rest; the cross clears it.',
          'Bấm một nhóm để làm nổi thẻ của nhóm: thẻ có viền, thẻ khác vẫn ở trên bảng. Chỉ hiện nhóm này mới ẩn phần còn lại; dấu X để bỏ chọn.',
        ),
        picture: const MockStrip(ringed: 0),
      ),
      _Step(
        tr(
          context,
          'Edit on the strip adds, renames, recolours and reorders them. Deleting one moves its cards to Uncategorised or another category.',
          'Sửa trên dải để thêm, đổi tên, đổi màu và sắp lại. Xoá một nhóm thì thẻ của nó chuyển sang Chưa phân nhóm hoặc nhóm khác.',
        ),
      ),
    ],
  ),
  _Topic(
    'details',
    Icons.checklist_rounded,
    tr(context, 'Subtasks and details', 'Việc con và chi tiết'),
    tr(
      context,
      'Break a card into steps; add a due day, a reminder and notes.',
      'Chia thẻ thành từng bước; thêm hạn, nhắc và ghi chú.',
    ),
    [
      _Step(
        tr(
          context,
          'Tap a card to open it. Under Subtasks, Add a subtask; tick each one as you go. Ticking never moves the card.',
          'Bấm một thẻ để mở. Ở Việc con, bấm Thêm việc con; làm xong bước nào tích bước đó. Tích không làm thẻ đổi cột.',
        ),
        picture: const MockCardDetail(),
      ),
      _Step(
        tr(
          context,
          'Due date and Reminder are chips at the top. Notifications are asked for the first time you set a reminder.',
          'Hạn và Nhắc là các nút ở đầu thẻ. Quyền thông báo chỉ được hỏi lần đầu bạn đặt nhắc.',
        ),
        picture: const MockCardDetail(ring: 'due'),
      ),
      _Step(
        tr(
          context,
          'Notes keep links: they show as chips you can open. Every change saves itself, with Undo.',
          'Ghi chú giữ được link: link hiện thành nút mở được. Mọi thay đổi tự lưu, có Hoàn tác.',
        ),
      ),
    ],
  ),
  _Topic(
    'time',
    Icons.view_timeline_outlined,
    tr(context, 'Plan by the week', 'Lên kế hoạch theo tuần'),
    tr(
      context,
      'What is planned, due or finished in a week, and the day you mean to do each card.',
      'Việc định làm, đến hạn hay đã xong trong một tuần, và ngày bạn định làm từng thẻ.',
    ),
    [
      _Step(
        tr(
          context,
          'When cards have dates, a bar above the board shows this week. ‹ and › go a week back or on; This week comes back; All shows every card. Columns stay your progress.',
          'Khi thẻ có ngày, thanh phía trên bảng cho thấy tuần này. ‹ và › lùi hay tới một tuần; Tuần này để quay về; Tất cả để xem mọi thẻ. Cột vẫn là tiến độ.',
        ),
      ),
      _Step(
        tr(
          context,
          'The calendar button sets how much the bar shows: a day, a week, 2 weeks, a month, 3 months, or your own dates.',
          'Nút lịch đặt thanh xem bao xa: một ngày, một tuần, 2 tuần, một tháng, 3 tháng, hay khoảng ngày tự chọn.',
        ),
      ),
      _Step(
        tr(
          context,
          'Card ⋯ › Do it today, or Plan a day…, sets the day you mean to work on it. Its due date never changes by itself. Work left over from before shows above the board with Move to today.',
          '⋯ trên thẻ › Làm hôm nay, hoặc Lên lịch…, đặt ngày bạn định làm. Hạn nộp không bao giờ tự đổi. Việc chưa xong từ trước hiện phía trên bảng, kèm nút Về hôm nay.',
        ),
      ),
    ],
  ),
  _Topic(
    'look',
    Icons.palette_outlined,
    tr(context, 'Covers and looks', 'Ảnh bìa và giao diện'),
    tr(
      context,
      'A cover for a board or a card, and a look for the whole board.',
      'Ảnh bìa cho bảng hay thẻ, và giao diện cho cả bảng.',
    ),
    [
      _Step(
        tr(
          context,
          'On a board, tap … › Change cover. Pick a drawn cover, a colour, or your own photo; you see it before you apply.',
          'Trong bảng, bấm … › Đổi ảnh bìa. Chọn bìa vẽ sẵn, một màu, hoặc ảnh của bạn; xem trước rồi mới áp dụng.',
        ),
        picture: MockRows(
          title: tr(context, 'Board options', 'Tuỳ chọn bảng'),
          rows: [
            (Icons.image_outlined, tr(context, 'Change cover', 'Đổi ảnh bìa')),
            (
              Icons.format_paint_outlined,
              tr(context, 'Board look', 'Giao diện bảng'),
            ),
            (Icons.ios_share, tr(context, 'Export board', 'Xuất bảng')),
          ],
        ),
      ),
      _Step(
        tr(
          context,
          'A card gets a cover the same way, from Cover in the card.',
          'Thẻ cũng có ảnh bìa theo cách đó, ở mục Ảnh bìa trong thẻ.',
        ),
        picture: const MockCardDetail(ring: 'cover'),
      ),
      _Step(
        tr(
          context,
          'Board look changes the page and column grounds: Pinboard is free; Linen, Blueprint, Meadow, Blush and Sand come with Pro.',
          'Giao diện bảng đổi nền trang và nền cột: Pinboard miễn phí; Linen, Blueprint, Meadow, Blush và Sand có trong Pro.',
        ),
      ),
    ],
  ),
  _Topic(
    'repeat',
    Icons.repeat_rounded,
    tr(context, 'Repeat and automate', 'Lặp lại và tự động'),
    tr(
      context,
      'Pro: cards that come back, and the board tidying itself.',
      'Pro: thẻ tự quay lại, và bảng tự dọn.',
    ),
    [
      _Step(
        tr(
          context,
          'In a card, Repeat: every day, week or month. When it reaches the finished column, the next one appears at the top of the first column, subtasks unticked.',
          'Trong thẻ, Lặp lại: hằng ngày, tuần hay tháng. Khi thẻ vào cột đã xong, thẻ kế tiếp hiện ở đầu cột đầu tiên, việc con chưa tích.',
        ),
        picture: const MockColumns(ringDone: true),
      ),
      _Step(
        tr(
          context,
          'Settings › Automations: finish a card when all its subtasks are done, and archive finished cards after 14 days. Archived cards come back from Settings › Data.',
          'Cài đặt › Tự động hoá: chuyển thẻ sang cột xong khi đủ việc con, và lưu trữ thẻ đã xong sau 14 ngày. Thẻ đã lưu trữ lấy lại ở Cài đặt › Dữ liệu.',
        ),
      ),
    ],
  ),
  _Topic(
    'find',
    Icons.search_rounded,
    tr(context, 'Find a card', 'Tìm một thẻ'),
    tr(
      context,
      'In one board, or in every board.',
      'Trong một bảng, hoặc trong mọi bảng.',
    ),
    [
      _Step(
        tr(
          context,
          'On a board, Search cards matches titles and notes; Due in 3 days shows what is close.',
          'Trong bảng, Tìm thẻ khớp tên và ghi chú; Hạn trong 3 ngày cho thấy việc sắp tới.',
        ),
        picture: MockChips(
          ringed: 1,
          chips: [
            (Icons.search, tr(context, 'Search cards', 'Tìm thẻ')),
            (
              Icons.event_outlined,
              tr(context, 'Due in 3 days', 'Hạn trong 3 ngày'),
            ),
          ],
        ),
      ),
      _Step(
        tr(
          context,
          'On Your boards, the search button looks through every board at once.',
          'Ở Bảng của bạn, nút tìm sẽ tìm trong mọi bảng cùng lúc.',
        ),
      ),
    ],
  ),
  _Topic(
    'share',
    Icons.ios_share_rounded,
    tr(context, 'Export and share', 'Xuất và chia sẻ'),
    tr(
      context,
      'A picture or PDF of a board, or its cards as a file.',
      'Ảnh hoặc PDF của bảng, hoặc các thẻ thành một tệp.',
    ),
    [
      _Step(
        tr(
          context,
          'On a board, tap … › Export board. You see the board as it will be saved: Plain is free; Poster and Printable come with Pro. Save it as PNG or PDF.',
          'Trong bảng, bấm … › Xuất bảng. Bạn thấy đúng bảng sẽ được lưu: Đơn giản miễn phí; Poster và Bản in có trong Pro. Lưu thành PNG hoặc PDF.',
        ),
        picture: MockChips(
          ringed: 0,
          chips: [
            (null, tr(context, 'Plain', 'Đơn giản')),
            (null, 'Poster'),
            (null, tr(context, 'Printable', 'Bản in')),
          ],
        ),
      ),
      _Step(
        tr(
          context,
          'The same page offers CSV, Markdown and a calendar file (ICS) of the cards, free.',
          'Cùng trang đó có CSV, Markdown và tệp lịch (ICS) của các thẻ, miễn phí.',
        ),
      ),
      _Step(
        tr(
          context,
          'Share text from another app to Handy Boards: it becomes a card in the first column of your top board, with Undo.',
          'Chia sẻ chữ từ app khác sang Handy Boards: chữ thành một thẻ ở cột đầu của bảng trên cùng, có Hoàn tác.',
        ),
      ),
    ],
  ),
  _Topic(
    'safe',
    Icons.shield_outlined,
    tr(context, 'Keep it safe', 'Giữ an toàn'),
    tr(
      context,
      'Everything stays on this device. Back it up, and take back a delete.',
      'Mọi thứ nằm trên máy này. Sao lưu, và lấy lại thứ đã xoá.',
    ),
    [
      _Step(
        tr(
          context,
          'Settings › Data › Back up makes one ZIP with every board, cover and photo. Keep it somewhere else; Restore shows what it holds first.',
          'Cài đặt › Dữ liệu › Sao lưu tạo một tệp ZIP chứa mọi bảng, ảnh bìa và ảnh. Cất ở nơi khác; Khôi phục cho xem trước tệp có gì.',
        ),
        picture: MockRows(
          title: tr(context, 'Data', 'Dữ liệu'),
          ringed: 0,
          rows: [
            (Icons.backup_outlined, tr(context, 'Back up', 'Sao lưu')),
            (Icons.update, tr(context, 'Back up automatically', 'Tự sao lưu')),
            (Icons.delete_outline, tr(context, 'Trash', 'Thùng rác')),
          ],
        ),
      ),
      _Step(
        tr(
          context,
          'Back up automatically keeps a copy each day something changed, the last 7 on this device.',
          'Tự sao lưu giữ một bản mỗi ngày có thay đổi, 7 bản gần nhất trên máy này.',
        ),
      ),
      _Step(
        tr(
          context,
          'Deleted a card? Undo in the message, or find it in Trash. Archived boards and cards wait in Settings › Data.',
          'Lỡ xoá thẻ? Bấm Hoàn tác trong thông báo, hoặc tìm trong Thùng rác. Bảng và thẻ đã lưu trữ nằm ở Cài đặt › Dữ liệu.',
        ),
      ),
    ],
  ),
  if (_computer)
    _Topic(
      'keys',
      Icons.keyboard_outlined,
      tr(context, 'Keyboard', 'Bàn phím'),
      tr(context, 'Faster on a computer.', 'Nhanh hơn trên máy tính.'),
      [
        _Step(tr(context, 'Ctrl+F: search cards.', 'Ctrl+F: tìm thẻ.')),
        _Step(
          tr(
            context,
            'Ctrl+Z undo, Ctrl+Y redo.',
            'Ctrl+Z hoàn tác, Ctrl+Y làm lại.',
          ),
        ),
        _Step(
          tr(
            context,
            'Alt+←/→ moves the focused card to the next column; Alt+↑/↓ moves it up or down.',
            'Alt+←/→ chuyển thẻ đang chọn sang cột bên cạnh; Alt+↑/↓ đưa lên hay xuống.',
          ),
        ),
        _Step(
          tr(
            context,
            'In Time, ← and → go to the previous or next span.',
            'Ở Thời gian, ← và → sang khoảng trước hoặc sau.',
          ),
        ),
      ],
    ),
  _Topic(
    'pro',
    Icons.workspace_premium_outlined,
    'Pro',
    tr(
      context,
      'One payment adds more; your boards stay free.',
      'Trả một lần để có thêm; bảng của bạn vẫn miễn phí.',
    ),
    [
      _Step(
        tr(
          context,
          'Five more templates, 30 more covers and five board looks.',
          'Thêm năm mẫu bảng, 30 ảnh bìa và năm giao diện bảng.',
        ),
      ),
      _Step(
        tr(
          context,
          'Repeating cards, automations, Poster and Printable exports, and Insights for each board.',
          'Thẻ lặp lại, tự động hoá, bản xuất Poster và Bản in, và Thống kê cho từng bảng.',
        ),
      ),
      _Step(
        tr(
          context,
          'Settings › Upgrade to Pro shows each before you pay. Restore a purchase there too.',
          'Cài đặt › Nâng cấp Pro cho xem thử từng thứ trước khi trả. Khôi phục giao dịch cũng ở đó.',
        ),
      ),
    ],
  ),
];

/// Settings › Help › How to use: the welcome again, then short topics.
/// Each topic opens as a sheet of numbered steps with a picture of where.
/// Reading it changes nothing.
class HowToPage extends StatelessWidget {
  final VoidCallback onReplayWelcome;
  const HowToPage({super.key, required this.onReplayWelcome});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final topics = _topics(context);
    return HandyPage(
      title: tr(context, 'How to use', 'Cách dùng'),
      children: [
        const SizedBox(height: HandySpace.m),
        // The first way in: the welcome again, on a large soft card.
        Material(
          color: p.tint,
          borderRadius: BorderRadius.circular(BoardsRadii.tile),
          child: InkWell(
            key: const Key('howto-replay'),
            borderRadius: BorderRadius.circular(BoardsRadii.tile),
            onTap: onReplayWelcome,
            child: Padding(
              padding: const EdgeInsets.all(HandySpace.l),
              child: Row(
                children: [
                  Icon(Icons.play_circle_outline, size: 36, color: p.ink),
                  const SizedBox(width: HandySpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(
                            context,
                            'Watch the welcome again',
                            'Xem lại phần giới thiệu',
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(
                            context,
                            'Practise on a sample board: add a card, move it, finish it. Nothing is kept.',
                            'Tập trên một bảng mẫu: thêm thẻ, chuyển thẻ, làm xong. Không lưu gì thật.',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: p.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: HandySpace.xl),
        Semantics(
          header: true,
          child: Text(
            tr(context, 'Topics', 'Chủ đề'),
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: HandySpace.s),
        for (final (i, t) in topics.indexed)
          ListTile(
            key: Key('howto-topic-${t.id}'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            minVerticalPadding: 10,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.raised,
                borderRadius: BorderRadius.circular(BoardsRadii.control),
              ),
              child: Icon(t.icon, color: p.ink),
            ),
            title: Text(
              t.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(t.summary),
            trailing: Icon(Icons.chevron_right, color: p.muted),
            onTap: () => showHowToTopic(context, i),
          ),
        const SizedBox(height: HandySpace.xl),
      ],
    );
  }
}

/// A topic as a sheet: numbered step cards, Previous and Next, and Done.
Future<void> showHowToTopic(BuildContext context, int start) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .92,
        minChildSize: .5,
        maxChildSize: .96,
        expand: false,
        builder: (_, scroll) => _TopicSheet(start: start, scroll: scroll),
      ),
    );

class _TopicSheet extends StatefulWidget {
  final int start;
  final ScrollController scroll;
  const _TopicSheet({required this.start, required this.scroll});
  @override
  State<_TopicSheet> createState() => _TopicSheetState();
}

class _TopicSheetState extends State<_TopicSheet> {
  late int _at = widget.start;

  void _go(int to) {
    if (widget.scroll.hasClients) widget.scroll.jumpTo(0);
    setState(() => _at = to);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final topics = _topics(context);
    final t = topics[_at];
    return Column(
      key: Key('howto-sheet-${t.id}'),
      children: [
        Expanded(
          child: ListView(
            controller: widget.scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            children: [
              Text(
                tr(
                  context,
                  'Topic ${_at + 1} of ${topics.length}',
                  'Chủ đề ${_at + 1}/${topics.length}',
                ),
                style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
              ),
              const SizedBox(height: 4),
              Semantics(
                header: true,
                child: Text(
                  t.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: HandySpace.s),
              Text(
                t.summary,
                style: theme.textTheme.bodyLarge?.copyWith(color: p.muted),
              ),
              const SizedBox(height: HandySpace.l),
              for (final (i, step) in t.steps.indexed)
                Container(
                  key: Key('howto-step-$i'),
                  margin: const EdgeInsets.only(bottom: HandySpace.m),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.canvas,
                    borderRadius: BorderRadius.circular(BoardsRadii.column),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(
                              '${i + 1}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: p.primary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                step.words,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (step.picture case final picture?) ...[
                        const SizedBox(height: HandySpace.m),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: picture,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Pinned at the foot, wherever the steps are scrolled.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _at > 0
                        ? TextButton.icon(
                            key: const Key('howto-previous'),
                            onPressed: () => _go(_at - 1),
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: Text(tr(context, 'Previous', 'Trước')),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: _at < topics.length - 1
                        ? TextButton.icon(
                            key: const Key('howto-next'),
                            onPressed: () => _go(_at + 1),
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: Text(tr(context, 'Next', 'Tiếp')),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: HandySpace.xs),
              FilledButton(
                key: const Key('howto-done'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(tr(context, 'Done', 'Xong')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
