import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:handy_store/handy_store.dart';

String get monetizationPlatform => kIsWeb
    ? 'web'
    : switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        TargetPlatform.windows => 'windows',
        _ => 'unsupported',
      };

class MonetizationConfig {
  final String productId, androidPublicKey, adUnitId;

  /// The app's public store or web page on this platform (https), used to
  /// point at sibling apps; empty until the app is published.
  final String listingUrl;
  final bool adsEnabled;
  const MonetizationConfig({
    this.productId = '',
    this.androidPublicKey = '',
    this.adUnitId = '',
    this.listingUrl = '',
    this.adsEnabled = false,
  });
  factory MonetizationConfig.parse(String source, String app, String platform) {
    if (source.length > 30000)
      throw const FormatException('Store config limit');
    final root = jsonDecode(source),
        value = root is Map && root[app] is Map ? root[app][platform] : null;
    if (value == null) return const MonetizationConfig();
    if (value is! Map) throw const FormatException('Invalid store config');
    String field(String key, int max) {
      final v = value[key] ?? '';
      if (v is! String || v.length > max)
        throw const FormatException('Invalid store config field');
      return v;
    }

    final product = field('productId', 200),
        publicKey = field('androidPublicKey', 2048),
        unit = field('bannerAdUnitId', 100),
        listing = field('listingUrl', 300);
    if (listing.isNotEmpty &&
        (Uri.tryParse(listing)?.scheme != 'https' ||
            Uri.parse(listing).host.isEmpty))
      throw const FormatException('Invalid listing URL');
    if (product.isNotEmpty && !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(product) ||
        unit.isNotEmpty &&
            !RegExp(r'^ca-app-pub-\d{16}/\d{10}$').hasMatch(unit))
      throw const FormatException('Invalid product/ad identifier');
    return MonetizationConfig(
      productId: product,
      androidPublicKey: publicKey,
      adUnitId: unit,
      listingUrl: listing,
      adsEnabled:
          value['adsEnabled'] == true &&
          unit.isNotEmpty &&
          ['android', 'ios'].contains(platform),
    );
  }
  static const _raw = String.fromEnvironment(
    'HANDY_MONETIZATION_CONFIG',
    defaultValue: '{}',
  );

  /// The public pages of the suite's apps on this platform, by app id; only
  /// apps that have one.
  static Map<String, String> listings([String source = _raw]) {
    final out = <String, String>{};
    try {
      final root = jsonDecode(source);
      if (root is! Map) return out;
      for (final app in root.keys.whereType<String>()) {
        final url = MonetizationConfig.parse(
          source,
          app,
          monetizationPlatform,
        ).listingUrl;
        if (url.isNotEmpty) out[app] = url;
      }
    } on FormatException {
      return {};
    }
    return out;
  }

  static MonetizationConfig forApp(String app) {
    const raw = _raw;
    try {
      final config = MonetizationConfig.parse(raw, app, monetizationPlatform);
      if (kDebugMode && const bool.fromEnvironment('HANDY_TEST_ADS'))
        return MonetizationConfig(
          productId: config.productId,
          androidPublicKey: config.androidPublicKey,
          adsEnabled: ['android', 'ios'].contains(monetizationPlatform),
          adUnitId: monetizationPlatform == 'ios'
              ? 'ca-app-pub-3940256099942544/2934735716'
              : 'ca-app-pub-3940256099942544/6300978111',
        );
      return config;
    } on FormatException {
      return const MonetizationConfig();
    }
  }
}

class LifetimeController extends ChangeNotifier {
  final MonetizationConfig config;
  final LifetimeStorePort store;
  StoreSnapshot? snapshot;
  bool busy = false, disposed = false;
  int adRevision = 0;
  void privacyChanged() {
    if (!disposed) {
      adRevision++;
      notifyListeners();
    }
  }

  LifetimeController(this.config, this.store) {
    store.listen(accept);
  }
  bool get pro => snapshot?.isPro ?? false;
  bool get pending => snapshot?.status == 'pending';
  /// A product id is enough: on Android, Google Play's word on a purchase
  /// is taken unless the app also gives its licence key (androidPublicKey),
  /// in which case the purchase's signature is checked too.
  bool get configured =>
      config.productId.isNotEmpty &&
      ['android', 'ios', 'windows'].contains(monetizationPlatform);
  void accept(StoreSnapshot value) {
    if (disposed || value.productId != config.productId) return;
    snapshot = value;
    notifyListeners();
  }

  Future<void> action(String action) async {
    if (busy || !configured) return;
    busy = true;
    notifyListeners();
    try {
      final result =
          await (action == 'buy'
                  ? store.purchase()
                  : action == 'restore'
                  ? store.restore()
                  : store.read())
              .timeout(const Duration(seconds: 40));
      accept(result);
    } catch (_) {
      if (!disposed) {
        snapshot = StoreSnapshot(
          status: 'unavailable',
          productId: config.productId,
          reason: 'store_unavailable',
          owned: pro,
          verified: pro,
        );
      }
    } finally {
      if (!disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    unawaited(store.dispose());
    super.dispose();
  }
}

class MonetizationHost extends StatefulWidget {
  final String app;
  final Widget child;
  const MonetizationHost({super.key, required this.app, required this.child});
  @override
  State<MonetizationHost> createState() => _MonetizationHostState();
}

class _MonetizationHostState extends State<MonetizationHost>
    with WidgetsBindingObserver {
  late final config = MonetizationConfig.forApp(widget.app);
  late final controller = LifetimeController(
    config,
    NativeLifetimeStore(
      productId: config.productId,
      androidPublicKey: config.androidPublicKey,
    ),
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.action('read');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) controller.action('read');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LifetimeScope(notifier: controller, child: widget.child);
}

class LifetimeScope extends InheritedNotifier<LifetimeController> {
  const LifetimeScope({
    super.key,
    required super.notifier,
    required super.child,
  });
  static LifetimeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LifetimeScope>()?.notifier;
}

String _tr(BuildContext context, String en, String vi) =>
    Localizations.localeOf(context).languageCode == 'vi' ? vi : en;

class LifetimeSettings extends StatelessWidget {
  const LifetimeSettings({super.key});
  @override
  Widget build(BuildContext context) {
    final model = LifetimeScope.maybeOf(context);
    if (model == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          model.pro
              ? 'Pro Lifetime'
              : _tr(context, 'Free + Pro Lifetime', 'Free + Pro Lifetime'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          HandyAdSlot.provider == null
              ? _tr(
                  context,
                  'One-time purchase unlocks the Pro features of this app. There are no ads. Ownership belongs to this store account and does not transfer between stores. Core tools remain free.',
                  'Mua một lần để mở các tính năng Pro của app này. App không có quảng cáo. Quyền sở hữu thuộc tài khoản cửa hàng này, không chuyển giữa các cửa hàng. Các công cụ chính vẫn miễn phí.',
                )
              : _tr(
                  context,
                  'One-time purchase removes supported advertisements in this app. Ownership belongs to this store account and does not transfer between stores. Core tools remain available for free.',
                  'Mua một lần để bỏ quảng cáo được hỗ trợ trong app này. Quyền sở hữu thuộc tài khoản cửa hàng này, không chuyển giữa các cửa hàng. Các công cụ chính vẫn dùng miễn phí.',
                ),
        ),
        if (!model.configured)
          Text(
            _tr(
              context,
              'Pro Lifetime is not on sale in this build.',
              'Bản này chưa mở bán Pro Lifetime.',
            ),
          ),
        if (model.pending)
          Text(
            _tr(
              context,
              'Purchase is pending. Pro unlocks after store verification.',
              'Giao dịch đang chờ. Pro chỉ mở sau khi cửa hàng xác minh.',
            ),
          ),
        if (model.snapshot?.status == 'canceled')
          Text(_tr(context, 'Purchase canceled.', 'Đã hủy mua.')),
        if (model.snapshot?.status == 'error' ||
            model.snapshot?.status == 'unavailable')
          Text(
            _tr(
              context,
              'Store verification is unavailable. You can retry or restore purchases.',
              'Chưa thể xác minh qua cửa hàng. Bạn có thể thử lại hoặc khôi phục giao dịch.',
            ),
          ),
        if (model.configured)
          Wrap(
            spacing: 8,
            children: [
              if (!model.pro)
                FilledButton(
                  onPressed: model.busy || model.pending
                      ? null
                      : () => model.action('buy'),
                  child: Text(
                    _tr(context, 'Buy Pro Lifetime', 'Mua Pro Lifetime'),
                  ),
                ),
              OutlinedButton(
                onPressed: model.busy ? null : () => model.action('restore'),
                child: Text(
                  _tr(context, 'Restore purchases', 'Khôi phục giao dịch'),
                ),
              ),
              TextButton(
                onPressed: model.busy ? null : () => model.action('read'),
                child: Text(
                  _tr(context, 'Check ownership', 'Kiểm tra quyền sở hữu'),
                ),
              ),
            ],
          ),
        if (model.busy) const LinearProgressIndicator(),
        if (model.config.adsEnabled && HandyAdSlot.provider != null)
          TextButton(
            onPressed: () => showAdPrivacyChoices(model),
            child: Text(
              _tr(
                context,
                'Advertising privacy choices',
                'Lựa chọn quyền riêng tư quảng cáo',
              ),
            ),
          ),
      ],
    );
  }
}

/// Where ads come from. The ad SDK lives in `package:handy_ads`, which an
/// app installs at start (`installHandyAds()`); an app that never installs
/// it carries no advertising SDK, banner or consent form at all.
abstract class AdProvider {
  /// The banner for this app's ad unit, shown only to Free users when the
  /// app's config enables ads.
  Widget banner(LifetimeController model);

  /// The consent platform's privacy options; ads reload with the choice.
  void privacyOptions(LifetimeController model);
}

abstract final class HandyAdSlot {
  static AdProvider? provider;
}

/// Opens the ad privacy options, when an ad provider is installed.
void showAdPrivacyChoices(LifetimeController model) =>
    HandyAdSlot.provider?.privacyOptions(model);

/// The ad banner, or nothing: no provider, Pro, or ads off for this app.
class LifetimeBanner extends StatelessWidget {
  const LifetimeBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final model = LifetimeScope.maybeOf(context), ads = HandyAdSlot.provider;
    if (model == null || ads == null || model.pro || !model.config.adsEnabled)
      return const SizedBox.shrink();
    return ads.banner(model);
  }
}
