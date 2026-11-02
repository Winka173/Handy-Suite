import 'package:handy_ui/kit.dart';
import '../specs.dart';

/// Tools outside the engine registry that open their own bench panel.
const generators = [
  (
    'qr',
    Icons.qr_code_2,
    'QR code',
    'Mã QR',
    'Text, links, Wi-Fi, contacts, events, bank transfers',
    'Văn bản, liên kết, Wi-Fi, liên hệ, sự kiện, chuyển khoản',
  ),
  (
    'password',
    Icons.password,
    'Password',
    'Mật khẩu',
    'Strong, random, never stored',
    'Mạnh, ngẫu nhiên, không lưu lại',
  ),
  (
    'subtitles',
    Icons.subtitles_outlined,
    'Subtitles',
    'Phụ đề',
    'SRT ↔ WebVTT, shift the timing',
    'SRT ↔ WebVTT, dời thời gian',
  ),
];

String toolTitle(BuildContext c, String id) {
  for (final g in generators) {
    if (g.$1 == id) return tr(c, g.$3, g.$4);
  }
  return specById[id]?.title(c) ?? id;
}

IconData toolIcon(String id) {
  for (final g in generators) {
    if (g.$1 == id) return g.$2;
  }
  return specById[id]?.icon ?? Icons.handyman_outlined;
}

/// Every Tools entry in the suite's finder (Ctrl K). Returns the chosen id.
Future<String?> showToolCatalog(
  BuildContext context, {
  required Set<String> pinned,
  required Future<void> Function(String id) onTogglePin,
}) {
  final make = tr(context, 'Make', 'Tạo mới');
  return showHandyCatalog(
    context,
    searchHint: tr(context, 'Find a tool', 'Tìm công cụ'),
    pinned: pinned,
    onTogglePin: onTogglePin,
    groups: [make, for (final k in Category.values) categoryLabel(context, k)],
    entries: [
      for (final g in generators)
        HandyCatalogEntry(
          id: g.$1,
          title: tr(context, g.$3, g.$4),
          hint: tr(context, g.$5, g.$6),
          group: make,
          icon: g.$2,
          pinnable: false,
          keywords: '${g.$3} ${g.$4}',
        ),
      for (final s in specs)
        HandyCatalogEntry(
          id: s.id,
          title: s.title(context),
          hint: s.hint(context),
          group: categoryLabel(context, s.category),
          icon: s.icon,
          keywords: '${s.engine.titleEn} ${s.engine.titleVi}',
        ),
    ],
  );
}
