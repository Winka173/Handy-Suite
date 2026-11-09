import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../home/pastel_blocks.dart';
import '../ui/read_later_ribbon.dart';
import '../ui/app_mark.dart';

/// The pictures of How to use: small pieces of a screen drawn in the
/// app's own colours (never a photo of one), each showing the one place a
/// step is about, ringed.

/// A white card with an optional title bar, like a cut-out of a screen.
class MockCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  const MockCard({super.key, this.title, this.trailing, required this.child});
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    return ExcludeSemantics(
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: p.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        textAlign: trailing == null
                            ? TextAlign.start
                            : TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            Padding(padding: const EdgeInsets.all(14), child: child),
          ],
        ),
      ),
    );
  }
}

/// A ring around the place to tap.
class Ringed extends StatelessWidget {
  final Widget child;
  final double radius;
  const Ringed({super.key, required this.child, this.radius = 14});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius + 3),
      border: Border.all(
        color: BookmarkPalette.of(context).primary,
        width: 2.5,
      ),
    ),
    child: child,
  );
}

/// One app in a share row: a rounded square and its name.
Widget _app(
  BuildContext context,
  IconData? icon,
  String? label, {
  bool ours = false,
}) {
  final p = BookmarkPalette.of(context);
  final face = ours
      ? const AppMark(size: 46, radius: 12)
      : Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: p.line.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: icon == null ? null : Icon(icon, size: 22, color: p.muted),
        );
  return SizedBox(
    width: 66,
    child: Column(
      children: [
        ours ? Ringed(child: face) : face,
        const SizedBox(height: 4),
        if (label != null)
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: ours ? FontWeight.w700 : FontWeight.w400,
              color: ours ? p.primary : p.muted,
            ),
          ),
      ],
    ),
  );
}

/// The phone's share sheet, Handy Bookmark among the apps.
class MockShareRow extends StatelessWidget {
  /// Where Handy Bookmark sits: first (pinned or a favourite) or past the
  /// usual apps.
  final bool first;
  const MockShareRow({super.key, this.first = false});
  @override
  Widget build(BuildContext context) {
    final ours = _app(context, Icons.bookmark, 'Handy Bookmark', ours: true);
    final others = [
      _app(
        context,
        Icons.chat_bubble_outline,
        tr(context, 'Messages', 'Tin nhắn'),
      ),
      _app(context, Icons.mail_outline, 'Email'),
      _app(
        context,
        Icons.sticky_note_2_outlined,
        tr(context, 'Notes', 'Ghi chú'),
      ),
    ];
    return MockCard(
      title: tr(context, 'Share to', 'Chia sẻ tới'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: first
            ? [ours, ...others]
            : [...others.take(2), ours, _app(context, Icons.more_horiz, '')],
      ),
    );
  }
}

/// iOS: the Apps list in Edit, Handy Bookmark among Favorites.
class MockFavorites extends StatelessWidget {
  const MockFavorites({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    return MockCard(
      title: tr(context, 'Apps', 'Ứng dụng'),
      trailing: Text(
        tr(context, 'Done', 'Xong'),
        style: theme.textTheme.labelLarge?.copyWith(color: p.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'Favorites', 'Mục ưa thích'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Ringed(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: p.tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.remove_circle, color: p.danger, size: 20),
                  const SizedBox(width: 10),
                  const AppMark(size: 28, radius: 8),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Handy Bookmark',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.primary,
                      ),
                    ),
                  ),
                  Icon(Icons.drag_handle, color: p.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Android: Handy Bookmark held down, with Pin in its menu.
class MockPin extends StatelessWidget {
  const MockPin({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    return MockCard(
      child: Row(
        children: [
          _app(context, Icons.bookmark, 'Handy Bookmark', ours: true),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Color(0x22000000), blurRadius: 10),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Ringed(
                    radius: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Icon(Icons.push_pin_outlined, size: 18, color: p.ink),
                          const SizedBox(width: 8),
                          Text(
                            tr(context, 'Pin', 'Ghim'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(11),
                    child: Text(
                      tr(context, 'App info', 'Thông tin ứng dụng'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Home's Quick Save field and its +.
class MockQuickSave extends StatelessWidget {
  final bool ringPlus;
  const MockQuickSave({super.key, this.ringPlus = false});
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final field = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ringPlus ? p.line : p.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.link, size: 18, color: p.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ringPlus
                  ? tr(context, 'Paste a link…', 'Dán link…')
                  : 'youtu.be/…',
              maxLines: 1,
              style: TextStyle(color: ringPlus ? p.muted : p.ink),
            ),
          ),
          Icon(Icons.content_paste_rounded, size: 18, color: p.muted),
        ],
      ),
    );
    final button = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: p.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: ringPlus
          ? Icon(Icons.add, color: p.onPrimary)
          : Text(
              tr(context, 'Save', 'Lưu'),
              style: TextStyle(color: p.onPrimary, fontWeight: FontWeight.w700),
            ),
    );
    return MockCard(
      child: Row(
        children: [
          Expanded(child: field),
          const SizedBox(width: 8),
          Ringed(child: ringPlus ? button : SizedBox(width: 56, child: button)),
        ],
      ),
    );
  }
}

/// A row of Not sorted with its collections as chips; the first ringed.
class MockPutIn extends StatelessWidget {
  const MockPutIn({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    Widget chip(String name, int hue) {
      final f = hueField(context, hue);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: f.field,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          name,
          style: theme.textTheme.labelMedium?.copyWith(
            color: f.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return MockCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.play_circle_outline, color: p.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'Beef phở at home', 'Phở bò tại nhà'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'youtube.com',
                  style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Ringed(
                      radius: 999,
                      child: chip(tr(context, 'Recipes', 'Công thức'), 0),
                    ),
                    chip(tr(context, 'Trips', 'Du lịch'), 1),
                    chip(tr(context, 'Other…', 'Khác…'), 7),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Home's Read later: one save under Tomorrow, its ribbon on the picture.
class MockReadLater extends StatelessWidget {
  const MockReadLater({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    return MockCard(
      title: tr(context, 'Read later', 'Hẹn đọc'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: tr(context, 'Tomorrow', 'Ngày mai'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: '  09:00',
                  style: TextStyle(color: p.muted),
                ),
              ],
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Ringed(
                radius: 10,
                child: SizedBox.square(
                  dimension: 44,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: p.tint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 6,
                        child: ReadLaterRibbon(
                          DateTime.now().add(const Duration(days: 1)),
                          small: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(
                    context,
                    'Best season for Hà Giang',
                    'Mùa đẹp nhất để đi Hà Giang',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A row of chips; one is ringed.
class MockChips extends StatelessWidget {
  final List<(IconData?, String)> chips;
  final int ringed;
  final String? title;
  const MockChips({
    super.key,
    required this.chips,
    this.ringed = 0,
    this.title,
  });
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    Widget chip((IconData?, String) c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.line.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.$1 != null) ...[
            Icon(c.$1, size: 16, color: p.ink),
            const SizedBox(width: 4),
          ],
          Text(c.$2, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
    return MockCard(
      title: title,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (i, c) in chips.indexed)
            i == ringed ? Ringed(radius: 999, child: chip(c)) : chip(c),
        ],
      ),
    );
  }
}

/// A row of settings-like lines with an icon, one ringed.
class MockRows extends StatelessWidget {
  final List<(IconData, String)> rows;
  final int ringed;
  final String? title;
  const MockRows({super.key, required this.rows, this.ringed = 0, this.title});
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    Widget row((IconData, String) r) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        children: [
          Icon(r.$1, size: 20, color: p.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(r.$2, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Icon(Icons.chevron_right, size: 18, color: p.muted),
        ],
      ),
    );
    return MockCard(
      title: title,
      child: Column(
        children: [
          for (final (i, r) in rows.indexed)
            i == ringed ? Ringed(radius: 8, child: row(r)) : row(r),
        ],
      ),
    );
  }
}

/// Focus: a card with Later and Done under it.
class MockFocus extends StatelessWidget {
  const MockFocus({super.key});
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    Widget round(IconData icon, String label, Color fill, Color ink) => Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: ink),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
    return MockCard(
      child: Column(
        children: [
          Container(
            height: 72,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tr(context, 'A café by the lake', 'Quán cà phê view hồ'),
              style: bookmarkSerif(context, 20),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              round(
                Icons.arrow_back,
                tr(context, 'Later', 'Để sau'),
                p.ink,
                p.surface,
              ),
              round(
                Icons.arrow_forward,
                tr(context, 'Done', 'Xong'),
                p.primary,
                p.onPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
