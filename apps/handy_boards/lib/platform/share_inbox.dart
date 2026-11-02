import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BoardsShare {
  final String id, text;
  final String? title;
  const BoardsShare(this.id, this.text, this.title);
}

/// Durable native inbox, acknowledged only after the app transaction commits.
class BoardsShareInbox {
  static const channel = MethodChannel('handy.boards/share');
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

  Future<List<BoardsShare>> pending() async {
    if (!supported) return [];
    final rows = await channel.invokeListMethod<dynamic>('drain') ?? [];
    return [
      for (final row in rows)
        BoardsShare(
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
