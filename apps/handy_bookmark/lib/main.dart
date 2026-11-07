import 'package:flutter/widgets.dart';
import 'app.dart';
import 'share_sheet/share_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SaveApp());
}

/// The share sheet's own start (Android `ShareSheetActivity`): only the
/// sheet, over the app someone shares from.
@pragma('vm:entry-point')
void shareSheet() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShareSheetApp());
}
