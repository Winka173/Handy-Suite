import 'package:handy_files/handy_files.dart';
import 'package:handy_save_engine/handy_save_engine.dart';
import 'package:handy_ui/kit.dart';
import 'controller.dart';
import 'editors.dart';
import 'services/metadata_client.dart' show sanitizeThumbnail;
import 'services/reminders.dart';
import 'ui/collection_picker.dart';
import 'view/library_view.dart';

/// What every Save screen shares: the controller, the list on screen, the
/// file picker and reminders, and the actions that change a link.
class SaveScope {
  final SaveController c;
  final LibraryView view;
  final HandyFiles files;
  final SaveReminders reminders;
  const SaveScope({
    required this.c,
    required this.view,
    required this.files,
    required this.reminders,
  });

  SaveLibrary get library => c.library!;
  Bookmark? find(String id) =>
      library.bookmarks.where((b) => b.id == id).firstOrNull;

  /// Replaces one link (undoable), stamping the change time.
  Future<void> put(Bookmark b) => view.change(
    (l) => l.copyWith(
      bookmarks: [
        for (final x in l.bookmarks)
          x.id == b.id ? b.copyWith(updatedAt: saveTime()) : x,
      ],
    ),
  );

  Future<void> toggle(
    BuildContext context,
    Bookmark b,
    Bookmark Function(Bookmark) flip,
  ) => run(context, () => put(flip(b)));

  Future<void> move(BuildContext context, Bookmark b) async {
    final id = await pickCollection(context, library);
    if (id == null || !context.mounted) return;
    await run(
      context,
      () => put(b.copyWith(collectionId: id.isEmpty ? null : id)),
    );
  }

  /// Files a link from the "not sorted" strip; throws so the card can stay.
  Future<void> file(Bookmark b, String collectionId) =>
      put(b.copyWith(collectionId: collectionId));

  Future<void> edit(BuildContext context, Bookmark b) async {
    final next = await Navigator.push<Bookmark>(
      context,
      MaterialPageRoute(
        builder: (_) => BookmarkEditor(initial: b, library: library),
      ),
    );
    if (next != null && context.mounted) await run(context, () => put(next));
  }

  /// Asks, deletes, and offers to undo.
  Future<bool> delete(BuildContext context, Bookmark b) async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Delete this link?', 'Xóa link này?'),
      message: b.title.isEmpty ? b.originalUrl : b.title,
      confirmLabel: tr(context, 'Delete', 'Xóa'),
      destructive: true,
    );
    if (!ok || !context.mounted) return false;
    final done = await run(
      context,
      () => view.change(
        (l) => l.copyWith(
          bookmarks: [
            for (final x in l.bookmarks)
              if (x.id != b.id) x,
          ],
        ),
      ),
    );
    if (done && context.mounted)
      undoMessage(context, tr(context, 'Link deleted.', 'Đã xóa link.'));
    return done;
  }

  /// A short message with an Undo action for the last change.
  void undoMessage(BuildContext context, String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: SnackBarAction(
            label: tr(context, 'Undo', 'Hoàn tác'),
            onPressed: view.undo,
          ),
        ),
      );
  }

  /// A picture the person picked (PNG, JPEG or WebP up to 1 MB), cleaned.
  Future<void> chooseThumbnail(BuildContext context, Bookmark b) =>
      run(context, () async {
        final file = await files.importBytes(
          extensions: ['png', 'jpg', 'jpeg', 'webp'],
          maxBytes: 1000000,
        );
        if (file == null) return;
        final image = sanitizeThumbnail(file.bytes);
        if (image.bytes == null) {
          throw const FormatException(
            'Use a PNG, JPEG or WebP picture / Dùng ảnh PNG, JPEG hoặc WebP',
          );
        }
        await c.store!.putThumbnail(b.id, image.bytes!);
        c.thumbnailChanged(b.id);
      });

  /// Sets or clears a reminder; asks the OS once for permission.
  Future<void> remind(BuildContext context, Bookmark b, DateTime? at) =>
      run(context, () async {
        await put(b.copyWith(reminderAt: at?.toUtc().toIso8601String()));
        if (at == null || !reminders.supported) return;
        final allowed = await reminders.request();
        await c.update(
          (l) => l,
          prefs: {...c.preferences, 'notifications': allowed},
        );
      });

  Future<void> open(
    BuildContext context,
    Bookmark b, {
    bool browser = false,
  }) async {
    final ok = await c.open(b, browser: browser);
    if (!ok && context.mounted) {
      showHandyMessage(
        context,
        tr(context, 'Could not open this link.', 'Chưa mở được link này.'),
      );
    }
  }

  /// Runs a change; on failure says that nothing changed. True on success.
  Future<bool> run(BuildContext context, Future<void> Function() task) async {
    try {
      await task();
      return true;
    } catch (e) {
      if (context.mounted) {
        showHandyMessage(
          context,
          tr(
            context,
            'Not saved: ${errorText(context, e)}. Nothing changed.',
            'Chưa lưu được: ${errorText(context, e)}. Không có gì thay đổi.',
          ),
        );
      }
      return false;
    }
  }
}
