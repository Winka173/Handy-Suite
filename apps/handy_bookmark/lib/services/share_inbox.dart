import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'web_share_inbox.dart';

class SharedLink {
  final String id, text;
  final String? title;
  const SharedLink(this.id, this.text, this.title);
}

class SaveShareInbox {
  final browser = BrowserShareInbox();
  static const channel = MethodChannel('handy.save/share');
  Future<void> start(
    VoidCallback incoming,
    ValueChanged<String> dropped,
    VoidCallback failed,
  ) async {
    if (kIsWeb) {
      browser.listen(incoming);
      return;
    }
    channel.setMethodCallHandler((call) async {
      if (call.method == 'incoming')
        incoming();
      else if (call.method == 'incomingText' && call.arguments is String)
        dropped(call.arguments as String);
      else if (call.method == 'shareError')
        failed();
    });
  }

  Future<List<SharedLink>> drain() async {
    if (kIsWeb)
      return [
        for (final r in await browser.drain())
          SharedLink(
            r['id'] as String,
            r['text'] as String,
            r['title'] as String?,
          ),
      ];
    try {
      final rows = await channel.invokeListMethod<dynamic>('drain') ?? [];
      return [
        for (final r in rows)
          SharedLink(
            r['id'] as String,
            r['text'] as String,
            r['title'] as String?,
          ),
      ];
    } on MissingPluginException {
      return [];
    }
  }

  Future<void> acknowledge(String id) async {
    if (kIsWeb) {
      await browser.ack(id);
      return;
    }
    final ok = await channel.invokeMethod<bool>('ack', {'id': id});
    if (ok != true)
      throw StateError('Share acknowledgment failed; saved data is retained');
  }

  void dispose() {
    browser.dispose();
    if (!kIsWeb) channel.setMethodCallHandler(null);
  }
}
