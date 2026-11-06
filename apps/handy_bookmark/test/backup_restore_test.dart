import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'package:image/image.dart' as img;
import 'controller_test.dart' show TestStore;
import 'new_flows_test.dart' show OneFile, boot, settle, idOf;
import 'widget_test.dart' show tapKey;

/// Keeps what was exported, and hands out the next import.
class CaptureFiles extends OneFile {
  Uint8List? saved;
  String? savedName;
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    saved = bytes;
    savedName = name;
    return name;
  }
}

Uint8List photo() {
  final image = img.Image(width: 900, height: 1600);
  img.fill(image, color: img.ColorRgb8(30, 140, 90));
  return img.encodeJpg(image, quality: 90);
}

Future<void> wait(WidgetTester t, [int ms = 300]) async {
  await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await settle(t);
}

Future<void> openSettings(WidgetTester t) async {
  Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/settings');
  await t.pumpAndSettle();
}

void main() {
  testWidgets('a ZIP backup moves pictures and Recently Deleted to a new '
      'device, byte for byte', (t) async {
    // Device A: a picture, and a link sent to Recently Deleted.
    final filesA = CaptureFiles()
      ..next = ImportedBytes('Bảng giá cà phê.jpg', photo());
    final (a, _) = await boot(t, files: filesA);
    await tapKey(t, 'save-new');
    await tapKey(t, 'save-photo');
    await wait(t);
    final picture = a.library!.bookmarks.firstWhere((b) => b.isImage);
    final original = (a.store as TestStore).ownedMedia[picture.media!.id]!.$1;
    await a.update(
      (l) => moveToTrash(l, [idOf(a, 'https://b.org/two')], saveTime()),
    );
    await openSettings(t);
    // Back up is one tap: the ZIP with pictures, no format to choose.
    await tapKey(t, 'save-backup');
    await wait(t);
    expect(filesA.savedName, 'handy-bookmark.zip');
    expect(find.textContaining('1 picture and'), findsOneWidget);
    expect(a.lastBackup?.automatic, isFalse, reason: 'Settings says when');

    // A separate device: nothing of A's app stays mounted.
    await t.pumpWidget(const SizedBox());
    // Device B: empty, restores the file.
    final filesB = CaptureFiles()
      ..next = ImportedBytes('handy-bookmark.zip', filesA.saved!);
    final (b, _) = await boot(t, files: filesB, urls: const []);
    expect(b.library!.bookmarks, isEmpty);
    await openSettings(t);
    await tapKey(t, 'save-import');
    await wait(t);
    expect(find.byKey(const Key('import-pictures')), findsOneWidget);
    expect(find.textContaining('With 1 pictures'), findsOneWidget);
    await tapKey(t, 'import-replace');
    await tapKey(t, 'confirm-action');
    await wait(t);

    final restored = b.library!.bookmarks.firstWhere((x) => x.isImage);
    expect(restored.id, picture.id);
    expect(restored.title, 'Bảng giá cà phê');
    final bytes = (b.store as TestStore).ownedMedia[restored.media!.id]!.$1;
    expect(bytes, original, reason: 'the original, not a re-encoded copy');
    expect(b.library!.trash.single.originalUrl, 'https://b.org/two');
    expect(b.library!.bookmarks.length, a.library!.bookmarks.length);
    expect(await b.mediaPreview(restored.media!.id), isNotNull);
  });
}
