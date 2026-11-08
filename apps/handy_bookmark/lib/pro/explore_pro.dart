import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart';
import '../design/looks.dart';
import '../design/theme.dart';
import '../platform/widget_styles.dart';
import '../scope.dart';
import 'entitlements.dart';
import 'focus_skins.dart';
import 'layouts.dart';
import 'pro_demos.dart';

/// What one Pro part is called and what it does, in a line and in full.
class ProPart {
  final ProFeature feature;
  final String title, line, body;
  const ProPart(this.feature, this.title, this.line, this.body);
}

/// Every Pro part that ships, in the groups the page lists them in.
List<(String, List<ProPart>)> proGroups(BuildContext context) {
  String t(String en, String vi) => tr(context, en, vi);
  final styles = bookmarkWidgetStyles.where((w) => w.pro).length;
  final groups = [
    (
      t('Make it yours', 'Theo ý bạn'),
      [
        ProPart(
          ProFeature.premiumThemes,
          t(
            '${premiumLooks.length} themes',
            '${premiumLooks.length} giao diện',
          ),
          t(
            'Ink & Paper, gallery dark and more',
            'Mực & Giấy, phòng tranh tối và hơn thế',
          ),
          t(
            'Each theme recolours the whole library, light and dark where it has both. Try every one on your own library first.',
            'Mỗi giao diện đổi màu cả thư viện, có cả sáng và tối nếu giao diện có. Thử từng cái trên chính thư viện của bạn trước.',
          ),
        ),
        ProPart(
          ProFeature.premiumLayouts,
          t(
            '${galleryLayouts.length} collection layouts',
            '${galleryLayouts.length} kiểu bày bộ sưu tập',
          ),
          t(
            'Magazine, masonry, film strip, scrapbook…',
            'Tạp chí, xếp gạch, cuộn phim, sổ dán…',
          ),
          t(
            'Lay out a collection the way its things look best: a magazine with a cover story, two staggered columns of pictures, a film strip, a scrapbook and more. Each collection keeps its own.',
            'Bày bộ sưu tập theo cách hợp nhất với nội dung: tạp chí có bài trang bìa, hai cột ảnh so le, cuộn phim, sổ dán và hơn thế. Mỗi bộ sưu tập giữ kiểu riêng.',
          ),
        ),
        ProPart(
          ProFeature.focusSkins,
          t(
            '${focusSkins.length} Focus styles',
            '${focusSkins.length} kiểu Tập trung',
          ),
          t(
            'One saved thing at a time, your way',
            'Từng mục một, theo kiểu bạn thích',
          ),
          t(
            'Focus shows one saved thing at a time. Pro adds Minimal, Film, Editorial and Nocturne; the classic one stays free.',
            'Tập trung hiện từng mục đã lưu. Pro thêm Tối giản, Phim, Tạp chí và Đêm; kiểu cổ điển vẫn miễn phí.',
          ),
        ),
        ProPart(
          ProFeature.widgets,
          t('Pro widgets and $styles styles', 'Widget Pro và $styles kiểu'),
          t(
            'Reading picks, Visual gallery, widget themes',
            'Gợi ý đọc, Thư viện ảnh, kiểu widget',
          ),
          t(
            'Reading picks brings back things you saved and never opened; Visual gallery shows your pictures. Every widget can take one of $styles styles, each easy to read.',
            'Gợi ý đọc mang lại những mục đã lưu mà chưa mở; Thư viện ảnh bày ảnh của bạn. Mọi widget có thể dùng một trong $styles kiểu, chữ luôn dễ đọc.',
          ),
        ),
      ],
    ),
    (
      t('Sort less by hand', 'Bớt xếp bằng tay'),
      [
        ProPart(
          ProFeature.autoOrganize,
          t('Auto organize', 'Tự sắp xếp'),
          t('New saves go where they belong', 'Mục mới tự về đúng chỗ'),
          t(
            'Tell it once that YouTube goes to Watch later and GitHub to Code; new saves from there skip Not sorted. Every move can be undone.',
            'Nói một lần: YouTube vào Xem sau, GitHub vào Lập trình; mục mới từ đó bỏ qua Chưa xếp. Mọi lần chuyển đều hoàn tác được.',
          ),
        ),
        ProPart(
          ProFeature.smartCollections,
          t('Smart collections', 'Bộ sưu tập thông minh'),
          t('Collections that fill themselves', 'Bộ sưu tập tự gom'),
          t(
            'Describe what belongs, such as "has a picture, not read, saved this month", and the collection keeps itself up to date. Nothing is moved; items only show up there.',
            'Mô tả thứ thuộc về, ví dụ "có ảnh, chưa đọc, lưu trong tháng", và bộ sưu tập tự cập nhật. Không mục nào bị chuyển; chúng chỉ hiện thêm ở đó.',
          ),
        ),
        ProPart(
          ProFeature.advancedBulk,
          t('Batch tools', 'Công cụ hàng loạt'),
          t(
            'Clean titles and file many at once',
            'Dọn tiêu đề, xếp nhiều mục một lần',
          ),
          t(
            'Pick many items, trim noisy titles ("!!! | Site name"), tag and file them together. A dry run shows the result first, and one Undo puts it all back.',
            'Chọn nhiều mục, cắt phần thừa của tiêu đề ("!!! | Tên trang"), gắn thẻ và xếp cùng lúc. Chạy thử cho xem kết quả trước, và một lần Hoàn tác trả lại tất cả.',
          ),
        ),
      ],
    ),
    (
      t('Read, find and share', 'Đọc, tìm và chia sẻ'),
      [
        ProPart(
          ProFeature.readerHighlights,
          t('Highlights and notes', 'Đánh dấu và ghi chú'),
          t('Five colours in the reader', 'Năm màu trong trình đọc'),
          t(
            'Highlight passages in the reader in five colours and add notes. They stay with the item and travel in backups.',
            'Đánh dấu đoạn văn trong trình đọc với năm màu và thêm ghi chú. Chúng đi cùng mục và có trong bản sao lưu.',
          ),
        ),
        ProPart(
          ProFeature.deepSearch,
          t('Deep search', 'Tìm sâu'),
          t(
            'Inside articles, highlights and pictures',
            'Trong bài viết, đoạn đánh dấu và ảnh',
          ),
          t(
            'Search also looks inside your offline articles, highlights and the text in pictures, and says where it found each one.',
            'Tìm kiếm còn tìm trong bài đã lưu offline, đoạn đánh dấu và chữ trong ảnh, và cho biết tìm thấy ở đâu.',
          ),
        ),
        ProPart(
          ProFeature.ocrOffline,
          t('Text in pictures', 'Chữ trong ảnh'),
          t(
            'Read on this device, ready to copy',
            'Đọc ngay trên máy, sẵn để chép',
          ),
          t(
            'Copy the text in a saved picture: a sign, a menu, a slide. It is read on this device; nothing is uploaded.',
            'Chép chữ trong ảnh đã lưu: biển hiệu, thực đơn, slide. Chữ được đọc ngay trên máy; không tải lên đâu cả.',
          ),
        ),
        ProPart(
          ProFeature.premiumExport,
          t('Export studio', 'Xưởng xuất'),
          t(
            'A collection as a designed PDF',
            'Bộ sưu tập thành PDF có thiết kế',
          ),
          t(
            'Turn a collection into a designed document: a travel guide, a reading list, a mood board. Preview the real pages for free; saving the file needs Pro.',
            'Biến bộ sưu tập thành tài liệu có thiết kế: cẩm nang du lịch, danh sách đọc, bảng cảm hứng. Xem trước trang thật miễn phí; lưu tệp cần Pro.',
          ),
        ),
      ],
    ),
  ];
  // Only what this build ships is offered.
  return [
    for (final g in groups)
      (
        g.$1,
        [
          for (final x in g.$2)
            if (shippedProFeatures.contains(x.feature)) x,
        ],
      ),
  ];
}

/// The one place that explains Pro Lifetime: a stage that plays the part
/// that brought the person here, every other part by group (a tap plays
/// it), Free beside Pro, and one buy bar with the store's own price.
/// Everything people save stays free without it.
class ExplorePro extends StatefulWidget {
  final SaveScope scope;

  /// The feature that brought the person here, played first.
  final ProFeature? focus;
  const ExplorePro({super.key, required this.scope, this.focus});
  @override
  State<ExplorePro> createState() => _ExploreProState();
}

class _ExploreProState extends State<ExplorePro> {
  final _scroll = ScrollController();
  late ProFeature _shown = widget.focus ?? ProFeature.premiumThemes;

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
    final p = BookmarkPalette.of(context);
    final groups = proGroups(context);
    final all = [for (final g in groups) ...g.$2];
    final part = all.firstWhere(
      (x) => x.feature == _shown,
      orElse: () => all.first,
    );
    // The stage keeps the drawing's 16:9 up to the column's 720 px.
    final width = MediaQuery.sizeOf(context).width.clamp(0.0, 720.0) - 32;
    final stageHeight = (width * 9 / 16).clamp(170.0, 340.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Handy Bookmark Pro')),
      bottomNavigationBar: _Purchase(
        store: LifetimeScope.maybeOf(context),
        canContinue: widget.focus != null,
      ),
      body: ListView(
        key: const Key('explore-pro'),
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.focus == null) ...[
                    Semantics(
                      header: true,
                      child: Text(
                        tr(
                          context,
                          'Make your library yours',
                          'Biến thư viện thành của bạn',
                        ),
                        style: bookmarkSerif(context, 30),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(
                        context,
                        'One payment, yours for good. No ads and no subscription, ever.',
                        'Trả một lần, dùng mãi. Không quảng cáo, không thuê bao.',
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
                      borderRadius: BorderRadius.circular(
                        BookmarkRadii.collection,
                      ),
                    ),
                    child: HandyDemoLoop(
                      key: ValueKey(part.feature),
                      label: bookmarkProDemoLabel(context, part.feature),
                      replayLabel: tr(context, 'Play again', 'Xem lại'),
                      builder: (context, t) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: bookmarkProDemo(context, part.feature, t),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  HandySwap(
                    child: Column(
                      key: ValueKey(part.feature),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            part.title,
                            key: const Key('pro-stage-title'),
                            style: bookmarkSerif(
                              context,
                              widget.focus == null ? 22 : 28,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(part.body, style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  ),
                  for (final g in groups)
                    if (g.$2.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Semantics(
                        header: true,
                        child: Text(g.$1, style: theme.textTheme.titleMedium),
                      ),
                      const SizedBox(height: 6),
                      for (final x in g.$2)
                        _PartRow(
                          part: x,
                          shown: x.feature == part.feature,
                          onTap: () => _show(x.feature),
                        ),
                    ],
                  const SizedBox(height: 28),
                  const _FreeAndPro(),
                  const SizedBox(height: 20),
                  Text(
                    tr(
                      context,
                      'Always free: saving links and pictures, search, collections, Focus, the reader, the read-later reminder, three widgets, backups, Recently deleted and sync through a folder. If Pro ever goes away, nothing you saved is touched; Pro looks wait until it is back.',
                      'Luôn miễn phí: lưu link và ảnh, tìm kiếm, bộ sưu tập, Tập trung, trình đọc, nhắc đọc sau, ba widget, sao lưu, Thùng rác và đồng bộ qua thư mục. Nếu không còn Pro, không gì bạn đã lưu bị đụng tới; kiểu Pro chờ tới khi có lại.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                  ),
                ],
              ),
            ),
          ),
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
    final p = BookmarkPalette.of(context);
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
        borderRadius: BorderRadius.circular(BookmarkRadii.item),
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
                  borderRadius: BorderRadius.circular(BookmarkRadii.thumb),
                  border: Border.all(
                    color: shown ? p.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: bookmarkProDemo(context, part.feature, 1),
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

/// Free beside Pro, counted from the app's own catalogues.
class _FreeAndPro extends StatelessWidget {
  const _FreeAndPro();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    String t(String en, String vi) => tr(context, en, vi);
    final stylesFree = bookmarkWidgetStyles.where((w) => !w.pro).length;
    final stylesPro = bookmarkWidgetStyles.length - stylesFree;
    final rows = [
      (
        t('Saving links and pictures', 'Lưu link và ảnh'),
        t('No limits', 'Không giới hạn'),
        t('No limits', 'Không giới hạn'),
      ),
      (
        t('Collections', 'Bộ sưu tập'),
        t('As many as you like', 'Bao nhiêu cũng được'),
        t('+ smart collections', '+ bộ sưu tập thông minh'),
      ),
      (
        t('Themes', 'Giao diện'),
        t('Library, light and dark', 'Thư viện, sáng và tối'),
        t(
          '+ ${premiumLooks.length} themes',
          '+ ${premiumLooks.length} giao diện',
        ),
      ),
      (
        t('Collection layouts', 'Kiểu bày bộ sưu tập'),
        t('List or cards', 'Danh sách hoặc thẻ'),
        t(
          '+ ${galleryLayouts.length} layouts',
          '+ ${galleryLayouts.length} kiểu bày',
        ),
      ),
      (
        t('Focus', 'Tập trung'),
        t('Classic', 'Cổ điển'),
        t('+ ${focusSkins.length} styles', '+ ${focusSkins.length} kiểu'),
      ),
      (
        t('Home-screen widgets', 'Widget màn hình chính'),
        t(
          'Quick save, Reading queue, Favourite collection; $stylesFree styles',
          'Lưu nhanh, Hàng đợi đọc, Bộ sưu tập yêu thích; $stylesFree kiểu',
        ),
        t(
          '+ Reading picks, Visual gallery, $stylesPro styles',
          '+ Gợi ý đọc, Thư viện ảnh, $stylesPro kiểu',
        ),
      ),
      (
        t('Sorting', 'Sắp xếp'),
        t('By hand, one at a time or a few', 'Bằng tay, từng mục hoặc vài mục'),
        t(
          'Auto organize, batch tools with Undo',
          'Tự sắp xếp, công cụ hàng loạt có Hoàn tác',
        ),
      ),
      (
        t('Reading', 'Đọc'),
        t(
          'Reader, offline copy, read-later reminder',
          'Trình đọc, bản offline, nhắc đọc sau',
        ),
        t('+ highlights and notes', '+ đánh dấu và ghi chú'),
      ),
      (
        t('Search', 'Tìm kiếm'),
        t('Titles, notes, sites, tags', 'Tiêu đề, ghi chú, trang, thẻ'),
        t(
          '+ inside articles, highlights, pictures',
          '+ trong bài viết, đoạn đánh dấu, ảnh',
        ),
      ),
      (
        t('Export', 'Xuất'),
        t(
          'Backups; ZIP, JSON, HTML, CSV, Markdown',
          'Sao lưu; ZIP, JSON, HTML, CSV, Markdown',
        ),
        t('+ Export studio PDFs', '+ PDF từ Xưởng xuất'),
      ),
    ];
    Widget head(String s) => Expanded(
      child: Text(
        s,
        style: theme.textTheme.labelLarge?.copyWith(color: p.muted),
      ),
    );
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

/// The buy bar at the page's foot, saying only what the store said: its
/// price, a pending payment, a cancel, an error, or that this build has no
/// store. Once Pro is active it thanks, and [canContinue] (opened from a
/// Pro part) offers to go straight back to it.
class _Purchase extends StatelessWidget {
  final LifetimeController? store;
  final bool canContinue;
  const _Purchase({required this.store, required this.canContinue});
  @override
  Widget build(BuildContext context) {
    final s = store;
    if (s == null) return _bar(context, null);
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => _bar(context, s),
    );
  }

  Widget _bar(BuildContext context, LifetimeController? s) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final snap = s?.snapshot;
    final configured = s?.configured ?? false;
    final pro = s?.pro == true;
    var trouble = false;
    final String status;
    if (s == null || !configured) {
      status = tr(
        context,
        'Not on sale in this build yet, so nothing can be bought here.',
        'Bản này chưa mở bán, nên chưa thể mua ở đây.',
      );
    } else if (pro) {
      status = tr(
        context,
        'Pro is active on this device. Thank you.',
        'Pro đang dùng trên máy này. Cảm ơn bạn.',
      );
    } else if (s.pending) {
      status = tr(
        context,
        'Waiting for the store to confirm the payment…',
        'Đang chờ cửa hàng xác nhận thanh toán…',
      );
    } else {
      trouble = snap?.status == 'error' || snap?.status == 'unavailable';
      status = switch (snap?.status) {
        'canceled' => tr(
          context,
          'Purchase cancelled. Nothing was charged.',
          'Đã hủy mua. Không bị trừ tiền.',
        ),
        'error' || 'unavailable' => tr(
          context,
          'The store could not be reached. Nothing was charged; try again later.',
          'Chưa kết nối được cửa hàng. Không bị trừ tiền; thử lại sau.',
        ),
        _ => tr(
          context,
          'Pay once through the store. No subscription.',
          'Trả một lần qua cửa hàng. Không thuê bao.',
        ),
      };
    }
    final price = snap?.price;
    final busy = s?.busy == true;
    final canBuy = s != null && configured && !pro && !busy && !s.pending;
    return Material(
      key: const Key('pro-purchase'),
      color: p.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.line)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Row(
                        children: [
                          if (pro || trouble) ...[
                            Icon(
                              pro ? Icons.check_circle : Icons.error_outline,
                              size: 18,
                              color: pro ? p.sage : p.danger,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              status,
                              key: const Key('pro-status'),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (pro)
                      if (canContinue)
                        FilledButton(
                          key: const Key('pro-continue'),
                          onPressed: () => Navigator.maybePop(context),
                          child: Text(tr(context, 'Continue', 'Tiếp tục')),
                        )
                      else
                        const SizedBox.shrink()
                    else
                      Row(
                        children: [
                          TextButton(
                            key: const Key('pro-restore'),
                            onPressed: s != null && configured && !busy
                                ? () => s.action('restore')
                                : null,
                            child: Text(tr(context, 'Restore', 'Khôi phục')),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              key: const Key('pro-buy'),
                              onPressed: canBuy ? () => s.action('buy') : null,
                              child: busy || s?.pending == true
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      configured && price != null
                                          ? tr(
                                              context,
                                              'Get Pro · $price',
                                              'Mua Pro · $price',
                                            )
                                          : tr(context, 'Get Pro', 'Mua Pro'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
