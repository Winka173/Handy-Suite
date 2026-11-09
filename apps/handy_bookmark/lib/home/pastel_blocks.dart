import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';
import '../ui/read_later_ribbon.dart';
import '../ui/visual.dart';
import '../ui/words.dart';

/// A collection's colour as a pale field with the dark of its own hue as
/// ink (pastel look): light, the hue's tint; dark, the hue sunk into the
/// surface with a light ink of the same hue.
({Color field, Color ink, Color mark}) hueField(BuildContext context, int hue) {
  final h = HandyPalette.of(context, hue);
  final p = BookmarkPalette.of(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark
      ? (
          field: Color.lerp(p.surface, h.mark, .32)!,
          ink: Color.lerp(h.mark, Colors.white, .7)!,
          mark: h.mark,
        )
      : (
          // Strong contrast: a fuller field and a deeper ink.
          field: Color.lerp(Colors.white, h.mark, .22)!,
          ink: Color.lerp(h.mark, Colors.black, .6)!,
          mark: h.mark,
        );
}

/// One Home section, straight on the ground (no box around it): its
/// heading with a count and one action, then its items, each its own
/// card or row.
class HomePanel extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry padding;
  const HomePanel({
    super.key,
    required this.title,
    required this.child,
    this.count,
    this.action,
    this.padding = const EdgeInsets.only(top: 20),
  });
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: title),
                          if (count != null)
                            TextSpan(
                              text: '  ${formatFigure(context, '$count')}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: p.muted,
                              ),
                            ),
                        ],
                      ),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                if (action != null)
                  ConstrainedBox(
                    // At the right edge; it shrinks only when space is short.
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * .45,
                    ),
                    child: action!,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

/// The day a reminder falls on, as the shelf names it: tonight or today,
/// tomorrow, the weekend, or the date.
String readLaterDay(BuildContext context, DateTime at, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(at.year, at.month, at.day).difference(today).inDays;
  if (d == 0) {
    return at.hour >= 17
        ? tr(context, 'Tonight', 'Tối nay')
        : tr(context, 'Today', 'Hôm nay');
  }
  if (d == 1) return tr(context, 'Tomorrow', 'Ngày mai');
  if (d < 7 && at.weekday >= DateTime.saturday) {
    return tr(context, 'This weekend', 'Cuối tuần');
  }
  return MaterialLocalizations.of(context).formatMediumDate(at);
}

/// Home's "put aside" shelf: the saves with a read-later reminder still
/// ahead, soonest first, each under the day it is due (Tonight, Tomorrow,
/// This weekend). Hidden when nothing is put aside.
class ReadLaterShelf extends StatelessWidget {
  final SaveScope scope;
  final ValueChanged<Bookmark> onOpen;
  final DateTime? now;

  /// A wide screen: the saves side by side, each under its day.
  final bool across;
  static const shown = 3;
  const ReadLaterShelf({
    super.key,
    required this.scope,
    required this.onOpen,
    this.now,
    this.across = false,
  });

  @override
  Widget build(BuildContext context) {
    final at = now ?? DateTime.now();
    final items = [
      for (final b in scope.library.bookmarks)
        if (!b.isArchived && readLaterAt(b, at) != null)
          (b, readLaterAt(b, at)!),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final loc = MaterialLocalizations.of(context);
    String? lastDay;
    Widget when(DateTime due) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: readLaterDay(context, due, at),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text:
                '  ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(due), alwaysUse24HourFormat: true)}',
            style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
          ),
        ],
      ),
    );
    if (across) {
      return HomePanel(
        key: const Key('read-later'),
        title: tr(context, 'Read later', 'Hẹn đọc'),
        count: items.length,
        child: LayoutBuilder(
          builder: (context, box) {
            const gap = 12.0;
            final width = (box.maxWidth - 2 * gap) / 3;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (b, due) in items.take(shown))
                  SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
                          child: when(due),
                        ),
                        _SaveRow(
                          key: Key('later-${b.id}'),
                          scope: scope,
                          bookmark: b,
                          filled: true,
                          ribbon: due,
                          onTap: () => onOpen(b),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }
    return HomePanel(
      key: const Key('read-later'),
      title: tr(context, 'Read later', 'Hẹn đọc'),
      count: items.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (k, (b, due)) in items.take(shown).indexed) ...[
            if (readLaterDay(context, due, at) != lastDay)
              Padding(
                // A day's name opens its group, with air above the last.
                padding: EdgeInsets.fromLTRB(2, k == 0 ? 4 : 16, 2, 8),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: lastDay = readLaterDay(context, due, at),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text:
                            '  ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(due), alwaysUse24HourFormat: true)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: p.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
            _SaveRow(
              key: Key('later-${b.id}'),
              scope: scope,
              bookmark: b,
              filled: true,
              ribbon: due,
              onTap: () => onOpen(b),
            ),
          ],
        ],
      ),
    );
  }
}

/// A collection to file into, in its own pale field and ink; without a
/// collection it is the neutral "Other…".
class FileChip extends StatelessWidget {
  final SaveCollection? collection;
  final int hue;
  final VoidCallback onTap;
  const FileChip({
    super.key,
    this.collection,
    this.hue = 0,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final f = collection == null ? null : hueField(context, hue);
    // A 32 pt chip inside a 48 pt target.
    return ActionChip(
      onPressed: onTap,
      backgroundColor: f?.field ?? p.raised,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      label: Text(
        collection?.name ?? tr(context, 'Other…', 'Khác…'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: f?.ink ?? p.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One save as a row: its picture (52, or 56 on the shelf), title and
/// where it is, with an optional line under it.
class _SaveRow extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  final VoidCallback onTap;
  final bool filled;
  final DateTime? ribbon;
  const _SaveRow({
    super.key,
    required this.scope,
    required this.bookmark,
    required this.onTap,
    this.filled = false,
    this.ribbon,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final b = bookmark;
    final home = collectionOf(scope.library, b.collectionId);
    final size = filled ? 56.0 : 52.0;
    return Material(
      color: filled ? p.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(BookmarkRadii.item),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(
            filled ? 8 : 0,
          ).add(EdgeInsets.symmetric(vertical: filled ? 0 : 10)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ItemPicture(scope.c, b, compact: true),
                    if (ribbon != null)
                      Positioned(
                        top: 0,
                        left: 6,
                        child: ReadLaterRibbon(ribbon!, small: true),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title.isEmpty ? b.sourceDomain : b.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (home != null) collectionSpan(context, home),
                          TextSpan(
                            text: home == null
                                ? [
                                    tr(context, 'Not sorted', 'Chưa xếp'),
                                    if (!b.isImage) sourceLine(b),
                                  ].join(' · ')
                                : (b.isImage
                                      ? tr(context, 'Picture', 'Ảnh')
                                      : sourceLine(b)),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
