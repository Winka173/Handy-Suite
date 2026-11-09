import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import 'remind_sheet.dart';
import '../ui/collection_picker.dart';
import '../ui/visual.dart';
import '../ui/words.dart';
import 'detail_facts.dart';
import 'picture_view.dart';
import 'rename.dart';
import 'share_item.dart';

/// One saved thing on its own: its picture large, its title, where it is
/// from, and the one thing to do with it (open the original, or view the
/// picture). Favourite, move, rename and share sit in a row under it;
/// copy and the browser wait in the "…" by the title, the library's tools
/// in a folded section below. Nothing here sets a new pin or reminder.
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
      final web = b.hasUrl && !b.isImage && _isWeb(b.originalUrl);
      return Column(
        key: const Key('detail'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The "…" sits on the picture's corner, so the title keeps
          // the whole width.
          if (b.isImage)
            PictureHeader(
              controller: scope.c,
              item: b,
              corner: _More(scope: scope, bookmark: b),
            )
          else
            _LinkHero(
              scope: scope,
              bookmark: b,
              corner: _More(scope: scope, bookmark: b),
            ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: SelectableText(
              title,
              key: const Key('detail-title'),
              style: bookmarkSerif(context, 28),
            ),
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
                // Room for the label at large text on a 320 pt screen.
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () => scope.open(context, b),
              icon: const Icon(Icons.open_in_new),
              label: Text(tr(context, 'Open original', 'Mở bản gốc')),
            ),
          if (web)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.s),
              child: FilledButton.icon(
                key: const Key('detail-reader'),
                style: detailToolStyle(context).copyWith(
                  minimumSize: const WidgetStatePropertyAll(
                    Size.fromHeight(48),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BookmarkRadii.button),
                    ),
                  ),
                ),
                onPressed: () => Navigator.pushNamed(context, '/read/${b.id}'),
                icon: const Icon(Icons.chrome_reader_mode_outlined, size: 20),
                label: Text(tr(context, 'Read', 'Đọc')),
              ),
            ),
          if (b.isImage && b.hasUrl)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.xs),
              child: Center(
                child: TextButton.icon(
                  key: const Key('save-open-original'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => scope.open(context, b),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(tr(context, 'Open its source', 'Mở nguồn')),
                ),
              ),
            ),
          const SizedBox(height: HandySpace.l),
          _Actions(scope: scope, bookmark: b),
          _ReminderLine(scope: scope, bookmark: b),
          DetailFacts(scope: scope, bookmark: b, onClosed: onClosed),
        ],
      );
    },
  );
}

/// Only addresses on the web can be read in the app.
bool _isWeb(String url) {
  final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

/// The "…" on the picture: Share, Copy link and Open in the browser.
class _More extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const _More({required this.scope, required this.bookmark});
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final b = bookmark;
    PopupMenuItem<String> item(String value, IconData icon, String label) =>
        PopupMenuItem<String>(
          key: Key('detail-$value'),
          value: value,
          height: 48,
          child: Row(
            children: [
              Icon(icon, size: 20, color: p.muted),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.ink),
                ),
              ),
            ],
          ),
        );
    return PopupMenuButton<String>(
      key: const Key('detail-more'),
      tooltip: tr(context, 'More', 'Thêm'),
      position: PopupMenuPosition.under,
      padding: EdgeInsets.zero,
      iconSize: 40,
      // A 40px disc on the picture inside a 48px target.
      icon: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.surface.withValues(alpha: .94),
        ),
        child: SizedBox.square(
          dimension: 40,
          child: Icon(Icons.more_horiz, size: 22, color: p.ink),
        ),
      ),
      onSelected: (value) => switch (value) {
        'share-menu' => scope.shareItem(context, b),
        'copy' => copyToClipboard(context, shareableUrl(b)),
        'browser' => scope.open(context, b, browser: true),
        _ => null,
      },
      itemBuilder: (context) => [
        if (b.hasUrl || b.isImage)
          item(
            'share-menu',
            Icons.ios_share_rounded,
            b.isImage
                ? tr(context, 'Share picture', 'Chia sẻ ảnh')
                : tr(context, 'Share', 'Chia sẻ'),
          ),
        if (b.hasUrl) ...[
          item(
            'copy',
            Icons.link_rounded,
            tr(context, 'Copy link', 'Chép link'),
          ),
          if (!b.isImage)
            item(
              'browser',
              Icons.open_in_browser_outlined,
              tr(context, 'Open in the browser', 'Mở bằng trình duyệt'),
            ),
        ],
      ],
    );
  }
}

/// A link's picture at a wide crop, or its source's face when it has none.
class _LinkHero extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  final Widget corner;
  const _LinkHero({
    required this.scope,
    required this.bookmark,
    required this.corner,
  });
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 360),
    child: AspectRatio(
      aspectRatio: 1.6,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ItemPicture(scope.c, bookmark, radius: BookmarkRadii.collection),
          PositionedDirectional(top: 6, end: 6, child: corner),
        ],
      ),
    ),
  );
}

/// Favourite, move, rename and share: round marks with their word under
/// them, each a whole column to tap.
class _Actions extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const _Actions({required this.scope, required this.bookmark});

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
          key: const Key('detail-rename'),
          icon: Icons.drive_file_rename_outline,
          label: tr(context, 'Rename', 'Đổi tên'),
          onTap: () => scope.rename(context, b),
        ),
        // Reads the page again (title, picture, description) when asked.
        if (b.hasUrl && !b.isImage && _isWeb(b.originalUrl))
          RoundAction(
            key: const Key('detail-refresh'),
            icon: Icons.refresh_rounded,
            label: tr(context, 'Refresh', 'Làm mới'),
            onTap: () {
              if (scope.c.fetching.containsKey(b.id)) return;
              scope.run(context, () => scope.c.refreshMetadata(b.id));
            },
          ),
        if (b.hasUrl || b.isImage)
          // Its own context, so an iPad or Mac sheet points at it.
          Builder(
            builder: (context) => RoundAction(
              key: const Key('detail-share'),
              icon: Icons.ios_share_rounded,
              label: tr(context, 'Share', 'Chia sẻ'),
              onTap: () => scope.shareItem(context, b),
            ),
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

/// "Remind me": Off, or when it will remind, with a way to cancel it. A
/// tap opens the choices.
class _ReminderLine extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const _ReminderLine({required this.scope, required this.bookmark});
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final theme = Theme.of(context);
    final at = bookmark.reminderAt == null
        ? null
        : DateTime.tryParse(bookmark.reminderAt!)?.toLocal();
    final now = DateTime.now();
    final past = at != null && !at.isAfter(now);
    final label = at == null
        ? tr(context, 'Remind me · Off', 'Nhắc tôi · Không nhắc')
        : past
        ? tr(
            context,
            'Was due ${RemindChoices.when(context, at, now)}',
            'Đã nhắc lúc ${RemindChoices.when(context, at, now)}',
          )
        : tr(
            context,
            'Reminder: ${RemindChoices.when(context, at, now)}',
            'Nhắc lúc ${RemindChoices.when(context, at, now)}',
          );
    return Padding(
      padding: const EdgeInsets.only(top: HandySpace.m),
      child: Material(
        color: at == null ? Colors.transparent : p.tint,
        borderRadius: BorderRadius.circular(BookmarkRadii.item),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('detail-remind'),
          onTap: () => showRemindSheet(context, scope, bookmark),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.only(left: HandySpace.l),
              child: Row(
                children: [
                  Icon(
                    at == null
                        ? Icons.notifications_none
                        : Icons.notifications_active_outlined,
                    size: 20,
                    color: at == null
                        ? p.muted
                        : theme.brightness == Brightness.dark
                        ? p.ink
                        : p.pressed,
                  ),
                  const SizedBox(width: HandySpace.m),
                  Expanded(
                    child: Text(
                      label,
                      key: const Key('detail-remind-at'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: at == null ? p.muted : p.ink,
                        fontWeight: at == null ? null : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (at != null)
                    IconButton(
                      key: const Key('detail-remind-clear'),
                      tooltip: tr(context, 'Cancel reminder', 'Bỏ hẹn nhắc'),
                      icon: const Icon(Icons.close),
                      onPressed: () => scope.remind(context, bookmark, null),
                    )
                  else
                    const SizedBox(width: HandySpace.l),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
