import 'package:flutter/services.dart';
import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import '../export/export_sheet.dart';
import '../scope.dart';
import 'canvas.dart';
import 'inspector.dart';
import 'layers.dart';
import 'studio_controller.dart';

Future<void> openStudio(
  BuildContext context,
  CardScope scope,
  String designId,
) => Navigator.of(context).pushNamed('/design/$designId');

/// The studio: the canvas is the editor. Layers and the add palette on the
/// left, the inspector on the right on wide screens; sheets and a bottom
/// bar on phones.
class StudioPage extends StatefulWidget {
  final CardScope scope;
  final String designId;
  const StudioPage({super.key, required this.scope, required this.designId});
  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  StudioController? c;
  final focus = FocusNode(debugLabel: 'studio');

  @override
  void initState() {
    super.initState();
    final doc = widget.scope.library.designs[widget.designId];
    if (doc != null)
      c = StudioController(widget.scope.library, widget.scope.images, doc);
    // No ads while designing or exporting (set after this frame, not
    // while the app is building).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.scope.adsVisible.value = false,
    );
  }

  @override
  void dispose() {
    final ads = widget.scope.adsVisible;
    WidgetsBinding.instance.addPostFrameCallback((_) => ads.value = true);
    c?.save();
    c?.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> pickPicture(String? replace) async {
    final c = this.c!;
    try {
      final file = await widget.scope.files.importBytes(
        extensions: const ['png', 'jpg', 'jpeg', 'webp'],
        maxBytes: 12000000,
      );
      if (file == null || !mounted) return;
      await c.addPicture(file.bytes, file.name, replace: replace);
    } catch (e) {
      if (mounted) showHandyMessage(context, errorText(context, e));
    }
  }

  void addMenu(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        child: _AddPalette(
          c: c!,
          pickPicture: pickPicture,
          close: () => Navigator.pop(context),
        ),
      ),
    ),
  );

  void sheet(BuildContext context, Widget Function() child) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: ListenableBuilder(listenable: c!, builder: (_, _) => child()),
        ),
      );

  Map<ShortcutActivator, VoidCallback> shortcuts(BuildContext context) {
    final c = this.c!;
    SingleActivator cmd(LogicalKeyboardKey k, {bool shift = false}) =>
        SingleActivator(k, control: true, shift: shift);
    SingleActivator mac(LogicalKeyboardKey k, {bool shift = false}) =>
        SingleActivator(k, meta: true, shift: shift);
    final pairs = <(LogicalKeyboardKey, bool, VoidCallback)>[
      (LogicalKeyboardKey.keyZ, false, c.session.undo),
      (LogicalKeyboardKey.keyZ, true, c.session.redo),
      (LogicalKeyboardKey.keyY, false, c.session.redo),
      (LogicalKeyboardKey.keyC, false, c.copySelection),
      (LogicalKeyboardKey.keyX, false, c.cutSelection),
      (LogicalKeyboardKey.keyV, false, c.paste),
      (LogicalKeyboardKey.keyD, false, c.duplicateSelection),
      (LogicalKeyboardKey.keyA, false, c.selectAll),
      (LogicalKeyboardKey.keyG, false, c.group),
      (LogicalKeyboardKey.keyG, true, c.ungroupSelection),
      (LogicalKeyboardKey.keyS, false, c.save),
      (
        LogicalKeyboardKey.keyE,
        false,
        () => openExport(context, widget.scope, c),
      ),
      (LogicalKeyboardKey.equal, false, () => c.zoomBy(1.25)),
      (LogicalKeyboardKey.minus, false, () => c.zoomBy(0.8)),
      (LogicalKeyboardKey.digit0, false, c.fit),
    ];
    return {
      for (final (k, shift, f) in pairs) ...{
        cmd(k, shift: shift): f,
        mac(k, shift: shift): f,
      },
      const SingleActivator(LogicalKeyboardKey.delete): c.deleteSelection,
      const SingleActivator(LogicalKeyboardKey.backspace): c.deleteSelection,
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (c.editingText != null) {
          c.editingText = null;
          c.refresh();
        } else if (c.session.selection.isNotEmpty ||
            c.session.entered != null) {
          c.session.clearSelection();
        } else {
          Navigator.maybePop(context);
        }
      },
      for (final (k, v) in [
        (LogicalKeyboardKey.arrowLeft, const Vec(-1, 0)),
        (LogicalKeyboardKey.arrowRight, const Vec(1, 0)),
        (LogicalKeyboardKey.arrowUp, const Vec(0, -1)),
        (LogicalKeyboardKey.arrowDown, const Vec(0, 1)),
      ]) ...{
        SingleActivator(k): () => c.nudge(v * (pointsPerMm / 2)),
        SingleActivator(k, shift: true): () => c.nudge(v * (pointsPerMm * 5)),
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = this.c;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: HandyEmpty(
          title: tr(
            context,
            'This design is not here',
            'Không có thiết kế này',
          ),
          message: tr(
            context,
            'It may have been deleted on this device.',
            'Có thể nó đã bị xóa trên máy này.',
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final wide = width >= 1100, medium = width >= 720;
        final canvas = ColoredBox(
          color: HandyColors.of(context).ground,
          child: CardCanvas(c: c),
        );
        final inspector = Inspector(c: c, pickPicture: pickPicture);
        return PopScope(
          canPop: !c.session.dirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await c.save();
            if (context.mounted && !c.session.dirty) Navigator.pop(context);
          },
          child: CallbackShortcuts(
            bindings: c.editingText == null ? shortcuts(context) : const {},
            child: Focus(
              focusNode: focus,
              autofocus: true,
              onKeyEvent: (node, e) {
                // Space held pans the view; nothing is edited while it is down.
                if (e.logicalKey == LogicalKeyboardKey.space &&
                    c.editingText == null) {
                  if (e is KeyDownEvent) c.setPanMode(true);
                  if (e is KeyUpEvent) c.setPanMode(false);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Scaffold(
                key: const Key('studio'),
                appBar: _topBar(context, c, medium),
                body: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 248,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _AddPalette(
                                  c: c,
                                  pickPicture: pickPicture,
                                  compact: true,
                                ),
                                const Divider(),
                                Expanded(child: LayersPanel(c: c)),
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: Column(
                              children: [
                                _sides(context, c),
                                Expanded(child: canvas),
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          SizedBox(width: 288, child: inspector),
                        ],
                      )
                    : medium
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _sides(context, c),
                                Expanded(child: canvas),
                                _bottomBar(context, c, phone: false),
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          SizedBox(width: 288, child: inspector),
                        ],
                      )
                    : Column(
                        children: [
                          _sides(context, c),
                          Expanded(child: canvas),
                          _bottomBar(context, c, phone: true),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _topBar(
    BuildContext context,
    StudioController c,
    bool medium,
  ) {
    final colors = HandyColors.of(context);
    final state = switch (c.saveState) {
      'saving' => tr(context, 'Saving…', 'Đang lưu…'),
      'pending' => tr(context, 'Edited', 'Đã sửa'),
      'error' => tr(context, 'Not saved', 'Chưa lưu được'),
      _ => tr(context, 'Saved', 'Đã lưu'),
    };
    return AppBar(
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            c.doc.name.isEmpty
                ? tr(context, 'Untitled card', 'Thẻ chưa đặt tên')
                : c.doc.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              state,
              key: const Key('studio-save-state'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: c.saveState == 'error' ? colors.negative : colors.muted,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          key: const Key('studio-undo'),
          tooltip: tr(context, 'Undo ${c.session.undoLabel ?? ''}', 'Hoàn tác'),
          icon: const Icon(Icons.undo),
          onPressed: c.session.canUndo ? c.session.undo : null,
        ),
        IconButton(
          key: const Key('studio-redo'),
          tooltip: tr(context, 'Redo', 'Làm lại'),
          icon: const Icon(Icons.redo),
          onPressed: c.session.canRedo ? c.session.redo : null,
        ),
        if (medium) ...[
          IconButton(
            tooltip: tr(context, 'Zoom out', 'Thu nhỏ'),
            icon: const Icon(Icons.zoom_out),
            onPressed: () => c.zoomBy(0.8),
          ),
          TextButton(
            onPressed: c.fit,
            child: Text(
              '${(c.zoom * 100 * 72 / 96).round()}%',
              style: const TextStyle(fontFeatures: tabular),
            ),
          ),
          IconButton(
            tooltip: tr(context, 'Zoom in', 'Phóng to'),
            icon: const Icon(Icons.zoom_in),
            onPressed: () => c.zoomBy(1.25),
          ),
        ],
        HandyMenuButton(
          items: [
            HandyMenuItem(
              c.showGuides ? Icons.grid_off : Icons.grid_on,
              c.showGuides
                  ? tr(context, 'Hide trim guides', 'Ẩn đường xén')
                  : tr(context, 'Show trim guides', 'Hiện đường xén'),
              () {
                c.showGuides = !c.showGuides;
                c.refresh();
              },
            ),
            HandyMenuItem(
              Icons.straighten,
              c.snap.toObjects
                  ? tr(
                      context,
                      'Stop snapping to objects',
                      'Tắt bắt dính phần tử',
                    )
                  : tr(context, 'Snap to objects', 'Bắt dính phần tử'),
              () => c.library.setSetting('snapObjects', !c.snap.toObjects),
            ),
            HandyMenuItem(
              Icons.grid_4x4,
              c.snap.toGrid
                  ? tr(
                      context,
                      'Stop snapping to the 2 mm grid',
                      'Tắt lưới 2 mm',
                    )
                  : tr(context, 'Snap to a 2 mm grid', 'Bắt dính lưới 2 mm'),
              () => c.library.setSetting('snapGrid', !c.snap.toGrid),
            ),
            HandyMenuItem(
              Icons.pan_tool_outlined,
              c.panMode
                  ? tr(context, 'Stop moving the view', 'Thôi kéo khung nhìn')
                  : tr(
                      context,
                      'Move the view (no edits)',
                      'Kéo khung nhìn (không sửa)',
                    ),
              () => c.setPanMode(!c.panMode),
            ),
            HandyMenuItem(
              Icons.bookmark_add_outlined,
              tr(context, 'Save as template', 'Lưu thành mẫu'),
              () async {
                await c.library.saveTemplate(
                  c.doc,
                  c.doc.name.isEmpty ? 'Template' : c.doc.name,
                );
                if (context.mounted)
                  showHandyMessage(
                    context,
                    tr(context, 'Saved as a template.', 'Đã lưu thành mẫu.'),
                  );
              },
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: HandySpace.s),
          child: FilledButton(
            key: const Key('studio-export'),
            onPressed: () => openExport(context, widget.scope, c),
            child: Text(tr(context, 'Export', 'Xuất')),
          ),
        ),
      ],
    );
  }

  /// Front, back and further sides; the one shown is underlined in ink.
  Widget _sides(BuildContext context, StudioController c) {
    final doc = c.doc;
    String name(CardPage p, int i) => switch (p.name) {
      'Front' => tr(context, 'Front', 'Mặt trước'),
      'Back' => tr(context, 'Back', 'Mặt sau'),
      '' => tr(context, 'Side ${i + 1}', 'Mặt ${i + 1}'),
      _ => p.name,
    };
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HandySpace.s),
        children: [
          for (final (i, p) in doc.pages.indexed)
            Padding(
              padding: const EdgeInsets.only(right: HandySpace.xs),
              child: ChoiceChip(
                key: Key('side-$i'),
                label: Text(name(p, i)),
                selected: c.session.page == p.id,
                onSelected: (_) => c.session.showPage(p.id),
              ),
            ),
          TextButton.icon(
            key: const Key('side-add'),
            onPressed: doc.pages.length >= 50
                ? null
                : () {
                    final page = CardPage(
                      id: newCardId(),
                      name: doc.pages.length == 1 ? 'Back' : '',
                    );
                    c.editDoc(
                      'Add side',
                      (d) => d.copyWith(pages: [...d.pages, page]),
                    );
                    c.session.showPage(page.id);
                  },
            icon: const Icon(Icons.add, size: 18),
            label: Text(tr(context, 'Side', 'Mặt')),
          ),
          if (doc.pages.length > 1)
            TextButton(
              onPressed: () async {
                final ok = await confirmHandy(
                  context,
                  title: tr(context, 'Remove this side?', 'Bỏ mặt này?'),
                  message: tr(
                    context,
                    'Undo brings it back.',
                    'Hoàn tác sẽ đưa nó trở lại.',
                  ),
                  confirmLabel: tr(context, 'Remove', 'Bỏ'),
                  destructive: true,
                );
                if (!ok) return;
                final id = c.session.page;
                c.session.showPage(doc.pages.firstWhere((p) => p.id != id).id);
                c.editDoc(
                  'Remove side',
                  (d) => d.copyWith(
                    pages: [
                      for (final p in d.pages)
                        if (p.id != id) p,
                    ],
                  ),
                );
              },
              child: Text(tr(context, 'Remove side', 'Bỏ mặt')),
            ),
        ],
      ),
    );
  }

  Widget _bottomBar(
    BuildContext context,
    StudioController c, {
    required bool phone,
  }) {
    final hasSelection = c.session.selected.isNotEmpty;
    Widget tool(Key key, IconData icon, String label, VoidCallback? onTap) =>
        Expanded(
          child: InkWell(
            key: key,
            onTap: onTap,
            child: SizedBox(
              height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: onTap == null
                        ? HandyColors.of(context).control
                        : null,
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        );
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            tool(
              const Key('bar-add'),
              Icons.add_box_outlined,
              tr(context, 'Add', 'Thêm'),
              () => addMenu(context),
            ),
            tool(
              const Key('bar-layers'),
              Icons.layers_outlined,
              tr(context, 'Layers', 'Lớp'),
              () => sheet(context, () => LayersPanel(c: c)),
            ),
            if (phone)
              tool(
                const Key('bar-edit'),
                Icons.tune,
                tr(context, 'Edit', 'Sửa'),
                () => sheet(
                  context,
                  () => Inspector(c: c, pickPicture: pickPicture),
                ),
              ),
            tool(
              const Key('bar-duplicate'),
              Icons.copy_all_outlined,
              tr(context, 'Copy', 'Nhân đôi'),
              hasSelection ? c.duplicateSelection : null,
            ),
            tool(
              const Key('bar-front'),
              Icons.flip_to_front,
              tr(context, 'Front', 'Lên trên'),
              hasSelection ? () => c.arrangeSelection(Arrange.front) : null,
            ),
            tool(
              const Key('bar-delete'),
              Icons.delete_outline,
              tr(context, 'Delete', 'Xóa'),
              hasSelection ? c.deleteSelection : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// What can be added, grouped as the person thinks of it.
class _AddPalette extends StatelessWidget {
  final StudioController c;
  final Future<void> Function(String?) pickPicture;
  final VoidCallback? close;

  /// Small tiles in a grid (the wide sidebar), or a list (the phone sheet).
  final bool compact;
  const _AddPalette({
    required this.c,
    required this.pickPicture,
    this.close,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    void then(VoidCallback f) {
      close?.call();
      f();
    }

    Widget item(String key, IconData icon, String label, VoidCallback f) =>
        compact
        ? Tooltip(
            message: label,
            child: InkWell(
              key: Key('add-$key'),
              borderRadius: BorderRadius.circular(HandyRadius.control),
              onTap: () => then(f),
              child: SizedBox(
                width: 72,
                height: 60,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          )
        : ListTile(
            key: Key('add-$key'),
            dense: true,
            leading: Icon(icon, size: 20),
            title: Text(label),
            onTap: () => then(f),
          );
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            HandySpace.m,
            HandySpace.l,
            HandySpace.xs,
          ),
          child: Text(
            tr(context, 'Add', 'Thêm'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        item(
          'text',
          Icons.title,
          tr(context, 'Text', 'Chữ'),
          () => c.add(
            'text',
            props: {
              'text': tr(context, 'Your text', 'Chữ của bạn'),
              'size': 14,
            },
          ),
        ),
        item(
          'contact',
          Icons.contact_page_outlined,
          tr(context, 'Contact field', 'Trường liên hệ'),
          () => c.add('contact', binding: const ElementBinding('phone')),
        ),
        item(
          'image',
          Icons.image_outlined,
          tr(context, 'Picture', 'Ảnh'),
          () => pickPicture(null),
        ),
        item(
          'qr',
          Icons.qr_code_2,
          tr(context, 'QR code', 'Mã QR'),
          () => c.add(
            'qr',
            binding: c.doc.profileId == null
                ? null
                : const ElementBinding('vcard'),
          ),
        ),
        item(
          'rect',
          Icons.crop_square,
          tr(context, 'Rectangle', 'Hình chữ nhật'),
          () => c.add('rect'),
        ),
        item(
          'ellipse',
          Icons.circle_outlined,
          tr(context, 'Ellipse', 'Hình elip'),
          () => c.add('ellipse'),
        ),
        item(
          'line',
          Icons.horizontal_rule,
          tr(context, 'Line', 'Đường kẻ'),
          () => c.add('line'),
        ),
        item(
          'polygon',
          Icons.hexagon_outlined,
          tr(context, 'Polygon or star', 'Đa giác, ngôi sao'),
          () => c.add('polygon'),
        ),
        item(
          'icon',
          Icons.emoji_symbols_outlined,
          tr(context, 'Icon', 'Biểu tượng'),
          () => c.add('icon'),
        ),
        item(
          'badge',
          Icons.verified_outlined,
          tr(context, 'Badge', 'Huy hiệu'),
          () => c.add('badge', props: {'label': tr(context, 'NEW', 'MỚI')}),
        ),
      ],
    );
    if (!compact) return column;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HandySpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          column.children.first,
          Wrap(children: column.children.skip(1).toList()),
        ],
      ),
    );
  }
}

/// Picks a file through the platform's own picker (used by home too).
Future<ImportedBytes?> pickProjectFile(HandyFiles files) =>
    files.importBytes(extensions: const ['zip', 'json'], maxBytes: 30000000);
