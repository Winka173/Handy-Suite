import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native URL delivery only. Label parsing and local resolution remain in Keep.
class KeepDeepLinks {
  static const channel = MethodChannel('handy.keep/labels');
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> start(void Function(String) receive) async {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'openLabel' && call.arguments is String) {
        receive(call.arguments as String);
      }
    });
    final initial = await channel.invokeMethod<String>('start');
    if (initial != null) receive(initial);
  }

  void dispose() {
    if (supported) channel.setMethodCallHandler(null);
  }
}
