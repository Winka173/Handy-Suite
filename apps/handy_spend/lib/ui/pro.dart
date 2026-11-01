import 'package:handy_ui/kit.dart';

/// Says which Pro feature was asked for and offers the way to it. Nothing
/// is changed either way.
Future<void> askForPro(BuildContext context, String en, String vi) async {
  final open = await confirmHandy(
    context,
    title: tr(context, 'A Pro feature', 'Tính năng Pro'),
    message: tr(
      context,
      '$en comes with Pro Lifetime: one payment, no ads. Everything else stays free.',
      '$vi có trong Pro trọn đời: trả một lần, không quảng cáo. Mọi thứ khác vẫn miễn phí.',
    ),
    confirmLabel: tr(context, 'See Pro', 'Xem Pro'),
    cancelLabel: tr(context, 'Not now', 'Để sau'),
  );
  if (open && context.mounted) await Navigator.pushNamed(context, '/settings');
}
