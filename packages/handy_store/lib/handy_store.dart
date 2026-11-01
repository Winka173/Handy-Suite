import 'package:flutter/services.dart';

class StoreSnapshot {
  final String status, productId, reason;
  final String? price;
  final bool owned, verified;
  const StoreSnapshot({
    required this.status,
    required this.productId,
    this.reason = '',
    this.price,
    this.owned = false,
    this.verified = false,
  });
  bool get isPro => owned && verified;
  factory StoreSnapshot.parse(dynamic raw, String productId) {
    if (raw is! Map ||
        raw['productId'] != productId ||
        raw['status'] is! String ||
        ![
          'ready',
          'owned',
          'pending',
          'canceled',
          'unavailable',
          'error',
        ].contains(raw['status']))
      throw const FormatException('Invalid native store response');
    final owned = raw['owned'] == true, verified = raw['verified'] == true;
    if (owned && !verified)
      throw const FormatException('Unverified native store ownership');
    return StoreSnapshot(
      status: raw['status'],
      productId: productId,
      reason: raw['reason'] is String ? raw['reason'] : '',
      price: raw['price'] is String ? raw['price'] : null,
      owned: owned,
      verified: verified,
    );
  }
}

abstract interface class LifetimeStorePort {
  Future<StoreSnapshot> read();
  Future<StoreSnapshot> purchase();
  Future<StoreSnapshot> restore();
  void listen(void Function(StoreSnapshot) listener);
  Future<void> dispose();
}

class NativeLifetimeStore implements LifetimeStorePort {
  final String productId, androidPublicKey;
  final MethodChannel channel;
  NativeLifetimeStore({
    required this.productId,
    this.androidPublicKey = '',
    this.channel = const MethodChannel('handy_store'),
  });
  Map<String, String> get arguments => {
    'productId': productId,
    'publicKey': androidPublicKey,
  };
  Future<StoreSnapshot> _call(String method) async => StoreSnapshot.parse(
    await channel.invokeMethod<dynamic>(method, arguments),
    productId,
  );
  @override
  Future<StoreSnapshot> read() => _call('read');
  @override
  Future<StoreSnapshot> purchase() => _call('buy');
  @override
  Future<StoreSnapshot> restore() => _call('restore');
  @override
  void listen(void Function(StoreSnapshot) listener) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'stateChanged') {
        try {
          listener(StoreSnapshot.parse(call.arguments, productId));
        } on FormatException {
          /* Untrusted/foreign products never unlock. */
        }
      }
    });
  }

  @override
  Future<void> dispose() async {
    channel.setMethodCallHandler(null);
  }
}
