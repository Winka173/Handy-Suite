import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart';
import 'entitlements.dart';

/// All purchase authority stays in the shared native adapter, not user data.
class HabitProPurchase extends StatefulWidget {
  final bool footer;
  const HabitProPurchase({super.key, this.footer = false});
  @override
  State<HabitProPurchase> createState() => _HabitProPurchaseState();
}

class _HabitProPurchaseState extends State<HabitProPurchase> {
  String? operation, completed;
  Future<void> act(LifetimeController store, String action) async {
    setState(() {
      operation = action;
      completed = null;
    });
    await store.action(action);
    if (mounted)
      setState(() {
        operation = null;
        completed = action;
      });
  }

  @override
  Widget build(BuildContext context) {
    final store = LifetimeScope.maybeOf(context);
    final snap = store?.snapshot;
    final pro = store?.pro == true;
    final configured = habitStoreSupported && store?.configured == true;
    final busy = store?.busy == true;
    final pending = store?.pending == true;
    String t(String en, String vi) => tr(context, en, vi);
    final status = !habitStoreSupported
        ? t('Not available on this platform yet.', 'Chưa có trên nền tảng này.')
        : !configured
        ? t('Pro is not on sale in this build yet.', 'Bản này chưa mở bán Pro.')
        : pro
        ? t(
            'Pro is active on this device. Thank you.',
            'Pro đang dùng trên máy này. Cảm ơn bạn.',
          )
        : busy
        ? operation == 'restore'
              ? t('Restoring purchases…', 'Đang khôi phục giao dịch…')
              : t(
                  'Loading store price and ownership…',
                  'Đang tải giá và quyền mua từ cửa hàng…',
                )
        : pending
        ? t(
            'Waiting for store confirmation. Pro unlocks after verification.',
            'Đang chờ cửa hàng xác nhận. Pro mở sau khi xác minh.',
          )
        : switch (snap?.status) {
            'canceled' => t(
              'Purchase cancelled. You can try again.',
              'Đã hủy mua. Bạn có thể thử lại.',
            ),
            'error' => t(
              'The store could not confirm the purchase. Retry or restore to check ownership.',
              'Cửa hàng chưa xác nhận giao dịch. Thử lại hoặc khôi phục để kiểm tra quyền mua.',
            ),
            'unavailable' => t(
              'Store unavailable. Check your connection and try again. Existing verified Pro stays available offline.',
              'Chưa kết nối được cửa hàng. Kiểm tra mạng rồi thử lại. Pro đã xác minh vẫn dùng khi ngoại tuyến.',
            ),
            _ =>
              completed == 'restore'
                  ? t(
                      'No Pro purchase found for this store account.',
                      'Không tìm thấy giao dịch Pro của tài khoản cửa hàng này.',
                    )
                  : snap?.price == null
                  ? t(
                      'The store price has not loaded. Retry to check availability.',
                      'Chưa tải được giá từ cửa hàng. Thử lại để kiểm tra.',
                    )
                  : t(
                      'Pay once through Google Play. No subscription.',
                      'Trả một lần qua Google Play. Không thuê bao.',
                    ),
          };
    final price = snap?.price;
    return Column(
      key: const Key('pro-purchase'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  status,
                  key: const Key('pro-status'),
                  style: widget.footer
                      ? Theme.of(context).textTheme.bodySmall
                      : null,
                ),
              ),
            ),
            if (configured &&
                !busy &&
                !pending &&
                ((!pro && price == null) ||
                    snap?.status == 'error' ||
                    snap?.status == 'unavailable' ||
                    snap?.status == 'canceled'))
              TextButton(
                key: const Key('pro-retry'),
                onPressed: () => act(store!, 'read'),
                child: Text(t('Retry', 'Thử lại')),
              ),
          ],
        ),
        if (configured && pro && snap?.status == 'unavailable')
          Text(
            t(
              'Offline · using verified ownership saved on this device.',
              'Ngoại tuyến · dùng quyền mua đã xác minh lưu trên máy.',
            ),
          ),
        const SizedBox(height: 12),
        if (busy) const LinearProgressIndicator(),
        if (configured)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: widget.footer
                ? WrapAlignment.spaceBetween
                : WrapAlignment.start,
            children: [
              if (widget.footer)
                OutlinedButton(
                  key: const Key('pro-restore'),
                  onPressed: busy || pending
                      ? null
                      : () => act(store!, 'restore'),
                  child: Text(t('Restore', 'Khôi phục')),
                ),
              if (!pro)
                FilledButton(
                  key: const Key('pro-buy'),
                  onPressed:
                      !busy &&
                          !pending &&
                          price != null &&
                          price.isNotEmpty &&
                          snap?.status != 'unavailable' &&
                          snap?.status != 'error'
                      ? () => act(store!, 'buy')
                      : null,
                  child: Text(
                    price == null
                        ? t('Get Pro', 'Mở Pro')
                        : t('Get Pro · $price', 'Mở Pro · $price'),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (!widget.footer)
                OutlinedButton(
                  key: const Key('pro-restore'),
                  onPressed: busy || pending
                      ? null
                      : () => act(store!, 'restore'),
                  child: Text(t('Restore purchases', 'Khôi phục giao dịch')),
                ),
            ],
          ),
        const SizedBox(height: 8),
        if (!widget.footer)
          Text(
            t(
              'One-time purchase. No subscription. Ownership belongs to this Google Play account and does not transfer between stores.',
              'Mua một lần. Không thuê bao. Quyền mua thuộc tài khoản Google Play này, không chuyển giữa các cửa hàng.',
            ),
          ),
      ],
    );
  }
}
