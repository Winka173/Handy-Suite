import 'package:flutter/foundation.dart';

class SpendCapabilities {
  final bool web,
      deviceLock,
      notifications,
      dragDrop,
      mobileAds,
      storeEntitlement;
  const SpendCapabilities({
    required this.web,
    required this.deviceLock,
    required this.notifications,
    required this.dragDrop,
    required this.mobileAds,
    required this.storeEntitlement,
  });
  static SpendCapabilities get current {
    final mobile =
            !kIsWeb &&
            {
              TargetPlatform.android,
              TargetPlatform.iOS,
            }.contains(defaultTargetPlatform),
        windows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    return SpendCapabilities(
      web: kIsWeb,
      deviceLock: mobile || windows,
      notifications: mobile,
      dragDrop: kIsWeb || windows,
      mobileAds: mobile,
      storeEntitlement: mobile || windows,
    );
  }
}
