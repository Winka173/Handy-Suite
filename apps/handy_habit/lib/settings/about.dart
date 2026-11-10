import 'package:handy_ui/kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openHabitLink(BuildContext context, Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  if (context.mounted)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
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
    );
}

class HabitAboutRows extends StatelessWidget {
  const HabitAboutRows({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _Version(),
      HandyTile(
        title: tr(context, 'Privacy policy', 'Chính sách riêng tư'),
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
      HandyTile(
        title: tr(context, 'Open-source licenses', 'Giấy phép mã nguồn mở'),
        onTap: () =>
            showLicensePage(context: context, applicationName: 'Handy Habit'),
      ),
      HandyTile(
        title: tr(context, 'Support', 'Hỗ trợ'),
        subtitle: 'apps.winka.studio@gmail.com',
        onTap: () => openHabitLink(
          context,
          Uri(
            scheme: 'mailto',
            path: 'apps.winka.studio@gmail.com',
            queryParameters: {'subject': 'Handy Habit support'},
          ),
        ),
      ),
    ],
  );
}

class _Version extends StatefulWidget {
  const _Version();
  @override
  State<_Version> createState() => _VersionState();
}

class _VersionState extends State<_Version> {
  late Future<PackageInfo> info = PackageInfo.fromPlatform();
  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: info,
    builder: (context, s) => HandyTile(
      title: tr(context, 'Version', 'Phiên bản'),
      subtitle: s.hasData
          ? '${s.data!.version} (${s.data!.buildNumber})'
          : s.hasError
          ? tr(
              context,
              'Unavailable · tap to retry',
              'Chưa đọc được · chạm để thử lại',
            )
          : tr(context, 'Loading…', 'Đang tải…'),
      onTap: s.hasError
          ? () => setState(() => info = PackageInfo.fromPlatform())
          : null,
    ),
  );
}
