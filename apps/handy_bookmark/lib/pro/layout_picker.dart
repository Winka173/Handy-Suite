import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import 'entitlements.dart';
import 'layouts.dart';

typedef ChooseLayout = Future<void> Function(String? id, {bool? asCards});

/// Every way to show this list: the free cards and rows, then the Pro
/// layouts, each drawn from the list's own saves. A Pro layout opens a
/// full preview first; choosing a free one applies at once.
Future<void> showLayoutPicker(
  BuildContext context, {
  required LayoutData data,
  required String? current,
  required bool cards,
  required ChooseLayout choose,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheet) {
    final theme = Theme.of(sheet);
    final pro = hasPro(context);
    final active = layoutById(current) != null && pro ? current : null;
    Widget free(
      String key,
      IconData icon,
      String label,
      bool on,
      bool asCards,
    ) => ListTile(
      key: Key(key),
      leading: Icon(icon),
      title: Text(label),
      trailing: on ? const Icon(Icons.check) : null,
      onTap: () async {
        await choose(null, asCards: asCards);
        if (sheet.mounted) Navigator.pop(sheet);
      },
    );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * .86,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              tr(sheet, 'Layouts', 'Bố cục'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            free(
              'layout-cards',
              Icons.grid_view_outlined,
              tr(sheet, 'Cards', 'Thẻ'),
              active == null && cards,
              true,
            ),
            free(
              'layout-rows',
              Icons.view_list_outlined,
              tr(sheet, 'Rows', 'Dòng'),
              active == null && !cards,
              false,
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                sheet,
                'Pro layouts: preview them with this list first.',
                'Bố cục Pro: xem trước với chính danh sách này.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, box) {
                final columns = (box.maxWidth / 170).floor().clamp(2, 4);
                final width = (box.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final (i, l) in galleryLayouts.indexed)
                      SizedBox(
                        width: width,
                        child: _Thumb(
                          layout: l,
                          data: data,
                          on: l.id == active,
                          onTap: () => Navigator.of(sheet).push(
                            MaterialPageRoute<void>(
                              builder: (_) => LayoutPreview(
                                data: data,
                                start: i,
                                current: active,
                                choose: choose,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  },
);

/// The layout itself, drawn from the first saves and scaled down.
class _Thumb extends StatelessWidget {
  final GalleryLayout layout;
  final LayoutData data;
  final bool on;
  final VoidCallback onTap;
  const _Thumb({
    required this.layout,
    required this.data,
    required this.on,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final sample = LayoutData(
      controller: data.controller,
      rows: data.rows.take(6).toList(),
      onOpen: (_) {},
      onDetails: (_) {},
      onToggle: (_) {},
    );
    return Semantics(
      button: true,
      selected: on,
      label: '${tr(context, layout.en, layout.vi)}, Pro',
      excludeSemantics: true,
      child: Material(
        key: Key('layout-${layout.id}'),
        color: p.raised,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BookmarkRadii.item),
          side: on ? BorderSide(color: p.primary, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 120,
                child: ColoredBox(
                  color: p.canvas,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          maxHeight: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: 360,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: MediaQuery(
                                  data: MediaQuery.of(
                                    context,
                                  ).copyWith(textScaler: TextScaler.noScaling),
                                  child: layout.build(context, sample),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Text(
                  tr(context, layout.en, layout.vi),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
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

/// A Pro layout over the whole screen with this list's saves, swiped
/// through; Use for Pro, otherwise a way to Pro and a way back.
class LayoutPreview extends StatefulWidget {
  final LayoutData data;
  final int start;
  final String? current;
  final ChooseLayout choose;
  const LayoutPreview({
    super.key,
    required this.data,
    required this.start,
    required this.current,
    required this.choose,
  });
  @override
  State<LayoutPreview> createState() => _LayoutPreviewState();
}

class _LayoutPreviewState extends State<LayoutPreview> {
  late int at = widget.start;

  Future<void> _use(GalleryLayout l) async {
    if (!await requirePro(context, ProFeature.premiumLayouts)) return;
    await widget.choose(l.id);
    if (!mounted) return;
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = galleryLayouts[at];
    final pro = hasPro(context);
    final using = l.id == widget.current;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, l.en, l.vi)),
        actions: [
          IconButton(
            key: const Key('layout-prev'),
            tooltip: tr(context, 'Previous layout', 'Bố cục trước'),
            onPressed: at == 0 ? null : () => setState(() => at--),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            key: const Key('layout-next'),
            tooltip: tr(context, 'Next layout', 'Bố cục sau'),
            onPressed: at == galleryLayouts.length - 1
                ? null
                : () => setState(() => at++),
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: HandySwap(
        child: ListView(
          key: ValueKey(l.id),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              tr(context, l.tagEn, l.tagVi),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            if (widget.data.rows.isEmpty)
              Text(
                tr(
                  context,
                  'This list is empty; save something here to see it in this layout.',
                  'Danh sách này đang trống; lưu gì đó vào đây để xem bố cục này.',
                ),
              )
            else
              IgnorePointer(child: l.build(context, widget.data)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('layout-keep'),
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr(context, 'Keep current', 'Giữ như cũ')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const Key('layout-use'),
                  onPressed: using ? null : () => _use(l),
                  child: Text(
                    using
                        ? tr(context, 'In use', 'Đang dùng')
                        : pro
                        ? tr(context, 'Use this layout', 'Dùng bố cục này')
                        : tr(context, 'Use with Pro', 'Dùng với Pro'),
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
