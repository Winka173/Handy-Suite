import 'package:flutter/material.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'l10n.dart';
import 'settings.dart';
import 'theme.dart';

/// One app of the suite, as the others list it.
class HandySuiteApp {
  final String id, name, en, vi;
  final Color hue;
  const HandySuiteApp(this.id, this.name, this.hue, this.en, this.vi);
}

const handySuite = [
  HandySuiteApp(
    'trip',
    'Handy Trip',
    Color(0xFF0284C7),
    'Offline trips, confirmed visits and travel memories.',
    'Lịch trình offline, lượt ghé xác nhận và kỷ niệm du lịch.',
  ),
  HandySuiteApp(
    'tools',
    'Handy Tools',
    Color(0xFFE8590C),
    'Calculators, converters, QR codes and text tools.',
    'Máy tính, đổi đơn vị, mã QR và công cụ văn bản.',
  ),
  HandySuiteApp(
    'docs',
    'Handy Docs',
    Color(0xFF1D5FBF),
    'Scan, write Markdown, sign and tidy PDFs.',
    'Quét giấy tờ, viết Markdown, ký và sắp xếp PDF.',
  ),
  HandySuiteApp(
    'media',
    'Handy Media',
    Color(0xFFC2255C),
    'Step-by-step guides from screenshots; quick image edits.',
    'Hướng dẫn từng bước từ ảnh chụp màn hình; sửa ảnh nhanh.',
  ),
  HandySuiteApp(
    'dev',
    'Handy Dev',
    Color(0xFF0F8A5F),
    'JSON, regex, API requests and developer tools.',
    'JSON, regex, gọi API và công cụ cho lập trình.',
  ),
  HandySuiteApp(
    'keep',
    'Handy Keep',
    Color(0xFFB7791F),
    'Where your things are, who borrowed them, warranties.',
    'Đồ để đâu, ai đang mượn, bảo hành đến bao giờ.',
  ),
  HandySuiteApp(
    'recall',
    'Handy Recall',
    Color(0xFF4D7C0F),
    'Flashcards that come back when you are about to forget.',
    'Thẻ ôn quay lại đúng lúc bạn sắp quên.',
  ),
  HandySuiteApp(
    'bookmark',
    'Handy Bookmark',
    Color(0xFF0E7490),
    'Save links from any app and read them later.',
    'Lưu link từ mọi app và đọc lại sau.',
  ),
  HandySuiteApp(
    'spend',
    'Handy Spend',
    Color(0xFF2E7D32),
    'How much you can still spend today.',
    'Hôm nay còn tiêu được bao nhiêu.',
  ),
  HandySuiteApp(
    'habit',
    'Handy Habit',
    Color(0xFFB42318),
    'Habits as one tap a day; routines step by step.',
    'Thói quen một chạm mỗi ngày; quy trình từng bước.',
  ),
];

/// "Other Handy apps": the siblings that have a public page on this
/// platform. Hidden until at least one does. Opens only on a tap.
class HandyMoreApps extends StatelessWidget {
  final String app;

  /// App id → https page; defaults to the store configuration.
  final Map<String, String>? listings;

  /// A divider above, for placing it among settings sections.
  final bool divider;
  const HandyMoreApps({
    super.key,
    required this.app,
    this.listings,
    this.divider = false,
  });

  @override
  Widget build(BuildContext context) {
    final pages = listings ?? MonetizationConfig.listings();
    final others = [
      for (final a in handySuite)
        if (a.id != app && pages[a.id] != null) a,
    ];
    if (others.isEmpty) return const SizedBox.shrink();
    final c = HandyColors.of(context);
    final section = HandySettingsSection(
      title: tr(context, 'Other Handy apps', 'Các app khác trong Handy'),
      description: tr(
        context,
        'Each one works on its own, offline, with its own data.',
        'Mỗi app chạy riêng, không cần mạng, dữ liệu riêng.',
      ),
      children: [
        for (final a in others)
          ListTile(
            key: Key('more-${a.id}'),
            leading: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: a.hue, shape: BoxShape.circle),
            ),
            minLeadingWidth: 12,
            title: Text(a.name),
            subtitle: Text(
              tr(context, a.en, a.vi),
              style: TextStyle(color: c.muted),
            ),
            trailing: Icon(Icons.open_in_new, size: 18, color: c.muted),
            onTap: () => launchUrl(
              Uri.parse(pages[a.id]!),
              mode: LaunchMode.externalApplication,
            ),
          ),
      ],
    );
    return divider
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [const Divider(), section],
          )
        : section;
  }
}
