import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';

/// What a save in the app says at the foot of the screen, as the share
/// sheet does on Android: where it went, and, while it is not sorted, the
/// likeliest collections ([suggestCollections]) and "Other…" to put it in
/// with one tap. Ignored, it stays in Not sorted. View opens a single new
/// save; Undo sends what is new to Recently Deleted.
///
/// [before] is the set of ids the library held before the save, so a link
/// that was already there is not offered again. [into] is the collection
/// the save went to (saved from inside a collection), if any.
void showSavedStrip(
  BuildContext context,
  SaveScope scope, {
  required List<Bookmark> saved,
  required Set<String> before,
  String? into,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final fresh = [
    for (final b in saved)
      if (!before.contains(b.id)) b,
  ];
  final l = scope.library;
  final where =
      collectionOf(l, into)?.$1.name ?? tr(context, 'Not sorted', 'Chưa xếp');
  final sortable = into == null && fresh.isNotEmpty && l.collections.isNotEmpty;
  final likely = sortable
      ? suggestCollections(l, fresh.first, take: 3)
      : const <SaveCollection>[];
  final message = fresh.isEmpty
      ? tr(context, 'Already saved.', 'Đã có sẵn.')
      : sortable
      ? (fresh.length == 1
            ? tr(context, 'Saved. Put it in:', 'Đã lưu. Cho vào:')
            : tr(
                context,
                '${fresh.length} links saved. Put them in:',
                'Đã lưu ${fresh.length} link. Cho vào:',
              ))
      : fresh.length == 1
      ? tr(context, 'Saved to $where.', 'Đã lưu vào $where.')
      : tr(
          context,
          '${fresh.length} links saved to $where.',
          'Đã lưu ${fresh.length} link vào $where.',
        );
  final theme = Theme.of(context);
  final ink =
      theme.snackBarTheme.contentTextStyle?.color ??
      theme.colorScheme.onInverseSurface;
  final accent =
      theme.snackBarTheme.actionTextColor ?? theme.colorScheme.inversePrimary;
  final nav = Navigator.of(context);
  final ids = {for (final b in fresh) b.id};
  // The words after a tap are chosen now: the page may be gone by then.
  final vi = tr(context, 'en', 'vi') == 'vi';
  String say(String en, String vn) => vi ? vn : en;

  /// Files every new save; then says where, with Undo back to Not sorted.
  Future<void> file(String id, String name) async {
    messenger.hideCurrentSnackBar();
    try {
      await scope.view.change(
        (l) => l.copyWith(
          bookmarks: [
            for (final b in l.bookmarks)
              ids.contains(b.id)
                  ? b.copyWith(collectionId: id, updatedAt: saveTime())
                  : b,
          ],
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            say(
              'Could not move it. It is still in Not sorted.',
              'Chưa chuyển được. Link vẫn ở Chưa xếp.',
            ),
          ),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        persist: false,
        key: const Key('saved-filed'),
        content: Text(say('Put in $name.', 'Đã cho vào $name.')),
        action: SnackBarAction(
          key: const Key('saved-filed-undo'),
          label: say('Undo', 'Hoàn tác'),
          onPressed: () => scope.view.change(
            (l) => l.copyWith(
              bookmarks: [
                for (final b in l.bookmarks)
                  ids.contains(b.id) ? b.copyWith(collectionId: null) : b,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget chip(Key key, String label, VoidCallback onTap, {int? hue}) =>
      ActionChip(
        key: key,
        avatar: hue == null ? null : HandyDot(hue, size: 10),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        labelStyle: theme.textTheme.labelLarge?.copyWith(color: ink),
        backgroundColor: Colors.transparent,
        side: BorderSide(color: ink.withValues(alpha: .6)),
        onPressed: onTap,
      );

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // Long enough to choose; it goes by itself (Flutter would keep a
        // snack bar with an action until dismissed).
        persist: false,
        duration: Duration(seconds: sortable ? 8 : 4),
        key: const Key('quick-saved'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(message)),
                if (fresh.length == 1)
                  TextButton(
                    key: const Key('quick-view'),
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      textStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      messenger.hideCurrentSnackBar();
                      nav.pushNamed('/bookmark/${fresh.first.id}');
                    },
                    child: Text(tr(context, 'View', 'Xem')),
                  ),
              ],
            ),
            if (sortable)
              Padding(
                padding: const EdgeInsets.only(top: HandySpace.s),
                child: Wrap(
                  key: const Key('saved-put-in'),
                  spacing: HandySpace.s,
                  runSpacing: HandySpace.s,
                  children: [
                    for (final c in likely)
                      chip(
                        Key('saved-into-${c.id}'),
                        c.name,
                        () => file(c.id, c.name),
                        hue: collectionHue(l, c.id),
                      ),
                    chip(
                      const Key('saved-into-other'),
                      tr(context, 'Other…', 'Khác…'),
                      () async {
                        messenger.hideCurrentSnackBar();
                        final id = await pickCollection(
                          context,
                          scope.library,
                          allowInbox: false,
                        );
                        if (id == null || id.isEmpty || !context.mounted)
                          return;
                        final name =
                            collectionOf(scope.library, id)?.$1.name ?? '';
                        await file(id, name);
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
        action: fresh.isEmpty
            ? null
            : SnackBarAction(
                key: const Key('quick-undo'),
                label: tr(context, 'Undo', 'Hoàn tác'),
                onPressed: () =>
                    scope.c.update((l) => moveToTrash(l, [...ids], saveTime())),
              ),
      ),
    );
}
