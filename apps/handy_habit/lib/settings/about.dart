import 'package:handy_ui/kit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settings_parts.dart';

Future<void> openHabitLink(BuildContext context, Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  if (context.mounted)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        persist: false,
        content: Text(
          tr(
            context,
            'Could not open $uri. You can copy the address.',
            'Chưa mở được $uri. Bạn có thể chép địa chỉ.',
          ),
        ),
        action: SnackBarAction(
          label: tr(context, 'Copy', 'Chép'),
          onPressed: () => copyToClipboard(context, uri.toString()),
        ),
      ),
      snackBarAnimationStyle: AnimationStyle(
        duration: HandyMotion.of(context),
        reverseDuration: HandyMotion.of(context),
      ),
    );
}

/// About: feedback, privacy, terms and licences, as Handy Boards.
List<Widget> habitAboutRows(BuildContext context) => [
  SettingsRow(
    key: const Key('settings-feedback'),
    icon: Icons.mail_outline,
    title: tr(context, 'Send feedback', 'Gửi góp ý'),
    subtitle: 'apps.winka.studio@gmail.com',
    onTap: () => openHabitLink(
      context,
      Uri(
        scheme: 'mailto',
        path: 'apps.winka.studio@gmail.com',
        queryParameters: {'subject': 'Handy Habit'},
      ),
    ),
  ),
  SettingsRow(
    key: const Key('settings-privacy'),
    icon: Icons.policy_outlined,
    title: tr(context, 'Privacy policy', 'Chính sách riêng tư'),
    subtitle: tr(
      context,
      'No account, no tracking; Drive only if you turn sync on',
      'Không tài khoản, không theo dõi; chỉ dùng Drive khi bạn bật đồng bộ',
    ),
    navigates: true,
    onTap: () => openHabitLink(
      context,
      Uri.parse(
        tr(
          context,
          'https://winka.top/en/apps/handy-habit/privacy/',
          'https://winka.top/vi/apps/handy-habit/privacy/',
        ),
      ),
    ),
  ),
  SettingsRow(
    key: const Key('settings-terms'),
    icon: Icons.gavel_outlined,
    title: tr(context, 'Terms of service', 'Điều khoản sử dụng'),
    navigates: true,
    onTap: () => openHabitLink(
      context,
      Uri.parse(
        tr(
          context,
          'https://winka.top/en/apps/handy-habit/terms/',
          'https://winka.top/vi/apps/handy-habit/terms/',
        ),
      ),
    ),
  ),
  SettingsRow(
    key: const Key('settings-licenses'),
    icon: Icons.info_outline,
    title: tr(context, 'Licenses', 'Giấy phép'),
    subtitle: tr(
      context,
      'Open-source licenses and fonts',
      'Giấy phép mã nguồn mở và phông chữ',
    ),
    navigates: true,
    onTap: () =>
        showLicensePage(context: context, applicationName: 'Handy Habit'),
  ),
];
