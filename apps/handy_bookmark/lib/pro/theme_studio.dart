import 'package:handy_ui/kit.dart';
import '../design/looks.dart';
import '../design/theme.dart';
import '../home/home_page.dart';
import '../scope.dart';
import 'entitlements.dart';

/// Every theme, free and Pro, side by side; each one opens a preview of
/// the person's own home in it. Previewing never changes the choice.
class ThemeStudio extends StatelessWidget {
  final SaveScope scope;
  const ThemeStudio({super.key, required this.scope});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen = scope.c.preferences['look'] as String? ?? libraryLook.id;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Themes', 'Giao diện'))),
      body: LayoutBuilder(
        builder: (context, box) {
          final columns = (box.maxWidth / 190).floor().clamp(2, 5);
          final scale = (MediaQuery.textScalerOf(context).scale(14) / 14 - 1)
              .clamp(0.0, 1.5);
          return CustomScrollView(
            key: const Key('looks-grid'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    tr(
                      context,
                      'Try any theme on your own library. Light, dark and following the system stay free.',
                      'Thử mọi giao diện trên chính thư viện của bạn. Sáng, tối và theo hệ thống luôn miễn phí.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 196 + 48 * scale,
                  ),
                  itemCount: allLooks.length,
                  itemBuilder: (context, i) => LookTile(
                    look: allLooks[i],
                    selected: allLooks[i].id == chosen,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LookPreview(scope: scope, start: i),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A theme's card: its own ground, surface, type and action colour drawn
/// from its tokens, with its name, mood and whether it is free.
class LookTile extends StatelessWidget {
  final BookmarkLook look;
  final bool selected;
  final VoidCallback onTap;
  const LookTile({
    super.key,
    required this.look,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final here = BookmarkPalette.of(context);
    final p = look.palette(theme.brightness);
    final name = tr(context, look.en, look.vi);
    return Semantics(
      button: true,
      selected: selected,
      label: '$name, ${look.pro ? 'Pro' : tr(context, 'free', 'miễn phí')}',
      excludeSemantics: true,
      child: Material(
        key: Key('look-${look.id}'),
        color: here.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BookmarkRadii.item),
          side: selected
              ? BorderSide(color: here.primary, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 112,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LookSwatch(palette: p),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _Badge(
                        look.pro ? 'Pro' : tr(context, 'Free', 'Miễn phí'),
                        strong: look.pro,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Text(
                  tr(context, look.tagEn, look.tagVi),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final bool strong;
  const _Badge(this.text, {this.strong = false});
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: strong ? p.primary : p.raised,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: strong ? p.onPrimary : p.ink,
        ),
      ),
    );
  }
}

/// A theme's tokens drawn as a tiny page: its ground, a card in its
/// surface with a title in its face, a line of meta and its action pill.
class LookSwatch extends StatelessWidget {
  final BookmarkPalette palette;
  const LookSwatch({super.key, required this.palette});
  @override
  Widget build(BuildContext context) {
    final p = palette;
    Widget line(double share, Color c) => FractionallySizedBox(
      widthFactor: share,
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
    return ExcludeSemantics(
      child: ColoredBox(
        color: p.canvas,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aa',
                style: TextStyle(
                  fontFamily: handyFontFamily(p.display),
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: p.edges ? Border.all(color: p.line) : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        decoration: BoxDecoration(
                          color: p.tint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            line(.9, p.ink),
                            const SizedBox(height: 5),
                            line(.6, p.muted),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 18,
                        height: 12,
                        decoration: BoxDecoration(
                          color: p.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One theme at a time on the person's real home (their saves, covers
/// and names), swiped through; Apply for free themes or with Pro, and
/// leaving without applying keeps what they had.
class LookPreview extends StatefulWidget {
  final SaveScope scope;
  final int start;
  const LookPreview({super.key, required this.scope, required this.start});
  @override
  State<LookPreview> createState() => _LookPreviewState();
}

class _LookPreviewState extends State<LookPreview> {
  late final pages = PageController(initialPage: widget.start);
  late int at = widget.start;
  final focus = FocusNode();

  @override
  void dispose() {
    pages.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> _apply(BookmarkLook look) async {
    if (look.pro && !await requirePro(context, ProFeature.premiumThemes))
      return;
    final c = widget.scope.c;
    try {
      await c.update((l) => l, prefs: {...c.preferences, 'look': look.id});
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        showHandyMessage(
          context,
          tr(context, 'Could not save the theme.', 'Chưa lưu được giao diện.'),
        );
    }
  }

  void _go(int i) {
    final time = HandyMotion.of(context, HandyMotion.medium);
    // Reduced motion: go straight there.
    time == Duration.zero
        ? pages.jumpToPage(i)
        : pages.animateToPage(i, duration: time, curve: HandyMotion.curve);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final look = allLooks[at];
    final chosen =
        widget.scope.c.preferences['look'] as String? ?? libraryLook.id;
    final pro = hasPro(context);
    final using = look.id == chosen;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Preview', 'Xem trước')),
        actions: [
          IconButton(
            key: const Key('look-prev'),
            tooltip: tr(context, 'Previous theme', 'Giao diện trước'),
            onPressed: at == 0 ? null : () => _go(at - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            key: const Key('look-next'),
            tooltip: tr(context, 'Next theme', 'Giao diện sau'),
            onPressed: at == allLooks.length - 1 ? null : () => _go(at + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: pages,
              itemCount: allLooks.length,
              onPageChanged: (i) => setState(() => at = i),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                child: _PhonePreview(
                  look: allLooks[i],
                  child: SaveHomePage(
                    scope: widget.scope,
                    searchFocus: focus,
                    onAdd: ({bool clipboard = false}) async {},
                    onExport: () {},
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(context, look.en, look.vi),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      _Badge(
                        look.pro ? 'Pro' : tr(context, 'Free', 'Miễn phí'),
                        strong: look.pro,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr(context, look.tagEn, look.tagVi),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('look-apply'),
                    onPressed: using ? null : () => _apply(look),
                    child: Text(
                      using
                          ? tr(context, 'In use', 'Đang dùng')
                          : look.pro && !pro
                          ? tr(context, 'Use with Pro', 'Dùng với Pro')
                          : tr(context, 'Use this theme', 'Dùng giao diện này'),
                    ),
                  ),
                  TextButton(
                    key: const Key('look-keep'),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      tr(
                        context,
                        'Keep my current theme',
                        'Giữ giao diện hiện tại',
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

/// The real home, drawn in [look] at phone size inside a rounded frame;
/// a picture of the screen, so taps inside it do nothing.
class _PhonePreview extends StatelessWidget {
  final BookmarkLook look;
  final Widget child;
  const _PhonePreview({required this.look, required this.child});
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    const size = Size(390, 800);
    return Center(
      child: AspectRatio(
        aspectRatio: size.width / size.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: BookmarkPalette.of(context).control),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: FittedBox(
              child: SizedBox.fromSize(
                size: size,
                child: MediaQuery(
                  data: mq.copyWith(
                    size: size,
                    padding: EdgeInsets.zero,
                    viewPadding: EdgeInsets.zero,
                    viewInsets: EdgeInsets.zero,
                    textScaler: TextScaler.noScaling,
                  ),
                  child: Theme(
                    data: lookTheme(look, Theme.of(context).brightness),
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: HeroMode(enabled: false, child: child),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
