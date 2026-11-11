import 'package:handy_ui/kit.dart';
import 'about.dart' show openHabitLink;

/// Where feedback goes.
const habitFeedbackEmail = 'apps.winka.studio@gmail.com';

/// The privacy policy and terms of service on winka.top (also the Play
/// listing's privacy policy), in English; [habitLegalUri] gives the
/// Vietnamese page when the app is in Vietnamese.
const habitPrivacyUrl = 'https://winka.top/en/apps/handy-habit/privacy/';
const habitTermsUrl = 'https://winka.top/en/apps/handy-habit/terms/';

/// [url] in the app's language: winka.top keeps each page under /en/ and /vi/.
Uri habitLegalUri(BuildContext context, String url) =>
    Uri.parse(tr(context, url, url.replaceFirst('/en/', '/vi/')));

/// Privacy policy · Terms of service, as two small links (the Pro page).
class HabitLegalLinks extends StatelessWidget {
  const HabitLegalLinks({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      TextButton(
        key: const Key('legal-privacy'),
        onPressed: () =>
            openHabitLink(context, habitLegalUri(context, habitPrivacyUrl)),
        child: Text(tr(context, 'Privacy policy', 'Chính sách riêng tư')),
      ),
      const Text('·'),
      TextButton(
        key: const Key('legal-terms'),
        onPressed: () =>
            openHabitLink(context, habitLegalUri(context, habitTermsUrl)),
        child: Text(tr(context, 'Terms of service', 'Điều khoản sử dụng')),
      ),
    ],
  );
}
