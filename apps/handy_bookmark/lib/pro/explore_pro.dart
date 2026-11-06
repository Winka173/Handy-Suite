import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart';
import '../design/looks.dart';
import '../design/theme.dart';
import '../scope.dart';
import 'entitlements.dart';
import 'theme_studio.dart';

/// The one place that explains Pro Lifetime: what it adds today (and
/// only what ships), a way to try each part first, the store's own price,
/// buy and restore. Everything people save stays free without it.
class ExplorePro extends StatelessWidget {
  final SaveScope scope;

  /// The feature that brought the person here, shown first.
  final ProFeature? focus;
  const ExplorePro({super.key, required this.scope, this.focus});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final store = LifetimeScope.maybeOf(context);
    final pillars = [
      _Pillar(
        key: const Key('pro-pillar-looks'),
        title: tr(context, 'Personalisation studio', 'Xưởng giao diện'),
        body: tr(
          context,
          'Ten themes and eight ways to lay out a collection (magazine, masonry, film strip, scrapbook and more). Try them on your own library first.',
          'Mười giao diện và tám kiểu bày bộ sưu tập (tạp chí, xếp gạch, cuộn phim, sổ dán…). Thử trên chính thư viện của bạn trước.',
        ),
        action: tr(context, 'Try the themes', 'Thử các giao diện'),
        onAction: () => Navigator.pushNamed(context, '/looks'),
        preview: SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: premiumLooks.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 112,
                child: LookSwatch(
                  palette: premiumLooks[i].palette(theme.brightness),
                ),
              ),
            ),
          ),
        ),
      ),
      _Pillar(
        key: const Key('pro-pillar-smart'),
        title: tr(context, 'Smart organisation', 'Sắp xếp thông minh'),
        body: tr(
          context,
          'Auto organize puts new saves where they belong by their source; batch tools clean titles and file many at once, with a dry run and Undo; smart collections fill themselves from rules.',
          'Tự sắp xếp đưa mục mới về đúng chỗ theo nguồn; công cụ hàng loạt dọn tiêu đề và xếp nhiều mục cùng lúc, có chạy thử và Hoàn tác; bộ sưu tập thông minh tự gom theo quy tắc.',
        ),
        action: tr(context, 'Set up Auto organize', 'Thiết lập Tự sắp xếp'),
        onAction: () => Navigator.pushNamed(context, '/organize'),
      ),
      _Pillar(
        key: const Key('pro-pillar-reading'),
        title: tr(context, 'Reading and search', 'Đọc và tìm kiếm'),
        body: tr(
          context,
          'Highlight passages in the reader in five colours and add notes; they stay with the item in backups. Copy the text in a picture, read on this device. Search also looks inside your offline articles, highlights and pictures, and says where it found each one.',
          'Đánh dấu đoạn văn trong trình đọc với năm màu và thêm ghi chú; chúng đi cùng mục trong bản sao lưu. Chép chữ trong ảnh, đọc ngay trên máy. Tìm kiếm còn tìm trong bài đã lưu offline, đoạn đánh dấu và ảnh, và cho biết tìm thấy ở đâu.',
        ),
      ),
    ];
    if (focus == ProFeature.smartCollections)
      pillars.insert(0, pillars.removeAt(1));
    return Scaffold(
      appBar: AppBar(title: const Text('Handy Bookmark Pro')),
      body: ListView(
        key: const Key('explore-pro'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            tr(
              context,
              'Make your library yours',
              'Biến thư viện thành của bạn',
            ),
            style: bookmarkSerif(context, 30),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              'One payment, yours for good. No ads and no subscription, ever.',
              'Trả một lần, dùng mãi. Không quảng cáo, không thuê bao.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(color: p.muted),
          ),
          const SizedBox(height: 16),
          for (final pillar in pillars) ...[pillar, const SizedBox(height: 12)],
          _Purchase(store: store),
          const SizedBox(height: 16),
          Text(
            tr(
              context,
              'Always free: saving links and pictures, search, collections, Focus, the reader, backups, Recently deleted and sync through a folder.',
              'Luôn miễn phí: lưu link và ảnh, tìm kiếm, bộ sưu tập, Tập trung, trình đọc, sao lưu, Thùng rác và đồng bộ qua thư mục.',
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Pillar extends StatelessWidget {
  final String title, body;
  final String? action;
  final VoidCallback? onAction;
  final Widget? preview;
  const _Pillar({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
    this.preview,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(BookmarkRadii.collection),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
          ),
          if (preview != null) ...[const SizedBox(height: 12), preview!],
          if (action != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(action!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Buy and restore, saying only what the store said: its price, a
/// pending payment, a cancel, an error, or that this build has no store.
class _Purchase extends StatelessWidget {
  final LifetimeController? store;
  const _Purchase({required this.store});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final s = store;
    final snap = s?.snapshot;
    final configured = s?.configured ?? false;
    final String status;
    if (s == null || !configured) {
      status = tr(
        context,
        'Purchases are not set up in this build yet, so nothing can be bought here.',
        'Bản này chưa thiết lập mua hàng, nên chưa thể mua ở đây.',
      );
    } else if (s.pro) {
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
          'A one-time purchase through the store.',
          'Mua một lần qua cửa hàng ứng dụng.',
        ),
      };
    }
    final price = snap?.price;
    final canBuy = s != null && configured && !s.pro && !s.busy && !s.pending;
    return Container(
      key: const Key('pro-purchase'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.tint,
        borderRadius: BorderRadius.circular(BookmarkRadii.collection),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pro Lifetime', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            status,
            key: const Key('pro-status'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (s?.pro != true)
            FilledButton(
              key: const Key('pro-buy'),
              onPressed: canBuy ? () => s.action('buy') : null,
              child: s?.busy == true
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      configured && price != null
                          ? tr(context, 'Get Pro for $price', 'Mua Pro $price')
                          : tr(context, 'Get Pro', 'Mua Pro'),
                    ),
            ),
          TextButton(
            key: const Key('pro-restore'),
            onPressed: s != null && configured && !s.busy
                ? () => s.action('restore')
                : null,
            child: Text(tr(context, 'Restore purchase', 'Khôi phục giao dịch')),
          ),
        ],
      ),
    );
  }
}
