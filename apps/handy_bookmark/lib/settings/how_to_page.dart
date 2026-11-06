import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import 'settings_parts.dart';

/// One part of the how-to: a name, its icon and the steps in order.
typedef _Part = ({String id, IconData icon, String title, List<String> steps});

List<_Part> _parts(BuildContext context) => [
  (
    id: 'save',
    icon: Icons.add_link_rounded,
    title: tr(context, 'Save', 'Lưu'),
    steps: [
      tr(
        context,
        'Paste a link into the field at the top of Home and press Save. Undo in the message takes it back.',
        'Dán link vào ô trên cùng của Trang chủ rồi bấm Lưu. Bấm Hoàn tác trong thông báo để bỏ lại.',
      ),
      tr(
        context,
        'From another app on your phone: Share, then Handy Bookmark. It lands in Not sorted.',
        'Từ app khác trên điện thoại: bấm Chia sẻ, chọn Handy Bookmark. Mục mới nằm ở Chưa sắp xếp.',
      ),
      tr(
        context,
        'The + beside the field saves a picture or several links at once.',
        'Nút + cạnh ô nhập để lưu một ảnh hoặc nhiều link một lúc.',
      ),
      tr(
        context,
        'Saving the same link twice shows the one you already have instead of a copy.',
        'Lưu lại một link đã có thì app mở mục cũ, không tạo bản trùng.',
      ),
      tr(
        context,
        'On a computer: Ctrl+V saves what you copied, Ctrl+N opens more ways to save.',
        'Trên máy tính: Ctrl+V lưu thứ vừa chép, Ctrl+N mở thêm cách lưu.',
      ),
    ],
  ),
  (
    id: 'organize',
    icon: Icons.folder_outlined,
    title: tr(context, 'Organize', 'Sắp xếp'),
    steps: [
      tr(
        context,
        'New saves wait in Not sorted. Put each one into a collection from Recently saved on Home.',
        'Mục mới chờ ở Chưa sắp xếp. Cho từng mục vào bộ sưu tập ngay ở phần Mới lưu trên Trang chủ.',
      ),
      tr(
        context,
        'Make a collection with the folder button beside Collections. Press and hold a collection to rename it.',
        'Tạo bộ sưu tập bằng nút thư mục cạnh Bộ sưu tập. Nhấn giữ một bộ sưu tập để đổi tên.',
      ),
      tr(
        context,
        'Open an item to add tags and a note, or to move it.',
        'Mở một mục để thêm thẻ, ghi chú hoặc chuyển chỗ.',
      ),
      tr(
        context,
        'Press and hold an item to select several, then move, tag or delete them together.',
        'Nhấn giữ một mục để chọn nhiều, rồi chuyển, gắn thẻ hoặc xóa cùng lúc.',
      ),
    ],
  ),
  (
    id: 'find',
    icon: Icons.search_rounded,
    title: tr(context, 'Find', 'Tìm lại'),
    steps: [
      tr(
        context,
        'The search button at the top of Home opens Search. Type a word from the title, the site, a tag or a note.',
        'Nút tìm ở đầu Trang chủ mở trang Tìm. Gõ một từ trong tiêu đề, tên trang, thẻ hoặc ghi chú.',
      ),
      tr(
        context,
        'Show only links or only pictures with the chips under the field.',
        'Lọc chỉ link hoặc chỉ ảnh bằng các nút dưới ô tìm.',
      ),
      tr(
        context,
        'On a computer, Ctrl+F jumps to search.',
        'Trên máy tính, Ctrl+F để tìm nhanh.',
      ),
    ],
  ),
  (
    id: 'read',
    icon: Icons.chrome_reader_mode_outlined,
    title: tr(context, 'Read', 'Đọc'),
    steps: [
      tr(
        context,
        'Open an article in the Reader for clean text. Save offline keeps a copy that opens without the internet.',
        'Mở bài viết trong trình đọc để xem chữ gọn gàng. Lưu offline giữ một bản đọc được khi không có mạng.',
      ),
      tr(
        context,
        'Focus shows what you have not opened yet, one at a time: swipe right when done, left for later.',
        'Tập trung cho xem từng mục chưa mở: vuốt phải khi xong, vuốt trái để để sau.',
      ),
      tr(
        context,
        'A weekly nudge can remind you when new saves wait. Turn it on in Settings › Reminders.',
        'Có thể bật nhắc mỗi tuần khi có mục mới chưa xem, trong Cài đặt › Nhắc nhở.',
      ),
    ],
  ),
  (
    id: 'safe',
    icon: Icons.shield_outlined,
    title: tr(context, 'Keep it safe', 'Giữ an toàn'),
    steps: [
      tr(
        context,
        'Everything stays on this device. There is no account.',
        'Mọi thứ nằm trên máy này. Không cần tài khoản.',
      ),
      tr(
        context,
        'Settings › Backup & restore › Back up makes one file with every item, picture and offline copy. Keep it somewhere else.',
        'Cài đặt › Sao lưu & khôi phục › Sao lưu tạo một file chứa mọi mục, ảnh và bản đọc offline. Hãy cất nó ở nơi khác.',
      ),
      tr(
        context,
        'Restore shows what a backup holds before anything changes.',
        'Khôi phục cho xem file sao lưu có gì trước khi thay đổi.',
      ),
      tr(
        context,
        'Deleted items wait 30 days in Recently deleted.',
        'Mục đã xóa chờ 30 ngày trong Đã xóa gần đây.',
      ),
      tr(
        context,
        'To use the same library on two computers, sync it through a folder your cloud app keeps in step (Settings › Cloud sync).',
        'Muốn dùng chung thư viện trên hai máy tính, đồng bộ qua một thư mục do app đám mây giữ đồng bộ (Cài đặt › Đồng bộ đám mây).',
      ),
    ],
  ),
  (
    id: 'pro',
    icon: Icons.workspace_premium_outlined,
    title: tr(context, 'Pro', 'Pro'),
    steps: [
      tr(
        context,
        'One payment adds themes, collection layouts, Focus skins and designed exports.',
        'Trả một lần để có thêm giao diện, kiểu trình bày bộ sưu tập, kiểu Tập trung và bản xuất có thiết kế.',
      ),
      tr(
        context,
        'Also highlights in the Reader, search inside articles and pictures, and reading text from pictures on the device.',
        'Thêm đánh dấu trong trình đọc, tìm bên trong bài viết và ảnh, đọc chữ trong ảnh ngay trên máy.',
      ),
      tr(
        context,
        'Everything above stays free. Settings › Explore Pro shows each one on your own library.',
        'Mọi thứ ở trên vẫn miễn phí. Cài đặt › Khám phá Pro cho xem thử từng tính năng trên chính thư viện của bạn.',
      ),
    ],
  ),
];

/// Settings › How to use: the whole app read from top to bottom, in six
/// parts, with a row of links at the top that jumps to each part.
class HowToPage extends StatefulWidget {
  const HowToPage({super.key});
  @override
  State<HowToPage> createState() => _HowToPageState();
}

class _HowToPageState extends State<HowToPage> {
  final _keys = <String, GlobalKey>{};

  GlobalKey _key(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  void _jump(String id) {
    final target = _key(id).currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: HandyMotion.of(context, HandyMotion.long),
      curve: HandyMotion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final parts = _parts(context);
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final title = tr(context, 'How to use', 'Cách dùng');
    final wide = MediaQuery.sizeOf(context).width >= HandySpace.wide;
    // Built whole (not lazily) so a link at the top can reach any part.
    final children = <Widget>[
      if (wide)
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineSmall),
        ),
      const SizedBox(height: HandySpace.m),
      Wrap(
        key: const Key('howto-jumps'),
        spacing: HandySpace.s,
        runSpacing: HandySpace.s,
        children: [
          for (final part in parts)
            ActionChip(
              key: Key('howto-jump-${part.id}'),
              avatar: Icon(part.icon, size: 18),
              label: Text(part.title),
              onPressed: () => _jump(part.id),
            ),
        ],
      ),
      const SizedBox(height: HandySpace.l),
      for (final (i, part) in parts.indexed)
        SettingsGroup(
          key: _key(part.id),
          first: i == 0,
          title: part.title,
          children: [
            Material(
              key: Key('howto-${part.id}'),
              color: p.surface,
              borderRadius: BorderRadius.circular(BookmarkRadii.item),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: HandySpace.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (n, step) in part.steps.indexed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          HandySpace.l,
                          HandySpace.s,
                          HandySpace.l,
                          HandySpace.s,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExcludeSemantics(
                              child: Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: p.tint,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${n + 1}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: p.ink,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: HandySpace.l),
                            Expanded(
                              child: Text(
                                step,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      const SizedBox(height: HandySpace.xxl),
    ];
    return HandyPage(
      title: title,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: HandySpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final c in children) HandyContent(child: c)],
        ),
      ),
    );
  }
}
