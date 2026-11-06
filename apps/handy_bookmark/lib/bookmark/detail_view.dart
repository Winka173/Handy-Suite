import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../links/recall_link.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'detail_facts.dart';
import 'picture_view.dart';
import 'reminder_sheet.dart';

/// One link: what it is, and opening it where it came from. Flags, place,
/// reminder and the page's own details follow.
class DetailView extends StatelessWidget {
  final SaveScope scope;
  final String id;
  final VoidCallback onClosed;
  const DetailView({
    super.key,
    required this.scope,
    required this.id,
    required this.onClosed,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.c,
    builder: (context, _) {
      final b = scope.find(id);
      if (b == null) {
        return HandyEmpty(
          title: tr(context, 'This link was deleted.', 'Link này đã bị xóa.'),
        );
      }
      final theme = Theme.of(context);
      final c = HandyColors.of(context);
      Widget flag(
        String key,
        IconData on,
        IconData off,
        String label,
        bool value,
        Bookmark Function(Bookmark) flip,
      ) => Expanded(
        // Four equal switches in one row: icon over word, the state in ink.
        child: Semantics(
          toggled: value,
          child: InkWell(
            key: Key('detail-$key'),
            borderRadius: BorderRadius.circular(HandyRadius.control),
            onTap: () => scope.toggle(context, b, flip),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: HandySpace.s),
              child: Column(
                children: [
                  Icon(value ? on : off, color: value ? null : c.muted),
                  const SizedBox(height: HandySpace.xs),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: value ? null : c.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return Column(
        key: const Key('detail'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (b.isImage)
            PictureHeader(controller: scope.c, item: b)
          else
            LayoutBuilder(
              builder: (context, box) =>
                  LinkThumb(scope.c, b, size: box.maxWidth, height: 180),
            ),
          const SizedBox(height: HandySpace.l),
          Semantics(
            header: true,
            child: SelectableText(
              b.title.isNotEmpty
                  ? b.title
                  : b.isImage
                  ? tr(context, 'Picture', 'Ảnh')
                  : b.sourceDomain,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: HandySpace.xs),
          Text(
            [
              sourceLine(b),
              kindName(context, b.contentType),
              ago(context, b.savedAt),
            ].where((s) => s.isNotEmpty).join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
          ),
          const SizedBox(height: HandySpace.l),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              if (b.isImage)
                FilledButton.icon(
                  key: const Key('detail-view-picture'),
                  onPressed: () => PictureView.open(context, scope.c, b),
                  icon: const Icon(Icons.fullscreen),
                  label: Text(tr(context, 'View picture', 'Xem ảnh')),
                ),
              if (b.hasUrl && !b.isImage)
                FilledButton.icon(
                  key: const Key('save-open-original'),
                  onPressed: () => scope.open(context, b),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(tr(context, 'Open original', 'Mở bản gốc')),
                ),
              if (b.hasUrl && b.isImage)
                OutlinedButton.icon(
                  key: const Key('save-open-original'),
                  onPressed: () => scope.open(context, b),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(tr(context, 'Open its source', 'Mở nguồn')),
                ),
              if (b.hasUrl && !b.isImage)
                OutlinedButton(
                  key: const Key('detail-browser'),
                  onPressed: () => scope.open(context, b, browser: true),
                  child: Text(
                    tr(context, 'In the browser', 'Bằng trình duyệt'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: HandySpace.l),
          Row(
            children: [
              flag(
                'favorite',
                Icons.star,
                Icons.star_outline,
                tr(context, 'Favourite', 'Yêu thích'),
                b.isFavorite,
                (x) => x.copyWith(isFavorite: !x.isFavorite),
              ),
              flag(
                'pin',
                Icons.push_pin,
                Icons.push_pin_outlined,
                tr(context, 'Pin', 'Ghim'),
                b.isPinned,
                (x) => x.copyWith(isPinned: !x.isPinned),
              ),
              flag(
                'read',
                Icons.done_all,
                Icons.done,
                tr(context, 'Read', 'Đã đọc'),
                b.isRead,
                (x) => x.copyWith(isRead: !x.isRead),
              ),
              flag(
                'archive',
                Icons.archive,
                Icons.archive_outlined,
                tr(context, 'Archive', 'Lưu trữ'),
                b.isArchived,
                (x) => x.copyWith(isArchived: !x.isArchived),
              ),
            ],
          ),
          HandyLabel(tr(context, 'Where it is kept', 'Nằm ở đâu')),
          HandyGroup(
            children: [
              ListTile(
                key: const Key('detail-move'),
                leading: const Icon(Icons.folder_outlined),
                title: Text(
                  scope.library.collections
                          .where((x) => x.id == b.collectionId)
                          .firstOrNull
                          ?.name ??
                      tr(context, 'Not sorted', 'Chưa xếp'),
                ),
                trailing: Text(
                  tr(context, 'Move', 'Chuyển'),
                  style: theme.textTheme.bodyMedium,
                ),
                onTap: () => scope.move(context, b),
              ),
              ListTile(
                key: const Key('detail-remind'),
                leading: const Icon(Icons.notifications_none),
                title: Text(
                  b.reminderAt == null
                      ? tr(context, 'No reminder', 'Chưa hẹn nhắc')
                      : '${formatDay(context, DateTime.parse(b.reminderAt!).toLocal().toIso8601String().substring(0, 10))} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(DateTime.parse(b.reminderAt!).toLocal()))}',
                ),
                trailing: b.reminderAt == null
                    ? Text(
                        tr(context, 'Remind me', 'Nhắc tôi'),
                        style: theme.textTheme.bodyMedium,
                      )
                    : IconButton(
                        key: const Key('detail-remind-clear'),
                        tooltip: tr(context, 'Cancel reminder', 'Bỏ hẹn nhắc'),
                        icon: const Icon(Icons.close),
                        onPressed: () => scope.remind(context, b, null),
                      ),
                onTap: () async {
                  try {
                    final at = await pickReminder(context);
                    if (at != null && context.mounted)
                      await scope.remind(context, b, at);
                  } on FormatException catch (e) {
                    if (context.mounted)
                      showHandyMessage(context, errorText(context, e));
                  }
                },
              ),
              if (canHandOff)
                ListTile(
                  key: const Key('detail-recall'),
                  leading: const Icon(Icons.style_outlined),
                  title: Text(
                    tr(
                      context,
                      'Make a study card in Handy Recall',
                      'Tạo thẻ ôn trong Handy Recall',
                    ),
                  ),
                  onTap: () => sendToRecall(context, b),
                ),
            ],
          ),
          DetailFacts(scope: scope, bookmark: b, onClosed: onClosed),
        ],
      );
    },
  );
}
