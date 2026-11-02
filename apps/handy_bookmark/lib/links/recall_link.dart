import 'package:flutter/foundation.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:url_launcher/url_launcher.dart';

/// Phones open other apps by link; elsewhere the link has nowhere to go.
bool get canHandOff =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// A link as a study card in Handy Recall: its title as the question, the
/// address and note as the answer. Recall saves nothing until the person
/// does.
Uri recallLink(Bookmark b) {
  final front = (b.title.trim().isEmpty ? b.sourceDomain : b.title.trim());
  final back = [
    b.originalUrl,
    if (b.note.trim().isNotEmpty) b.note.trim(),
  ].join('\n');
  return Uri(
    scheme: 'handy-recall',
    host: 'new',
    queryParameters: {
      'front': front.length > 500 ? front.substring(0, 500) : front,
      'back': back.length > 2000 ? back.substring(0, 2000) : back,
    },
  );
}

Future<void> sendToRecall(BuildContext context, Bookmark b) async {
  var opened = false;
  try {
    opened = await launchUrl(
      recallLink(b),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted)
    showHandyMessage(
      context,
      tr(
        context,
        'Handy Recall is not on this device.',
        'Máy này chưa có Handy Recall.',
      ),
    );
}
