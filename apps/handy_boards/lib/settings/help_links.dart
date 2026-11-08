import 'package:flutter/foundation.dart';
import 'package:handy_ui/kit.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where feedback goes.
const feedbackEmail = 'apps.winka.studio@gmail.com';

/// The published privacy policy and terms of service (apps/handy_boards/
/// PRIVACY.md and TERMS.md, the Play listing's too); Settings opens them.
const String? privacyPolicyUrl =
    'https://github.com/Winka173/Handy-Suite/blob/ui-rebuild/apps/handy_boards/PRIVACY.md';
const String? termsUrl =
    'https://github.com/Winka173/Handy-Suite/blob/ui-rebuild/apps/handy_boards/TERMS.md';

/// Opens; tests replace it.
@visibleForTesting
Future<bool> Function(Uri) openExternal = (uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
};

String _platform() => kIsWeb
    ? 'Web'
    : switch (defaultTargetPlatform) {
        TargetPlatform.android => 'Android',
        TargetPlatform.iOS => 'iOS',
        TargetPlatform.windows => 'Windows',
        TargetPlatform.macOS => 'macOS',
        TargetPlatform.linux => 'Linux',
        TargetPlatform.fuchsia => 'Fuchsia',
      };

/// The mail to write: to [feedbackEmail], with the app and the platform in
/// the subject. Nothing from your boards goes in it.
Uri feedbackMail() => Uri.parse(
  'mailto:$feedbackEmail'
  '?subject=${Uri.encodeComponent('Handy Boards feedback (${_platform()})')}',
);

/// Settings › Send feedback: opens the mail app with the address filled
/// in. Where there is no mail app, says the address and offers to copy it.
Future<void> sendFeedback(BuildContext context) async {
  if (await openExternal(feedbackMail()) || !context.mounted) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // Undo stays a few seconds, then goes; it never sits over the board.
        persist: false,
        key: const Key('feedback-no-mail'),
        content: Text(
          tr(
            context,
            'No mail app opened. Write to $feedbackEmail',
            'Không mở được app mail. Hãy gửi tới $feedbackEmail',
          ),
        ),
        action: SnackBarAction(
          label: tr(context, 'Copy', 'Chép'),
          onPressed: () => copyToClipboard(context, feedbackEmail),
        ),
      ),
    );
}

/// Opens a published legal page, when it exists.
Future<void> openLegal(BuildContext context, String url) async {
  if (await openExternal(Uri.parse(url)) || !context.mounted) return;
  showHandyMessage(
    context,
    tr(context, 'Could not open the page.', 'Chưa mở được trang.'),
  );
}
