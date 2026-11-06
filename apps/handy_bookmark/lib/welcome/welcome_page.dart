import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../data/import_export.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';
import 'filing.dart';
import 'first_save.dart';
import 'scenes.dart';

/// The preference that records a finished (or skipped) guide. It lives with
/// the library, so a restored backup does not show the guide again.
const guideDoneKey = 'guideDone';

/// Whether to open the guide on start: never finished, and nothing saved
/// or recently deleted (someone who already has links never sees it unasked).
bool shouldShowGuide(SaveScope scope) =>
    scope.c.preferences[guideDoneKey] != true &&
    scope.library.bookmarks.isEmpty &&
    scope.library.trash.isEmpty;

/// The first run: why, how, a real first save, and where it went. Four
/// steps, Skip on every one; replayable from Settings (`/welcome`).
class WelcomePage extends StatefulWidget {
  final SaveScope scope;
  const WelcomePage({super.key, required this.scope});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  static const steps = 4;
  int step = 0;

  /// Items that existed when step three opened; anything new is the save.
  Set<String>? before;
  String? savedId;
  final titleFocus = FocusNode(debugLabel: 'welcome-title');
  SaveScope get scope => widget.scope;

  @override
  void initState() {
    super.initState();
    scope.c.addListener(_watch);
  }

  @override
  void dispose() {
    scope.c.removeListener(_watch);
    titleFocus.dispose();
    unawaited(_markDone());
    super.dispose();
  }

  void _watch() {
    if (!mounted) return;
    if (step == 2 && before != null && scope.c.library != null) {
      final fresh = [
        for (final b in scope.library.bookmarks)
          if (!before!.contains(b.id)) b,
      ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      if (fresh.isNotEmpty) return _landed(fresh.first);
    }
    setState(() {});
  }

  void _landed(Bookmark b) {
    if (step != 2) return;
    savedId = b.id;
    if (!kIsWeb) HapticFeedback.lightImpact();
    _go(3);
  }

  void _go(int next) {
    setState(() {
      step = next;
      if (next == 2) before = {for (final b in scope.library.bookmarks) b.id};
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) titleFocus.requestFocus();
    });
  }

  Future<void> _markDone() async {
    if (scope.c.preferences[guideDoneKey] == true) return;
    try {
      await scope.c.update(
        (l) => l,
        prefs: {...scope.c.preferences, guideDoneKey: true},
      );
    } catch (_) {
      // Not remembered: the guide may show again on an empty library.
    }
  }

  bool leaving = false;

  /// Leaves the guide. A plain pop: the page's own PopScope turns system
  /// back into a step back, so maybePop would only come round to here.
  Future<void> _finish() async {
    if (leaving) return;
    leaving = true;
    await _markDone();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _import() async {
    await scope.importLinks(context);
    if (mounted && scope.library.bookmarks.isNotEmpty) await _finish();
  }

  void _back() => step == 0 ? _finish() : _go(step - 1);

  @override
  Widget build(BuildContext context) {
    final saved = savedId == null ? null : scope.find(savedId!);
    if (step == 3 && saved == null) {
      // The save was undone or deleted: wait for another one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && step == 3) _go(2);
      });
    }
    final page = _page(context, saved);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _back,
          if (page.primary != null)
            const SingleActivator(LogicalKeyboardKey.enter): page.onPrimary!,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: _bar(context),
            bottomNavigationBar: MediaQuery.sizeOf(context).width < 700
                ? HandyBottomBar(child: _actions(context, page))
                : null,
            body: LayoutBuilder(
              builder: (context, box) => box.maxWidth < 700
                  ? _narrow(context, page, box.maxWidth)
                  : _wide(context, page),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _bar(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: SafeArea(
        bottom: false,
        // Lined up with the content's column on wide screens.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040 + 2 * 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: HandySpace.s),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: step == 0
                        ? null
                        : IconButton(
                            key: const Key('welcome-back'),
                            tooltip: tr(context, 'Back', 'Quay lại'),
                            onPressed: _back,
                            icon: const Icon(Icons.arrow_back),
                          ),
                  ),
                  Expanded(
                    child: Semantics(
                      label: tr(
                        context,
                        'Step ${step + 1} of $steps',
                        'Bước ${step + 1} trên $steps',
                      ),
                      child: ExcludeSemantics(
                        child: Row(
                          children: [
                            for (var i = 0; i < steps; i++) ...[
                              if (i > 0) const SizedBox(width: HandySpace.xs),
                              Expanded(
                                child: AnimatedContainer(
                                  duration: HandyMotion.of(context),
                                  height: 3,
                                  color: i <= step
                                      ? theme.colorScheme.onSurface
                                      : c.rule,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 88,
                    child: step == steps - 1
                        ? null
                        : TextButton(
                            key: const Key('welcome-skip'),
                            onPressed: _finish,
                            child: Text(tr(context, 'Skip', 'Bỏ qua')),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _Page _page(BuildContext context, Bookmark? saved) {
    final platform = defaultTargetPlatform;
    final mac = platform == TargetPlatform.macOS;
    switch (step) {
      case 0:
        return _Page(
          title: tr(
            context,
            'Keep it once. Find it again.',
            'Lưu một lần. Tìm lại được ngay.',
          ),
          body: tr(
            context,
            'Links from TikTok, YouTube, Shopee or the web, and the screenshots you take, kept together on this device.',
            'Link từ TikTok, YouTube, Shopee hay trình duyệt, cùng ảnh chụp màn hình, được giữ chung một chỗ trên máy này.',
          ),
          scene: PileScene(today: DateTime.now()),
          primary: tr(context, 'Show me how', 'Chỉ tôi cách lưu'),
          onPrimary: () => _go(1),
          secondary: TextButton(
            key: const Key('welcome-import'),
            onPressed: _import,
            child: Text(
              tr(
                context,
                'I have links in another app',
                'Tôi có link ở app khác',
              ),
            ),
          ),
        );
      case 1:
        return _Page(
          title: tr(context, 'Save from any app.', 'Lưu từ bất kỳ app nào.'),
          body: canReceiveShares
              ? tr(
                      context,
                      'In TikTok, YouTube, Shopee or your browser, tap Share, then Handy Bookmark. You don\'t have to open this app.',
                      'Ở TikTok, YouTube, Shopee hay trình duyệt, bấm Chia sẻ rồi chọn Handy Bookmark. Không cần mở app này.',
                    ) +
                    (platform == TargetPlatform.iOS
                        ? tr(
                            context,
                            ' If it isn\'t in the row, look under More.',
                            ' Nếu không thấy trong hàng, tìm ở mục Thêm.',
                          )
                        : '')
              : tr(
                  context,
                  'Copy a link anywhere, then press ${mac ? '⌘' : 'Ctrl'} V here. It lands in Not sorted.',
                  'Chép link ở bất kỳ đâu rồi bấm ${mac ? '⌘' : 'Ctrl'} V ở đây. Link sẽ nằm trong Chưa xếp.',
                ),
          scene: const ShareScene(),
          primary: tr(context, 'Try it now', 'Thử ngay'),
          onPrimary: () => _go(2),
        );
      case 2:
        return _Page(
          title: tr(context, 'Save your first one.', 'Lưu món đầu tiên.'),
          body: tr(
            context,
            'It stays in your library on this device. Nothing is sent anywhere.',
            'Nó sẽ ở lại trong thư viện trên máy này. Không gửi đi đâu cả.',
          ),
          scene: Tray(heading: tr(context, 'Not sorted', 'Chưa xếp')),
          sceneAfter: true,
          extra: FirstSave(scope: scope, onSaved: _landed),
          secondary: TextButton(
            key: const Key('welcome-later'),
            onPressed: _finish,
            child: Text(tr(context, 'Later', 'Để sau')),
          ),
        );
      default:
        final where = collectionOf(scope.library, saved?.collectionId);
        return _Page(
          title: where == null
              ? tr(
                  context,
                  'Saved. It\'s in Not sorted.',
                  'Đã lưu. Nó đang ở Chưa xếp.',
                )
              : tr(context, 'Saved and filed.', 'Đã lưu và xếp chỗ.'),
          body: where == null
              ? tr(
                  context,
                  'Everything you save lands here first. Give it a place now, or whenever you like.',
                  'Mọi thứ bạn lưu đều vào đây trước. Xếp chỗ cho nó ngay, hoặc lúc nào tiện.',
                )
              : tr(
                  context,
                  'Find it under ${where.$1.name}, or search any word of its title.',
                  'Tìm nó trong ${where.$1.name}, hoặc gõ một chữ trong tiêu đề để tìm.',
                ),
          scene: Tray(
            heading: where?.$1.name ?? tr(context, 'Not sorted', 'Chưa xếp'),
            child: saved == null
                ? null
                : SavedClipping(
                    key: ValueKey(saved.id),
                    scope: scope,
                    bookmark: saved,
                  ),
          ),
          extra: saved == null
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'Put it in', 'Xếp vào'),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: HandySpace.s),
                    Filing(scope: scope, bookmark: saved),
                  ],
                ),
          primary: tr(context, 'Go to my library', 'Vào thư viện'),
          onPrimary: _finish,
        );
    }
  }

  Widget _title(BuildContext context, _Page p) => Focus(
    focusNode: titleFocus,
    child: Semantics(
      header: true,
      child: HandySwap(
        child: Text(
          p.title,
          key: ValueKey(p.title),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    ),
  );

  List<Widget> _words(BuildContext context, _Page p) => [
    _title(context, p),
    const SizedBox(height: HandySpace.m),
    Text(p.body, style: Theme.of(context).textTheme.bodyLarge),
    if (p.extra != null) ...[const SizedBox(height: HandySpace.xl), p.extra!],
  ];

  Widget _scene(Widget scene, double height) =>
      scene is Tray ? scene : SizedBox(height: height, child: scene);

  Widget _narrow(BuildContext context, _Page p, double width) {
    // Drawings fill the column's width (their canvas is 320 × 280).
    final scene = _scene(
      p.scene,
      math.min((width - 2 * HandySpace.l) * 280 / 320, 340),
    );
    return SingleChildScrollView(
      key: ValueKey('welcome-step-$step'),
      padding: const EdgeInsets.fromLTRB(
        HandySpace.l,
        HandySpace.l,
        HandySpace.l,
        HandySpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!p.sceneAfter) ...[scene, const SizedBox(height: HandySpace.xl)],
          ..._words(context, p),
          if (p.sceneAfter) ...[const SizedBox(height: HandySpace.xl), scene],
        ],
      ),
    );
  }

  /// Words and actions on the left, the drawing on the right, the pair
  /// centred in the window so no band of it is left empty.
  Widget _wide(BuildContext context, _Page p) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      key: ValueKey('welcome-step-$step'),
      padding: const EdgeInsets.all(HandySpace.xl),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: math.max(0, box.maxHeight - 2 * HandySpace.xl - 56),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._words(context, p),
                      const SizedBox(height: HandySpace.xl),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _actions(context, p),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                Expanded(flex: 6, child: _scene(p.scene, 400)),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _actions(BuildContext context, _Page p) => Wrap(
    spacing: HandySpace.m,
    runSpacing: HandySpace.s,
    crossAxisAlignment: WrapCrossAlignment.center,
    alignment: WrapAlignment.end,
    children: [
      ?p.secondary,
      if (p.primary != null)
        FilledButton(
          key: Key('welcome-next-$step'),
          onPressed: p.onPrimary,
          child: Text(p.primary!),
        ),
    ],
  );
}

class _Page {
  final String title, body;
  final Widget scene;

  /// The scene follows the words (the step's controls come first).
  final bool sceneAfter;
  final Widget? extra, secondary;
  final String? primary;
  final VoidCallback? onPrimary;
  const _Page({
    required this.title,
    required this.body,
    required this.scene,
    this.sceneAfter = false,
    this.extra,
    this.secondary,
    this.primary,
    this.onPrimary,
  });
}
