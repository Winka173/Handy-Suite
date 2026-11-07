import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';

/// What Pro Lifetime adds. Everything a board needs to work stays free:
/// boards, cards, categories, subtasks, drag and drop, due dates, search,
/// backup and plain export.
enum ProFeature { templates, covers, automation, export, insights }

/// Whether this device has a verified Pro Lifetime.
bool hasPro(BuildContext context) =>
    debugProOverride ?? LifetimeScope.maybeOf(context)?.pro == true;

/// Tests only. Never set in the app.
@visibleForTesting
bool? debugProOverride;

/// The one gate: true with Pro; otherwise opens Pro (at [feature]) and
/// says whether Pro became active there. Browsing and previews never call
/// this; only an explicit Use, Apply or Export does.
Future<bool> requirePro(BuildContext context, ProFeature feature) async {
  if (hasPro(context)) return true;
  await Navigator.pushNamed(context, '/pro', arguments: feature);
  return context.mounted && hasPro(context);
}

/// Pro: what it adds, each part tried first, the store's own price.
class ProPage extends StatelessWidget {
  final ProFeature? focus;
  const ProPage({super.key, this.focus});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final store = LifetimeScope.maybeOf(context);
    final parts = <(ProFeature, IconData, String, String)>[
      (
        ProFeature.templates,
        Icons.dashboard_customize_outlined,
        tr(context, 'Five more templates', 'Thêm năm mẫu bảng'),
        tr(
          context,
          'Content production, goals, events, a moodboard and a renovation, each with its own covers. Open any of them in the gallery to see the whole board first.',
          'Sản xuất nội dung, mục tiêu, sự kiện, moodboard và sửa nhà, mỗi mẫu có bộ bìa riêng. Mở trong thư viện mẫu để xem cả bảng trước.',
        ),
      ),
      (
        ProFeature.covers,
        Icons.image_outlined,
        tr(context, 'Every cover family', 'Mọi bộ ảnh bìa'),
        tr(
          context,
          'The full cover library. Free keeps a good selection in every family; tap any cover to see it on your card before deciding.',
          'Toàn bộ thư viện bìa. Bản miễn phí vẫn có đủ bìa đẹp ở mọi họ; chạm một bìa để xem ngay trên thẻ trước khi quyết định.',
        ),
      ),
      (
        ProFeature.automation,
        Icons.bolt_outlined,
        tr(context, 'Small automations', 'Tự động hoá nhỏ'),
        tr(
          context,
          'Move a card to the finished column when its last subtask is ticked; archive finished cards after a while. Off until you turn each one on; Undo always works.',
          'Chuyển thẻ sang cột xong khi tick việc con cuối; lưu trữ thẻ xong sau một thời gian. Tắt cho tới khi bạn bật từng cái; luôn hoàn tác được.',
        ),
      ),
      (
        ProFeature.export,
        Icons.ios_share,
        tr(context, 'Designed exports', 'Bản xuất có thiết kế'),
        tr(
          context,
          'Your board as a picture or PDF in poster and printable styles. Plain export and backups stay free.',
          'Bảng thành ảnh hoặc PDF kiểu poster và bản in. Xuất thường và sao lưu vẫn miễn phí.',
        ),
      ),
      (
        ProFeature.insights,
        Icons.insights_outlined,
        tr(context, 'Board insights', 'Thống kê bảng'),
        tr(
          context,
          'Per category: done, overdue and finished this week, from your own cards.',
          'Theo từng nhóm: đã xong, quá hạn và xong trong tuần, tính từ chính thẻ của bạn.',
        ),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Handy Boards Pro', 'Handy Boards Pro')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(context, 'Pay once. Keep it.', 'Trả một lần. Dùng mãi.'),
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      context,
                      'No subscription, no ads, no account. Your boards stay on your device either way.',
                      'Không thuê bao, không quảng cáo, không tài khoản. Bảng của bạn luôn ở trên máy.',
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(color: p.muted),
                  ),
                  const SizedBox(height: 20),
                  for (final part in parts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: part.$1 == focus ? p.tint : p.surface,
                        borderRadius: BorderRadius.circular(BoardsRadii.tile),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(part.$2, color: p.muted),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      part.$3,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      part.$4,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: p.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  ProPurchase(store: store),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Buy and restore, saying only what the store said: its price, a pending
/// payment, a cancel, an error, or that this build has no store yet.
class ProPurchase extends StatelessWidget {
  final LifetimeController? store;
  const ProPurchase({super.key, required this.store});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
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
          'Đã huỷ mua. Không bị trừ tiền.',
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
        borderRadius: BorderRadius.circular(BoardsRadii.tile),
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
