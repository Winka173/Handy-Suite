import 'package:handy_ui/kit.dart';
import 'editor_controller.dart';

/// The nine kinds of note, each with its name in both languages.
const layerKinds = [
  ('arrow', Icons.north_east, 'Arrow', 'Mũi tên'),
  ('step', Icons.looks_one_outlined, 'Step number', 'Số bước'),
  ('rect', Icons.crop_square, 'Box', 'Khung'),
  ('ellipse', Icons.circle_outlined, 'Circle', 'Vòng tròn'),
  ('highlight', Icons.highlight, 'Highlight', 'Tô sáng'),
  ('text', Icons.title, 'Text', 'Chữ'),
  ('redact', Icons.visibility_off_outlined, 'Hide', 'Che kín'),
  ('spotlight', Icons.flare, 'Spotlight', 'Vùng nổi bật'),
  ('pen', Icons.gesture, 'Pen', 'Bút vẽ'),
];

String kindName(BuildContext context, String kind) {
  final k = layerKinds.firstWhere((k) => k.$1 == kind);
  return tr(context, k.$3, k.$4);
}

/// Pick, the nine notes, then pan and zoom. One tool is in hand at a time;
/// pick (the arrow cursor) moves and resizes what is already there.
class ToolBar extends StatelessWidget {
  final EditorController c;
  final bool busy;
  const ToolBar({super.key, required this.c, required this.busy});

  Widget _tool(
    BuildContext context,
    String key,
    IconData icon,
    String label,
    bool on,
    VoidCallback? tap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final colors = HandyColors.of(context);
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        selected: on,
        button: true,
        excludeSemantics: true,
        child: InkWell(
          key: Key(key),
          onTap: tap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: HandyMotion.of(context, HandyMotion.short),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: on ? colors.select : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 22,
              color: tap == null
                  ? colors.muted
                  : on
                  ? scheme.primary
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = !busy && c.picture != null;
    final scale = c.zoom.value.getMaxScaleOnAxis();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: HandySpace.s),
      child: Row(
        children: [
          _tool(
            context,
            'capture-tool-select',
            Icons.near_me_outlined,
            tr(context, 'Pick and move', 'Chọn và di chuyển'),
            c.tool == null && !c.panMode,
            ready ? () => c.pick(null) : null,
          ),
          const SizedBox(width: HandySpace.xs),
          for (final (kind, icon, en, vi) in layerKinds)
            _tool(
              context,
              'capture-tool-$kind',
              icon,
              tr(context, en, vi),
              c.tool == kind,
              ready ? () => c.pick(c.tool == kind ? null : kind) : null,
            ),
          SizedBox(
            height: 28,
            child: VerticalDivider(
              width: HandySpace.l,
              color: HandyColors.of(context).rule,
            ),
          ),
          _tool(
            context,
            'capture-pan',
            Icons.pan_tool_outlined,
            tr(context, 'Move the picture', 'Kéo ảnh'),
            c.panMode,
            ready ? c.togglePan : null,
          ),
          _tool(
            context,
            'capture-zoom',
            Icons.zoom_in,
            tr(
              context,
              'Zoom ${scale.round()}×, tap for more',
              'Phóng ${scale.round()}×, chạm để phóng thêm',
            ),
            scale > 1.01,
            ready ? c.stepZoom : null,
          ),
        ],
      ),
    );
  }
}
