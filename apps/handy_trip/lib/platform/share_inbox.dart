import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TripShare {
  final String id, text;
  final String? title;
  const TripShare(this.id, this.text, this.title);
}

/// Durable native inbox, acknowledged only after the app transaction commits.
class TripShareInbox {
  static const channel = MethodChannel('handy.trip/share');
  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  void listen(VoidCallback changed) {
    if (supported)
      channel.setMethodCallHandler((call) async {
        if (call.method == 'incoming') changed();
      });
  }

  Future<List<TripShare>> pending() async {
    if (!supported) return [];
    final rows = await channel.invokeListMethod<dynamic>('drain') ?? [];
    return [
      for (final row in rows)
        TripShare(
          row['id'] as String,
          row['text'] as String,
          row['title'] as String?,
        ),
    ];
  }

  Future<void> acknowledge(String id) async {
    if (await channel.invokeMethod<bool>('ack', {'id': id}) != true)
      throw StateError('Share remains queued; saved data preserved');
  }

  void dispose() {
    if (supported) channel.setMethodCallHandler(null);
  }
}
