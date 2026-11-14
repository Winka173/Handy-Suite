import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/settings/storage_summary.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'new_flows_test.dart' show OneFile, boot, settle;
import 'pictures_test.dart' show png;
import 'widget_test.dart' show tapKey;

void main() {
  testWidgets('the home names the library and says what waits', (t) async {
    await boot(t);
    expect(find.text('My library'), findsWidgets);
    // Under the name: how much it holds (what waits has its own card).
    expect(find.text('3 items'), findsOneWidget);
    await tapKey(t, 'open-settings');
    await tapKey(t, 'set-library-name');
    await t.enterText(
      find.byKey(const Key('library-name-input')),
      "Lan's saves",
    );
    await tapKey(t, 'library-name-save');
    await settle(t);
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.text("Lan's saves"), findsOneWidget);
  });

  testWidgets('storage shows counts and the size of the person\'s pictures', (
    t,
  ) async {
    final files = OneFile()..next = ImportedBytes('a.png', png(300, 200));
    final (c, _) = await boot(t, files: files);
    await tapKey(t, 'save-new');
    await tapKey(t, 'save-photo');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(t);
    final u = (await t.runAsync(() => storageUsage(c)))!;
    expect((u.links, u.pictures, u.readingCopies, u.deleted), (3, 1, 0, 0));
    expect(u.pictureBytes, png(300, 200).length);
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1536), '2 KB');
    expect(formatBytes(19293798), '18.4 MB');
  });
}
