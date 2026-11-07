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
/// and where it goes. The share is already saved (in Not sorted) before
/// this appears; closing keeps it there.
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
                  child: _Sheet(c),
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
    if (_name.text.trim().isEmpty) return;
    widget.c.name(_name.text);
    _name.clear();
    setState(() => _naming = false);
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
                          Text(
                            c.broken
                                ? tr(
                                    context,
                                    'Saved. It shows in Not sorted.',
                                    'Đã lưu. Mục nằm ở Chưa xếp.',
                                  )
                                : tr(
                                    context,
                                    'Saved · choose where it goes',
                                    'Đã lưu · chọn chỗ cho nó',
                                  ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: p.muted,
                            ),
                          ),
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
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            tr(context, 'Save to', 'Lưu vào'),
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ),
                      Flexible(
                        flex: 2,
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
              Divider(height: 1, color: p.line),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
                child: Row(
                  children: [
                    if (c.share != null)
                      Flexible(
                        child: TextButton(
                          key: const Key('share-sheet-discard'),
                          onPressed: c.busy ? null : c.discard,
                          style: TextButton.styleFrom(foregroundColor: p.muted),
                          child: Text(
                            tr(context, 'Don’t save', 'Không lưu'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      key: const Key('share-sheet-save'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(96, 48),
                      ),
                      onPressed: c.busy
                          ? null
                          : (c.share == null ? c.close : c.save),
                      icon: const Icon(Icons.bookmark),
                      label: Text(
                        c.share == null || locked
                            ? tr(context, 'Done', 'Xong')
                            : tr(context, 'Save', 'Lưu'),
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

/// Not sorted, collections named here, then the library's collections in
/// its own tree order: one choice.
class _Places extends StatelessWidget {
  final SheetController c;
  final Widget? naming;
  const _Places(this.c, {this.naming});

  String _key(SheetChoice v) => switch (v) {
    NotSorted() => '',
    InCollection(:final id) => 'c:$id',
    InNewCollection(:final name) => 'n:$name',
  };

  @override
  Widget build(BuildContext context) {
    final snapshot = c.share!.snapshot;
    final l = snapshot.library;
    final p = BookmarkPalette.of(context);
    String links(int n) =>
        tr(context, n == 1 ? '1 link' : '$n links', '$n link');
    return RadioGroup<String>(
      groupValue: _key(c.choice),
      onChanged: (v) {
        if (v == null) return;
        c.choose(
          v.isEmpty
              ? const NotSorted()
              : v.startsWith('c:')
              ? InCollection(v.substring(2))
              : InNewCollection(v.substring(2)),
        );
      },
      child: ListView(
        key: const Key('share-sheet-places'),
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          ?naming,
          _Place(
            key: const Key('share-place-inbox'),
            value: '',
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: p.sunk, shape: BoxShape.circle),
              child: Icon(Icons.inbox_outlined, size: 20, color: p.ink),
            ),
            title: tr(context, 'Not sorted', 'Chưa xếp'),
          ),
          for (final name in c.named)
            _Place(
              key: Key('share-place-new-$name'),
              value: 'n:$name',
              leading: CollectionBadge(
                hue: HandyPalette.forKey(name),
                size: 15,
                always: true,
              ),
              title: name,
              note: tr(context, 'New', 'Mới'),
            ),
          for (final (col, depth) in collectionTree(l))
            _Place(
              key: Key('share-place-${col.id}'),
              value: 'c:${col.id}',
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
      ),
    );
  }
}

class _Place extends StatelessWidget {
  final String value, title;
  final String? note;
  final Widget leading;
  final double indent;
  const _Place({
    super.key,
    required this.value,
    required this.title,
    required this.leading,
    this.note,
    this.indent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RadioListTile<String>(
      value: value,
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: EdgeInsets.only(left: 20 + indent, right: 12),
      secondary: leading,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: note == null
          ? null
          : Text(
              note!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BookmarkPalette.of(context).muted,
              ),
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
