import 'package:handy_ui/kit.dart';
import '../controller.dart';

/// The library's own name when the person gave it one, else "My library"
/// (the app's name where there is no locale to say it in).
String libraryName(SaveController c, [BuildContext? context]) {
  final name = (c.preferences['libraryName'] as String? ?? '').trim();
  if (name.isNotEmpty) return name;
  return context == null
      ? 'Handy Bookmark'
      : tr(context, 'My library', 'Thư viện của tôi');
}
