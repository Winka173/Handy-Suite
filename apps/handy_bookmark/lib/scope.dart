import 'package:handy_files/handy_files.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'controller.dart';
import 'editors.dart';
import 'links/link_tasks.dart';
import 'services/metadata_client.dart' show sanitizeThumbnail;
import 'services/reminders.dart';
import 'ui/collection_picker.dart';
import 'bookmark/picture_view.dart';
import 'view/library_view.dart';

/// What every Save screen shares: the controller, the list on screen, the
/// file picker and reminders, and the actions that change a link.
class SaveScope {
  final SaveController c;
  final LibraryView view;
  final HandyFiles files;
  final SaveReminders reminders;

  /// Link checks and reading copies, one job at a time.
  final LinkTasks tasks;

  /// Automatic backups to a folder; null in tests that do not need them.
  final HandyAutoBackup? autoBackup;
  const SaveScope({
    required this.c,
    required this.view,
    required this.files,
    required this.reminders,
    required this.tasks,
    this.autoBackup,
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

  /// Moves the item to Recently Deleted and offers Undo. Nothing is lost:
  /// it stays restorable for 30 days, so there is no question first.
  Future<bool> delete(BuildContext context, Bookmark b) async {
    final done = await run(
      context,
      () => view.change((l) => moveToTrash(l, [b.id], saveTime())),
    );
    if (done && context.mounted)
      undoMessage(
        context,
        tr(context, 'Moved to Recently Deleted.', 'Đã chuyển vào Thùng rác.'),
      );
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
    // A picture without an address opens as itself.
    if (!b.hasUrl) {
      if (b.isImage) await PictureView.open(context, c, b);
      return;
    }
    final ok = await c.open(b, browser: browser);
    if (!ok && context.mounted) {
      showHandyMessage(
        context,
        tr(context, 'Could not open this link.', 'Chưa mở được link này.'),
      );
    }
  }

  /// Saves a picture the person picks (JPEG, PNG or WebP up to 25 MB) as
  /// an image item in Not sorted, or says it is already saved.
  Future<void> addPhoto(BuildContext context, {String? collectionId}) =>
      run(context, () async {
        final file = await files.importBytes(
          extensions: ['jpg', 'jpeg', 'png', 'webp'],
          maxBytes: MediaRef.maxBytes,
        );
        if (file == null) return;
        final result = await c.addPictures([
          (bytes: file.bytes, name: file.name),
        ], collectionId: collectionId);
        if (!context.mounted) return;
        showHandyMessage(
          context,
          result.added.isNotEmpty
              ? tr(context, 'Picture saved.', 'Đã lưu ảnh.')
              : tr(
                  context,
                  'This picture is already saved.',
                  'Ảnh này đã được lưu.',
                ),
        );
      });

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
