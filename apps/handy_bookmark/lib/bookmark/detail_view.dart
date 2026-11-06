import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';
import '../ui/visual.dart';
import '../ui/words.dart';
import 'detail_facts.dart';
import 'picture_view.dart';
import 'reminder_sheet.dart';

/// One saved thing on its own: its picture large, its title, where it is
/// from, and the one thing to do with it (open the original, or view the
/// picture). Favourite, move, remind and copy sit in a row under it; the
/// library's tools wait in a folded section below.
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
          title: tr(context, 'This item was deleted.', 'Mục này đã bị xóa.'),
        );
      }
      final theme = Theme.of(context);
      final p = BookmarkPalette.of(context);
      final home = collectionOf(scope.library, b.collectionId);
      final title = b.title.isNotEmpty
          ? b.title
          : b.isImage
          ? tr(context, 'Picture', 'Ảnh')
          : b.sourceDomain;
      return Column(
        key: const Key('detail'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (b.isImage)
            PictureHeader(controller: scope.c, item: b)
          else
            _LinkHero(scope: scope, bookmark: b),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: SelectableText(title, style: bookmarkSerif(context, 28)),
          ),
          const SizedBox(height: HandySpace.s),
          Text.rich(
            TextSpan(
              children: [
                if (home != null) collectionSpan(context, home),
                TextSpan(
                  text: [
                    if (!b.isImage) sourceLine(b),
                    b.isImage
                        ? tr(context, 'Picture', 'Ảnh')
                        : kindName(context, b.contentType),
                    ago(context, b.savedAt),
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
              ],
            ),
            style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
          ),
          const SizedBox(height: 20),
          if (b.isImage)
            FilledButton.icon(
              key: const Key('detail-view-picture'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => PictureView.open(context, scope.c, b),
              icon: const Icon(Icons.fullscreen),
              label: Text(tr(context, 'View picture', 'Xem ảnh')),
            )
          else if (b.hasUrl)
            FilledButton.icon(
              key: const Key('save-open-original'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => scope.open(context, b),
              icon: const Icon(Icons.open_in_new),
              label: Text(tr(context, 'Open original', 'Mở bản gốc')),
            ),
          if (b.hasUrl)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.xs),
              child: Center(
                child: b.isImage
                    ? TextButton.icon(
                        key: const Key('save-open-original'),
                        onPressed: () => scope.open(context, b),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(tr(context, 'Open its source', 'Mở nguồn')),
                      )
                    : TextButton(
                        key: const Key('detail-browser'),
                        onPressed: () => scope.open(context, b, browser: true),
                        child: Text(
                          tr(
                            context,
                            'Open in the browser',
                            'Mở bằng trình duyệt',
                          ),
                        ),
                      ),
              ),
            ),
          const SizedBox(height: HandySpace.l),
          _Actions(scope: scope, bookmark: b),
          if (b.reminderAt != null) _ReminderLine(scope: scope, bookmark: b),
          DetailFacts(scope: scope, bookmark: b, onClosed: onClosed),
        ],
      );
    },
  );
}

/// A link's picture at a wide crop, or its source's face when it has none.
class _LinkHero extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const _LinkHero({required this.scope, required this.bookmark});
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 360),
    child: AspectRatio(
      aspectRatio: 1.6,
      child: ItemPicture(scope.c, bookmark, radius: BookmarkRadii.collection),
    ),
  );
}

/// Favourite, move, remind and copy: round marks with their word under
/// them, each a whole 48px column to tap.
class _Actions extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const _Actions({required this.scope, required this.bookmark});

  Future<void> _remind(BuildContext context) async {
    try {
      final at = await pickReminder(context);
      if (at != null && context.mounted)
        await scope.remind(context, bookmark, at);
    } on FormatException catch (e) {
      if (context.mounted) showHandyMessage(context, errorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RoundAction(
          key: const Key('detail-favorite'),
          icon: b.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
          label: tr(context, 'Favourite', 'Yêu thích'),
          on: b.isFavorite,
          toggle: true,
          onTap: () => scope.toggle(
            context,
            b,
            (x) => x.copyWith(isFavorite: !x.isFavorite),
          ),
        ),
        RoundAction(
          key: const Key('detail-move'),
          icon: Icons.drive_file_move_outline,
          label: tr(context, 'Move', 'Chuyển'),
          onTap: () => scope.move(context, b),
        ),
        RoundAction(
          key: const Key('detail-remind'),
          icon: b.reminderAt == null
              ? Icons.notifications_none_rounded
              : Icons.notifications_active_outlined,
          label: tr(context, 'Remind me', 'Nhắc tôi'),
          on: b.reminderAt != null,
          onTap: () => _remind(context),
        ),
        if (b.hasUrl)
          RoundAction(
            key: const Key('detail-copy'),
            icon: Icons.link_rounded,
            label: tr(context, 'Copy link', 'Chép link'),
            onTap: () => copyToClipboard(context, b.originalUrl),
          ),
      ],
    );
  }
}

/// One round action: a 48px mark on a tone (the hue's tint when on) with
/// its word under it.
class RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool on, toggle;
  final VoidCallback onTap;
  const RoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.on = false,
    this.toggle = false,
  });
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Semantics(
        button: true,
        toggled: toggle ? on : null,
        excludeSemantics: true,
        label: label,
        onTap: onTap,
        child: InkWell(
          borderRadius: BorderRadius.circular(BookmarkRadii.item),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: HandyMotion.of(context, HandyMotion.short),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? p.tint : (dark ? p.raised : p.surface),
                  ),
                  child: Icon(
                    icon,
                    color: on ? (dark ? p.primary : p.pressed) : p.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: p.ink,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// When the reminder is set for, with a way to cancel it.
class _ReminderLine extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const _ReminderLine({required this.scope, required this.bookmark});
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final at = DateTime.parse(bookmark.reminderAt!).toLocal();
    final when =
        '${formatDay(context, at.toIso8601String().substring(0, 10))}, '
        '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(at))}';
    return Padding(
      padding: const EdgeInsets.only(top: HandySpace.m),
      child: Container(
        padding: const EdgeInsets.only(left: HandySpace.l),
        decoration: BoxDecoration(
          color: p.tint,
          borderRadius: BorderRadius.circular(BookmarkRadii.item),
        ),
        child: Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 20,
              color: Theme.of(context).brightness == Brightness.dark
                  ? p.ink
                  : p.pressed,
            ),
            const SizedBox(width: HandySpace.m),
            Expanded(
              child: Text(
                tr(context, 'Reminder: $when', 'Nhắc lúc $when'),
                key: const Key('detail-remind-at'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: p.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              key: const Key('detail-remind-clear'),
              tooltip: tr(context, 'Cancel reminder', 'Bỏ hẹn nhắc'),
              icon: const Icon(Icons.close),
              onPressed: () => scope.remind(context, bookmark, null),
            ),
          ],
        ),
      ),
    );
  }
}
