import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:handy_monetization/handy_monetization.dart';

/// Makes this app show ads to Free users where its config enables them.
/// Apps without ads (Handy Bookmark) never call this and never depend on
/// this package, so the Mobile Ads SDK is not in their build.
void installHandyAds() => HandyAdSlot.provider = const _AdMob();

class _AdMob implements AdProvider {
  const _AdMob();
  @override
  Widget banner(LifetimeController model) => _AdMobBanner(model: model);
  @override
  void privacyOptions(LifetimeController model) =>
      ConsentForm.showPrivacyOptionsForm((error) => model.privacyChanged());
}

/// No ad request happens before UMP permits it; no app/user document content is sent.
class _AdMobBanner extends StatefulWidget {
  final LifetimeController model;
  const _AdMobBanner({required this.model});
  @override
  State<_AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<_AdMobBanner> {
  BannerAd? ad;
  bool loading = false, loaded = false;
  int seenRevision = -1;
  LifetimeController get model => widget.model;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    LifetimeScope.maybeOf(context);
    if (seenRevision != model.adRevision) {
      seenRevision = model.adRevision;
      ad?.dispose();
      ad = null;
      loaded = false;
    }
    if (model.pro || !model.config.adsEnabled) {
      ad?.dispose();
      ad = null;
      loaded = false;
      return;
    }
    if (!loading && ad == null) {
      loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
  }

  Future<void> load() async {
    try {
      final completer = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => completer.complete(),
        (error) => completer.complete(),
      );
      await completer.future.timeout(const Duration(seconds: 15));
      final form = Completer<void>();
      ConsentForm.loadAndShowConsentFormIfRequired((error) => form.complete());
      await form.future.timeout(const Duration(seconds: 20));
      if (!await ConsentInformation.instance.canRequestAds() ||
          !mounted ||
          model.pro)
        return;
      await MobileAds.instance.initialize();
      if (!mounted || model.pro) return;
      ad = BannerAd(
        adUnitId: model.config.adUnitId,
        size: AdSize.banner,
        request: const AdRequest(nonPersonalizedAds: true),
        listener: BannerAdListener(
          onAdLoaded: (value) {
            if (!mounted || model.pro) {
              value.dispose();
              return;
            }
            setState(() => loaded = true);
          },
          onAdFailedToLoad: (value, error) {
            value.dispose();
            if (mounted)
              setState(() {
                ad = null;
                loaded = false;
              });
          },
        ),
      );
      await ad!.load();
    } catch (_) {
      /* Core offline tools remain usable when consent/ads are unavailable. */
    } finally {
      loading = false;
    }
  }

  @override
  void dispose() {
    ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = LifetimeScope.maybeOf(context);
    if (state == null || state.pro || !loaded || ad == null)
      return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: SizedBox(
          width: ad!.size.width.toDouble(),
          height: ad!.size.height.toDouble(),
          child: AdWidget(ad: ad!),
        ),
      ),
    );
  }
}
