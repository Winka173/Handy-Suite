import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';

export 'pro_page.dart';

/// What Pro Lifetime adds. Everything a board needs to work stays free:
/// boards, cards, categories, subtasks, drag and drop, due dates, search,
/// backup and plain export.
enum ProFeature {
  templates,
  covers,
  looks,
  automation,
  export,
  insights,
  cardTemplates,
  myWork,
  carryOver,
  fields,
  history,
  savedFilters,
  repeat,
  digest,
  widgetStyles,
}

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

/// The buy bar at the page's foot, saying only what the store said: its
/// price, a pending payment, a cancel, an error, or that this build has no
/// store. Once Pro is active it thanks, and [canContinue] (opened from a
/// Pro part) offers to go straight back to it.
class ProPurchase extends StatelessWidget {
  final LifetimeController? store;
  final bool canContinue;
  const ProPurchase({super.key, required this.store, this.canContinue = false});
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
    final p = BoardsPalette.of(context);
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
          'Đã huỷ mua. Không bị trừ tiền.',
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
                              color: pro ? p.positive : p.danger,
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
