import 'package:flutter/foundation.dart';
import 'package:handy_ui/kit.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where feedback goes.
const feedbackEmail = 'apps.winka.studio@gmail.com';

/// The published privacy policy and terms of service on winka.top (the Play
/// listing's privacy policy too), English; [openLegal] opens the Vietnamese
/// page when the app is in Vietnamese. The texts are PRIVACY.md and TERMS.md.
const String? privacyPolicyUrl =
    'https://winka.top/en/apps/handy-bookmark/privacy/';
const String? termsUrl = 'https://winka.top/en/apps/handy-bookmark/terms/';

/// [url] in the app's language: winka.top keeps each page under /en/ and /vi/.
String legalUrlFor(BuildContext context, String url) =>
    tr(context, url, url.replaceFirst('/en/', '/vi/'));

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
/// the subject. Nothing from the library goes in it.
Uri feedbackMail() => Uri.parse(
  'mailto:$feedbackEmail'
  '?subject=${Uri.encodeComponent('Handy Bookmark feedback (${_platform()})')}',
);

/// Settings › Send feedback: opens the mail app with the address filled
/// in. Where there is no mail app, says the address and offers to copy it.
Future<void> sendFeedback(BuildContext context) async {
  if (await openExternal(feedbackMail()) || !context.mounted) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
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

/// Opens a published legal page, in the app's language.
Future<void> openLegal(BuildContext context, String url) async {
  if (await openExternal(Uri.parse(legalUrlFor(context, url))) ||
      !context.mounted) {
    return;
  }
  showHandyMessage(
    context,
    tr(context, 'Could not open the page.', 'Chưa mở được trang.'),
  );
}
