import 'package:flutter/foundation.dart';
import 'package:handy_ui/kit.dart';
import '../bookmark/share_item.dart' show canShareText, shareTextNow;
import '../design/clipping.dart';
import '../design/theme.dart';
import 'how_to_mocks.dart';

/// One step of a topic: what to do, and (often) a picture of where.
class _Step {
  final String words;
  final Widget? picture;

  /// A button that does the step for real (opens the share sheet).
  final (String, Future<void> Function(BuildContext))? action;
  const _Step(this.words, {this.picture, this.action});
}

/// One topic of How to use.
class _Topic {
  final String id;
  final IconData icon;
  final String title, summary;
  final List<_Step> steps;
  const _Topic(this.id, this.icon, this.title, this.summary, this.steps);
}

bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool get _apple =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Opens the phone's share sheet with a sample link, so its list can be
/// set up right away.
Future<void> _openShareSheet(BuildContext context) async {
  if (!canShareText) {
    showHandyMessage(
      context,
      tr(
        context,
        'Sharing opens in the Android and iOS apps.',
        'Chia sẻ có trong app Android và iOS.',
      ),
    );
    return;
  }
  final box = context.findRenderObject() as RenderBox?;
  final at = box == null || !box.hasSize
      ? Rect.zero
      : box.localToGlobal(Offset.zero) & box.size;
  try {
    await shareTextNow('https://www.youtube.com/', at);
  } catch (_) {}
}

List<_Topic> _topics(BuildContext context) => [
  _Topic(
    'faster',
    Icons.bolt_rounded,
    tr(context, 'Save links faster', 'Lưu link nhanh hơn'),
    tr(
      context,
      'Put Handy Bookmark first in the share list, so saving from any app is one tap.',
      'Đưa Handy Bookmark lên đầu danh sách chia sẻ, để lưu từ app nào cũng chỉ một chạm.',
    ),
    [
      _Step(
        tr(context, 'Open the share menu', 'Mở khung chia sẻ'),
        action: (
          tr(context, 'Open the share menu', 'Mở khung chia sẻ'),
          _openShareSheet,
        ),
      ),
      if (_apple) ...[
        _Step(
          tr(
            context,
            'Swipe through the apps to the end and tap More',
            'Vuốt hàng app tới cuối rồi bấm Thêm',
          ),
          picture: const MockShareRow(),
        ),
        _Step(
          tr(
            context,
            'Tap Edit, then add Handy Bookmark to Favorites',
            'Bấm Sửa, rồi thêm Handy Bookmark vào Mục ưa thích',
          ),
          picture: const MockFavorites(),
        ),
      ] else ...[
        _Step(
          tr(
            context,
            'Swipe through the apps to find Handy Bookmark',
            'Vuốt hàng app để tìm Handy Bookmark',
          ),
          picture: const MockShareRow(),
        ),
        _Step(
          tr(
            context,
            'Press and hold it, then tap Pin',
            'Nhấn giữ nó rồi bấm Ghim',
          ),
          picture: const MockPin(),
        ),
      ],
      _Step(
        tr(
          context,
          'Next time: tap Share, choose Handy Bookmark, and you are done. Then pick a collection, or leave it in Not sorted.',
          'Lần sau: bấm Chia sẻ, chọn Handy Bookmark là xong. Rồi chọn bộ sưu tập, hoặc để ở Chưa xếp.',
        ),
        picture: const MockShareRow(first: true),
      ),
    ],
  ),
  _Topic(
    'home',
    Icons.add_link_rounded,
    tr(context, 'Save in the app', 'Lưu ngay trong app'),
    tr(
      context,
      'A link you copied, a picture, or several links at once.',
      'Link vừa chép, một ảnh, hoặc nhiều link một lúc.',
    ),
    [
      _Step(
        tr(
          context,
          'Paste a link into the field at the top of Home and tap Save. Undo in the message takes it back.',
          'Dán link vào ô trên cùng Trang chủ rồi bấm Lưu. Bấm Hoàn tác trong thông báo để bỏ lại.',
        ),
        picture: const MockQuickSave(),
      ),
      _Step(
        tr(
          context,
          'The + beside it saves a picture, or several links at once.',
          'Nút + bên cạnh để lưu ảnh, hoặc nhiều link một lúc.',
        ),
        picture: const MockQuickSave(ringPlus: true),
      ),
      if (!_android && !_apple)
        _Step(
          tr(
            context,
            'On a computer: Ctrl+V saves what you copied.',
            'Trên máy tính: Ctrl+V lưu thứ vừa chép.',
          ),
        ),
    ],
  ),
  _Topic(
    'move',
    Icons.move_to_inbox_outlined,
    tr(context, 'Bring links from another app', 'Chuyển link từ app khác'),
    tr(
      context,
      'Pocket, Raindrop, or your browser’s bookmarks.',
      'Pocket, Raindrop, hoặc dấu trang của trình duyệt.',
    ),
    [
      _Step(
        tr(
          context,
          'From Pocket or Raindrop: export from there, then Settings › Data › Import and export › Import from Pocket or Raindrop.',
          'Từ Pocket hoặc Raindrop: xuất file ở app đó, rồi Cài đặt › Dữ liệu › Nhập và xuất › Nhập từ Pocket hoặc Raindrop.',
        ),
        picture: MockRows(
          title: tr(context, 'From other apps', 'Từ app khác'),
          rows: [
            (
              Icons.move_to_inbox_outlined,
              tr(context, 'Import from Pocket', 'Nhập từ Pocket'),
            ),
            (
              Icons.move_to_inbox_outlined,
              tr(context, 'Import from Raindrop', 'Nhập từ Raindrop'),
            ),
          ],
        ),
      ),
      _Step(
        tr(
          context,
          'From a browser: export its bookmarks as an HTML file, then Settings › Data › Restore and pick that file.',
          'Từ trình duyệt: xuất dấu trang thành file HTML, rồi Cài đặt › Dữ liệu › Khôi phục và chọn file đó.',
        ),
      ),
      _Step(
        tr(
          context,
          'You see what the file holds before anything changes. Only what is new is added, and Undo takes it back.',
          'Bạn xem trước file có gì rồi mới thay đổi. Chỉ thêm mục mới, và Hoàn tác để bỏ lại.',
        ),
      ),
    ],
  ),
  _Topic(
    'organize',
    Icons.folder_outlined,
    tr(context, 'Put things in order', 'Sắp xếp gọn gàng'),
    tr(
      context,
      'Collections with their own icon and colour, tags and notes.',
      'Bộ sưu tập có biểu tượng và màu riêng, thẻ và ghi chú.',
    ),
    [
      _Step(
        tr(
          context,
          'New saves wait in Not sorted. Tap the folder on a row to put it in a collection.',
          'Mục mới chờ ở Chưa xếp. Bấm biểu tượng thư mục trên dòng để cho vào bộ sưu tập.',
        ),
        picture: const MockPutIn(),
      ),
      _Step(
        tr(
          context,
          'Make a collection from a ready start, then give it an icon and a colour.',
          'Tạo bộ sưu tập từ mẫu có sẵn, rồi chọn biểu tượng và màu.',
        ),
        picture: MockChips(
          title: tr(context, 'Start from', 'Bắt đầu từ'),
          chips: [
            (Icons.restaurant_outlined, tr(context, 'Recipes', 'Công thức')),
            (Icons.luggage_outlined, tr(context, 'Trips', 'Du lịch')),
            (Icons.shopping_bag_outlined, tr(context, 'To buy', 'Cần mua')),
          ],
        ),
      ),
      _Step(
        tr(
          context,
          'Open an item to add tags and a note right on its page.',
          'Mở một mục để thêm thẻ và ghi chú ngay trên trang của nó.',
        ),
        picture: MockChips(
          title: tr(context, 'Tags', 'Thẻ'),
          ringed: 1,
          chips: [
            (null, '#weekend'),
            (Icons.add, tr(context, 'Add tag', 'Thêm thẻ')),
          ],
        ),
      ),
      _Step(
        tr(
          context,
          'In a collection, tap … › New collection inside to keep smaller groups in it.',
          'Trong một bộ sưu tập, bấm … › Bộ sưu tập con mới để chia nhỏ bên trong.',
        ),
        picture: MockRows(
          rows: [
            (
              Icons.edit_outlined,
              tr(context, 'Edit collection', 'Sửa bộ sưu tập'),
            ),
            (
              Icons.create_new_folder_outlined,
              tr(context, 'New collection inside', 'Bộ sưu tập con mới'),
            ),
          ],
          ringed: 1,
        ),
      ),
      _Step(
        tr(
          context,
          'Pro: smart collections fill themselves by rules (a site, a tag, unread…), and Auto organize files new saves for you.',
          'Pro: bộ sưu tập thông minh tự gom theo quy tắc (một trang, một thẻ, chưa đọc…), và Tự sắp xếp tự cho mục mới vào đúng chỗ.',
        ),
      ),
    ],
  ),
  _Topic(
    'pictures',
    Icons.image_outlined,
    tr(context, 'Pictures and screenshots', 'Ảnh và ảnh chụp màn hình'),
    tr(
      context,
      'Keep a screenshot like a link, and copy the words in it.',
      'Giữ ảnh chụp màn hình như một link, và chép chữ trong ảnh.',
    ),
    [
      _Step(
        tr(
          context,
          'Tap + on Home › Save a picture, or share a screenshot to Handy Bookmark from your gallery.',
          'Bấm + ở Trang chủ › Lưu một ảnh, hoặc chia sẻ ảnh chụp màn hình từ thư viện ảnh sang Handy Bookmark.',
        ),
        picture: const MockQuickSave(ringPlus: true),
      ),
      _Step(
        tr(
          context,
          'Open it to see it whole. Pro: Copy text reads the words in it on this device.',
          'Mở ảnh để xem toàn bộ. Pro: Chép chữ đọc chữ trong ảnh ngay trên máy.',
        ),
      ),
    ],
  ),
  _Topic(
    'find',
    Icons.search_rounded,
    tr(context, 'Find it again', 'Tìm lại'),
    tr(
      context,
      'By a word, a tag, or where it is.',
      'Bằng một chữ, một thẻ, hoặc nơi nó nằm.',
    ),
    [
      _Step(
        tr(
          context,
          'Tap the search button at the top of Home and type a word from the title, site, tag or note.',
          'Bấm nút tìm ở đầu Trang chủ rồi gõ một chữ trong tiêu đề, tên trang, thẻ hoặc ghi chú.',
        ),
      ),
      _Step(
        tr(
          context,
          'Before typing, tap a figure or a tag to open it.',
          'Trước khi gõ, bấm một con số hoặc một thẻ để mở nó.',
        ),
        picture: MockChips(
          ringed: 0,
          chips: [(null, '#món-huế  2'), (null, '#cuối-tuần  1')],
        ),
      ),
      _Step(
        tr(
          context,
          'Show only links or only pictures with the chips under the field.',
          'Lọc chỉ link hoặc chỉ ảnh bằng các nút dưới ô tìm.',
        ),
        picture: MockChips(
          ringed: 2,
          chips: [
            (null, tr(context, 'All', 'Tất cả')),
            (null, 'Link'),
            (null, tr(context, 'Pictures', 'Ảnh')),
          ],
        ),
      ),
    ],
  ),
  _Topic(
    'read',
    Icons.chrome_reader_mode_outlined,
    tr(context, 'Read and look back', 'Đọc và xem lại'),
    tr(
      context,
      'Clean reading, offline copies, and Focus for what waits.',
      'Đọc gọn gàng, bản đọc offline, và Tập trung cho những gì đang chờ.',
    ),
    [
      _Step(
        tr(
          context,
          'Open an article and tap Read for clean text. Save offline keeps a copy for when there is no internet.',
          'Mở một bài viết và bấm Đọc để xem chữ gọn gàng. Lưu offline giữ một bản cho lúc không có mạng.',
        ),
      ),
      _Step(
        tr(
          context,
          'Focus shows what you have not opened, one at a time: right when done, left for later.',
          'Tập trung cho xem từng mục chưa mở: vuốt phải khi xong, vuốt trái để sau.',
        ),
        picture: const MockFocus(),
      ),
      _Step(
        tr(
          context,
          'Settings › General › Weekly nudge reminds you when new saves wait unread. It shows a count, never titles.',
          'Cài đặt › Chung › Nhắc mỗi tuần báo khi có mục mới chưa xem. Chỉ ghi số lượng, không ghi tiêu đề.',
        ),
      ),
    ],
  ),
  _Topic(
    'share',
    Icons.ios_share_rounded,
    tr(context, 'Share with others', 'Chia sẻ cho người khác'),
    tr(
      context,
      'One item, or a whole collection as a page.',
      'Một mục, hoặc cả bộ sưu tập thành một trang.',
    ),
    [
      _Step(
        tr(
          context,
          'Open an item and tap Share. The link goes without tracking bits (utm_, fbclid).',
          'Mở một mục và bấm Chia sẻ. Link được bỏ phần theo dõi (utm_, fbclid) trước khi gửi.',
        ),
      ),
      _Step(
        tr(
          context,
          'In a collection, tap … › Share as a page. Pro: Design an export makes a PDF or a web page in a chosen design.',
          'Trong một bộ sưu tập, bấm … › Chia sẻ thành trang. Pro: Thiết kế bản xuất tạo PDF hoặc trang web theo mẫu bạn chọn.',
        ),
        picture: MockRows(
          ringed: 0,
          rows: [
            (
              Icons.ios_share,
              tr(context, 'Share as a page', 'Chia sẻ thành trang'),
            ),
            (
              Icons.auto_awesome_outlined,
              tr(context, 'Design an export', 'Thiết kế bản xuất'),
            ),
          ],
        ),
      ),
    ],
  ),
  _Topic(
    'tidy',
    Icons.cleaning_services_outlined,
    tr(context, 'Tidy up', 'Dọn dẹp'),
    tr(
      context,
      'Duplicates, links that stopped working, and taking back a delete.',
      'Mục trùng, link không còn mở được, và lấy lại thứ đã xóa.',
    ),
    [
      _Step(
        tr(
          context,
          'Settings › Data › Library tools finds duplicates to merge, and checks every link for ones that stopped working.',
          'Cài đặt › Dữ liệu › Công cụ thư viện tìm mục trùng để gộp, và kiểm tra mọi link xem cái nào không còn mở được.',
        ),
        picture: MockRows(
          title: tr(context, 'Data', 'Dữ liệu'),
          ringed: 1,
          rows: [
            (
              Icons.delete_outline,
              tr(context, 'Recently deleted', 'Đã xóa gần đây'),
            ),
            (
              Icons.handyman_outlined,
              tr(context, 'Library tools', 'Công cụ thư viện'),
            ),
          ],
        ),
      ),
      _Step(
        tr(
          context,
          'Deleted something? Undo in the message, or find it in Recently deleted for 30 days.',
          'Lỡ xóa? Bấm Hoàn tác trong thông báo, hoặc tìm trong Đã xóa gần đây trong 30 ngày.',
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
      'Everything stays on this device. Back it up, sync it, lock it.',
      'Mọi thứ nằm trên máy này. Sao lưu, đồng bộ, khóa lại.',
    ),
    [
      _Step(
        tr(
          context,
          'Settings › Data › Back up makes one file with everything. Keep it somewhere else; Restore shows what it holds first.',
          'Cài đặt › Dữ liệu › Sao lưu tạo một file chứa mọi thứ. Cất ở nơi khác; Khôi phục cho xem trước file có gì.',
        ),
        picture: MockRows(
          title: tr(context, 'Data', 'Dữ liệu'),
          ringed: 1,
          rows: [
            (Icons.sync, tr(context, 'Sync', 'Đồng bộ')),
            (Icons.backup_outlined, tr(context, 'Back up', 'Sao lưu')),
            (
              Icons.delete_outline,
              tr(context, 'Recently deleted', 'Đã xóa gần đây'),
            ),
          ],
        ),
      ),
      _Step(
        tr(
          context,
          'App lock asks for your fingerprint, face or screen lock when the app opens.',
          'Khóa app hỏi vân tay, khuôn mặt hoặc khóa màn hình khi mở app.',
        ),
        picture: MockRows(
          title: tr(context, 'Privacy', 'Riêng tư'),
          rows: [(Icons.lock_outline, tr(context, 'App lock', 'Khóa app'))],
        ),
      ),
      _Step(
        tr(
          context,
          'Back up automatically keeps a copy each day something changed, the last 7 on this device.',
          'Tự sao lưu giữ một bản mỗi ngày có thay đổi, 7 bản gần nhất trên máy này.',
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
      'One payment adds more; everything above stays free.',
      'Trả một lần để có thêm; mọi thứ ở trên vẫn miễn phí.',
    ),
    [
      _Step(
        tr(
          context,
          'Themes, collection layouts and Focus skins.',
          'Chủ đề màu, kiểu trình bày bộ sưu tập và kiểu Tập trung.',
        ),
      ),
      _Step(
        tr(
          context,
          'Highlights and notes in the Reader; search inside articles, highlights and pictures.',
          'Đánh dấu và ghi chú trong trình đọc; tìm cả bên trong bài viết, đoạn đánh dấu và ảnh.',
        ),
      ),
      _Step(
        tr(
          context,
          'Copy text from pictures, Auto organize, smart collections, and designed exports.',
          'Chép chữ trong ảnh, Tự sắp xếp, bộ sưu tập thông minh, và bản xuất có thiết kế.',
        ),
      ),
      _Step(
        tr(
          context,
          'Settings › Upgrade to Pro shows each on your own library before you pay. Restore a purchase there too.',
          'Cài đặt › Nâng cấp Pro cho xem thử từng thứ trên chính thư viện của bạn trước khi trả. Khôi phục giao dịch cũng ở đó.',
        ),
      ),
    ],
  ),
];

/// Settings › Help › How to use: the welcome again, then short topics.
/// Each topic opens as a sheet of numbered steps with a picture of where.
/// Reading it changes nothing.
class HowToPage extends StatelessWidget {
  const HowToPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final topics = _topics(context);
    return HandyPage(
      title: tr(context, 'How to use', 'Cách dùng'),
      children: [
        const SizedBox(height: HandySpace.m),
        // The first way in: the welcome again, on a large soft card.
        Material(
          color: p.tint,
          borderRadius: BorderRadius.circular(BookmarkRadii.item),
          child: InkWell(
            key: const Key('howto-replay'),
            borderRadius: BorderRadius.circular(BookmarkRadii.item),
            onTap: () => Navigator.pushNamed(context, '/welcome'),
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
                          style: bookmarkSerif(context, 22),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(
                            context,
                            'Save a video for practice and find it again. Nothing is kept.',
                            'Lưu thử một video rồi tìm lại. Không lưu gì thật.',
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
                color: p.surface,
                borderRadius: BorderRadius.circular(12),
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
    final p = BookmarkPalette.of(context);
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
                child: Text(t.title, style: SheetTitle.style(context)),
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
                  // A step in tone from the sheet, as the app's grounds are.
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(18),
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
                      if (step.action case (final label, final run)) ...[
                        const SizedBox(height: HandySpace.m),
                        Builder(
                          builder: (context) => FilledButton.icon(
                            key: Key('howto-action-$i'),
                            style: sheetButtonStyle(context),
                            onPressed: () => run(context),
                            icon: const Icon(Icons.ios_share_rounded),
                            label: Text(label),
                          ),
                        ),
                      ],
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
                style: sheetButtonStyle(context),
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
