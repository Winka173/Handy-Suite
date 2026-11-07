import 'dart:io';
import 'package:flutter/services.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../collections/identity.dart';
import '../design/identity.dart';
import '../design/theme.dart';
import '../ui/app_mark.dart';
import '../ui/collection_picker.dart' show collectionHue, collectionTree;
import '../ui/visual.dart' show ReadingShade, SourceFace;
import 'sheet_controller.dart';

/// Shown over the app someone shares from (Android): what is being saved,
/// and where it goes. The share is already saved (in Not sorted, or the
/// collection whose shortcut it came through) before this appears; closing
/// keeps it there.
class ShareSheetApp extends StatefulWidget {
  final SheetController? controller;
  const ShareSheetApp({super.key, this.controller});
  @override
  State<ShareSheetApp> createState() => _ShareSheetAppState();
}

class _ShareSheetAppState extends State<ShareSheetApp> {
  late final c = widget.controller ?? SheetController();
  final _noAds = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    c.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    if (widget.controller == null) c.dispose();
    _noAds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final share = c.share;
    // Nothing is drawn until the share and the person's theme are known
    // (a moment): the app below stays as it is.
    if (share == null && !c.broken) return const SizedBox.shrink();
    return HandyApp(
      brand: bookmarkIdentity,
      themeOverride: bookmarkTheme,
      adsVisible: _noAds,
      app: 'bookmark',
      title: 'Handy Bookmark',
      accent: const Color(0xFF0E7490),
      theme: share?.snapshot.theme ?? 'system',
      locale: share?.snapshot.locale ?? 'system',
      home: _SheetPage(c),
    );
  }
}

class _SheetPage extends StatefulWidget {
  final SheetController c;
  const _SheetPage(this.c);
  @override
  State<_SheetPage> createState() => _SheetPageState();
}

class _SheetPageState extends State<_SheetPage> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final still = MediaQuery.disableAnimationsOf(context);
    final time = still ? Duration.zero : const Duration(milliseconds: 240);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) c.close();
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // The window behind is dimmed by the system (ShareSheetTheme);
            // a tap there closes, keeping the share in Not sorted.
            Positioned.fill(
              child: GestureDetector(
                key: const Key('share-sheet-outside'),
                behavior: HitTestBehavior.opaque,
                onTap: c.close,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                duration: time,
                curve: Curves.easeOutCubic,
                offset: _shown ? Offset.zero : const Offset(0, 1),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 560,
                    maxHeight: MediaQuery.sizeOf(context).height * .88,
                  ),
                  // Once placed, the sheet gives way to a small "Saved in …"
                  // card, as the system's own confirmations do.
                  child: AnimatedSwitcher(
                    duration: time,
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, run) => FadeTransition(
                      opacity: run,
                      child: SizeTransition(
                        sizeFactor: run,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                    ),
                    child: c.done ? _SavedCard(c) : _Sheet(c),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sheet extends StatefulWidget {
  final SheetController c;
  const _Sheet(this.c);
  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  bool _naming = false;
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _addNamed() {
    final where = widget.c.name(_name.text);
    if (where == null) return;
    setState(() => _naming = false);
    widget.c.put(where);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final p = BookmarkPalette.of(context);
    final theme = Theme.of(context);
    final snapshot = c.share?.snapshot;
    final locked = snapshot?.locked ?? false;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        key: const Key('share-sheet'),
        color: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                child: Row(
                  children: [
                    const AppMark(size: 40, radius: 10),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              'Handy Bookmark',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          _SavedIn(c),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('share-sheet-close'),
                      tooltip: tr(context, 'Close', 'Đóng'),
                      onPressed: c.close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (c.share != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _Preview(c),
                ),
              if (c.share != null && locked)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    tr(
                      context,
                      'It is in Not sorted. Unlock the app to sort it.',
                      'Mục đã vào Chưa xếp. Mở khoá app để xếp chỗ.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                  ),
                ),
              if (c.share != null && !locked) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
                  child: Row(
                    // Each keeps its own width and shrinks (with …) only on
                    // a narrow screen with large text.
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Semantics(
                          header: true,
                          child: Text(
                            tr(context, 'Tap where it goes', 'Chạm để cho vào'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ),
                      Flexible(
                        child: TextButton.icon(
                          key: const Key('share-sheet-new'),
                          onPressed: _naming
                              ? null
                              : () => setState(() => _naming = true),
                          icon: const Icon(Icons.add),
                          label: Text(
                            tr(context, 'New collection', 'Bộ sưu tập mới'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: _Places(
                    c,
                    naming: _naming
                        ? _NameField(
                            controller: _name,
                            onDone: _addNamed,
                            onCancel: () => setState(() {
                              _naming = false;
                              _name.clear();
                            }),
                          )
                        : null,
                  ),
                ),
              ],
              if (c.share != null) ...[
                Divider(height: 1, color: p.line),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('share-sheet-discard'),
                      onPressed: c.busy || c.placed != null ? null : c.discard,
                      style: TextButton.styleFrom(
                        foregroundColor: p.muted,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: Text(tr(context, 'Don’t save', 'Không lưu')),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What is being saved: its picture, title, site and a line of what it is.
class _Preview extends StatelessWidget {
  final SheetController c;
  const _Preview(this.c);

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final theme = Theme.of(context);
    final share = c.share!;
    final u = c.link;
    final page = c.page;
    final pictures = share.images.length;
    final title = pictures > 0
        ? (pictures == 1
              ? tr(context, '1 picture', '1 ảnh')
              : tr(context, '$pictures pictures', '$pictures ảnh'))
        : page?.title ??
              _named(share.title) ??
              u?.sourceDomain ??
              share.text.trim();
    final site = pictures > 0 ? null : page?.siteName ?? u?.sourceDomain;
    final more = c.moreLinks;
    final side = MediaQuery.sizeOf(context).width < 360 ? 72.0 : 88.0;
    return Semantics(
      container: true,
      liveRegion: c.reading,
      label: [
        title,
        ?site,
        if (c.reading) tr(context, 'Reading the page', 'Đang đọc trang'),
      ].join('. '),
      excludeSemantics: true,
      child: Container(
        key: const Key('share-sheet-preview'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: p.raised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: side,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: c.reading
                    ? ReadingShade(child: _picture(context, u))
                    : _picture(context, u),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (site != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      more > 0
                          ? '$site · ${tr(context, '+$more more links', '+$more link khác')}'
                          : site,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ],
                  if (page?.description case final d?) ...[
                    const SizedBox(height: 2),
                    Text(
                      d,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A title the sending app gave, unless it only names the app.
  static String? _named(String? v) =>
      v == null || v.trim().isEmpty ? null : v.trim();

  Widget _picture(BuildContext context, UrlCandidate? u) {
    final share = c.share!;
    if (share.images.isNotEmpty) {
      return Image.file(
        File(share.images.first),
        fit: BoxFit.cover,
        cacheWidth: 300,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }
    if (c.picture case final bytes?) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      );
    }
    if (u == null) {
      return ColoredBox(
        color: BookmarkPalette.of(context).sunk,
        child: const Icon(Icons.notes),
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    return SourceFace(
      Bookmark(
        id: '00000000000000000000000000000000',
        originalUrl: u.originalUrl,
        normalizedUrl: u.normalizedUrl,
        canonicalUrl: u.canonicalUrl,
        platform: u.platform,
        contentType: u.contentType,
        sourceDomain: u.sourceDomain,
        title: u.sourceDomain,
        savedAt: now,
        updatedAt: now,
      ),
      compact: true,
    );
  }
}

/// The confirmation after a tap: "Saved", where, and the picture of what
/// was saved. A tap closes it at once.
class _SavedCard extends StatelessWidget {
  final SheetController c;
  const _SavedCard(this.c);

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final theme = Theme.of(context);
    final where = c.placed ?? c.choice;
    final name = c.placeName(where) ?? tr(context, 'Not sorted', 'Chưa xếp');
    final l = c.share?.snapshot.library;
    final hue = switch (where) {
      InCollection(:final id) when l != null => collectionHue(l, id),
      InNewCollection(:final name) => HandyPalette.forKey(name),
      _ => null,
    };
    final images = c.share?.images ?? const [];
    final picture = c.picture;
    return Padding(
      key: const Key('share-saved'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Semantics(
        liveRegion: true,
        button: true,
        label: tr(context, 'Saved in $name', 'Đã lưu vào $name'),
        excludeSemantics: true,
        child: Material(
          color: p.surface,
          elevation: 8,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: c.close,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const AppMark(size: 40, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 18,
                              color: p.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tr(context, 'Saved', 'Đã lưu'),
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (hue != null) ...[
                              HandyDot(hue, size: 9),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                tr(context, 'in $name', 'vào $name'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: hue == null ? p.muted : p.ink,
                                  fontWeight: hue == null
                                      ? null
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (picture != null || images.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox.square(
                        dimension: 48,
                        child: picture != null
                            ? Image.memory(
                                picture,
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                              )
                            : Image.file(
                                File(images.first),
                                fit: BoxFit.cover,
                                cacheWidth: 150,
                                excludeFromSemantics: true,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the share is, in a line under the app's name: "Saved in Not
/// sorted", "Saved in Food"; the place just tapped once it is.
class _SavedIn extends StatelessWidget {
  final SheetController c;
  const _SavedIn(this.c);

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    if (c.broken || c.share == null) {
      return Text(
        tr(context, 'Saved in Not sorted', 'Đã lưu vào Chưa xếp'),
        style: style?.copyWith(color: p.muted),
      );
    }
    final name =
        c.placeName(c.placed ?? c.choice) ??
        tr(context, 'Not sorted', 'Chưa xếp');
    return Semantics(
      liveRegion: true,
      child: Text(
        tr(context, 'Saved in $name', 'Đã lưu vào $name'),
        key: const Key('share-sheet-where'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style?.copyWith(
          color: c.placed == null ? p.muted : p.primary,
          fontWeight: c.placed == null ? null : FontWeight.w600,
        ),
      ),
    );
  }
}

/// Not sorted, collections named here, then the library's collections in
/// its own tree order. One tap puts the share there and closes the sheet;
/// the place it is now carries a tick.
class _Places extends StatelessWidget {
  final SheetController c;
  final Widget? naming;
  const _Places(this.c, {this.naming});

  static bool _same(SheetChoice a, SheetChoice b) => switch ((a, b)) {
    (NotSorted(), NotSorted()) => true,
    (InCollection(id: final x), InCollection(id: final y)) => x == y,
    (InNewCollection(name: final x), InNewCollection(name: final y)) => x == y,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final snapshot = c.share!.snapshot;
    final l = snapshot.library;
    final p = BookmarkPalette.of(context);
    String links(int n) =>
        tr(context, n == 1 ? '1 link' : '$n links', '$n link');
    Widget place(
      SheetChoice where, {
      required Key key,
      required Widget leading,
      required String title,
      String? note,
      double indent = 0,
    }) {
      final placed = c.placed;
      final now = placed == null && _same(where, c.choice);
      final done = placed != null && _same(where, placed);
      return _Place(
        key: key,
        title: title,
        leading: leading,
        indent: indent,
        note: done
            ? tr(context, 'Added', 'Đã cho vào')
            : now
            ? tr(context, 'Here now', 'Đang ở đây')
            : note,
        state: done
            ? _PlaceState.done
            : now
            ? _PlaceState.here
            : _PlaceState.open,
        onTap: c.busy || placed != null ? null : () => c.put(where),
      );
    }

    return ListView(
      key: const Key('share-sheet-places'),
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        ?naming,
        place(
          const NotSorted(),
          key: const Key('share-place-inbox'),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: p.sunk, shape: BoxShape.circle),
            child: Icon(Icons.inbox_outlined, size: 20, color: p.ink),
          ),
          title: tr(context, 'Not sorted', 'Chưa xếp'),
        ),
        for (final name in c.named)
          place(
            InNewCollection(name),
            key: Key('share-place-new-$name'),
            leading: CollectionBadge(
              hue: HandyPalette.forKey(name),
              size: 15,
              always: true,
            ),
            title: name,
            note: tr(context, 'New', 'Mới'),
          ),
        for (final (col, depth) in collectionTree(l))
          place(
            InCollection(col.id),
            key: Key('share-place-${col.id}'),
            indent: depth * 20.0,
            leading: CollectionBadge(
              hue: collectionHue(l, col.id),
              mark: markOf(col.icon),
              size: 15,
              always: true,
            ),
            title: col.name,
            note: links(snapshot.counts[col.id] ?? 0),
          ),
      ],
    );
  }
}

enum _PlaceState { open, here, done }

class _Place extends StatelessWidget {
  final String title;
  final String? note;
  final Widget leading;
  final double indent;
  final _PlaceState state;
  final VoidCallback? onTap;
  const _Place({
    super.key,
    required this.title,
    required this.leading,
    required this.state,
    this.note,
    this.indent = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final done = state == _PlaceState.done;
    return Semantics(
      selected: state != _PlaceState.open,
      child: ListTile(
        onTap: onTap,
        // Still readable while the sheet closes.
        enabled: true,
        tileColor: done ? p.tint : null,
        contentPadding: EdgeInsets.only(left: 20 + indent, right: 20),
        leading: leading,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: done ? const TextStyle(fontWeight: FontWeight.w600) : null,
        ),
        subtitle: note == null
            ? null
            : Text(
                note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: state == _PlaceState.open ? p.muted : p.primary,
                ),
              ),
        trailing: switch (state) {
          _PlaceState.done => Icon(Icons.check_circle, color: p.primary),
          _PlaceState.here => Icon(Icons.check, color: p.primary),
          _PlaceState.open => null,
        },
      ),
    );
  }
}

/// The new collection's name, typed in place at the top of the list.
class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onDone, onCancel;
  const _NameField({
    required this.controller,
    required this.onDone,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final empty = controller.text.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): onCancel,
              },
              child: TextField(
                key: const Key('share-sheet-name'),
                controller: controller,
                autofocus: true,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onDone(),
                decoration: InputDecoration(
                  hintText: tr(context, 'Collection name', 'Tên bộ sưu tập'),
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: tr(context, 'Cancel', 'Huỷ'),
            onPressed: onCancel,
            icon: const Icon(Icons.close),
          ),
          FilledButton.tonal(
            key: const Key('share-sheet-name-done'),
            onPressed: empty ? null : onDone,
            child: Text(tr(context, 'Add', 'Thêm')),
          ),
        ],
      ),
    );
  }
}
