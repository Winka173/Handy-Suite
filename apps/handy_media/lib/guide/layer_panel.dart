import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import 'editor_controller.dart';
import 'tool_bar.dart';

const layerColors = [
  ('#EA580C', 'Orange', 'Cam'),
  ('#2563EB', 'Blue', 'Xanh dương'),
  ('#16A34A', 'Green', 'Xanh lá'),
  ('#000000', 'Black', 'Đen'),
  ('#FFFFFF', 'White', 'Trắng'),
];

/// The chosen note: its colour, its words, where it sits and what is on
/// top. With nothing chosen, the notes on this step, to pick one.
class LayerPanel extends StatelessWidget {
  final EditorController c;
  final bool busy;
  final VoidCallback onRepeatMask;
  const LayerPanel({
    super.key,
    required this.c,
    required this.busy,
    required this.onRepeatMask,
  });

  @override
  Widget build(BuildContext context) {
    final layer = c.layer;
    return HandySwap(
      child: layer == null
          ? _Notes(key: const ValueKey('notes'), c: c, busy: busy)
          : _Layer(
              key: ValueKey(layer.id),
              c: c,
              layer: layer,
              busy: busy,
              onRepeatMask: onRepeatMask,
            ),
    );
  }
}

class _Notes extends StatelessWidget {
  final EditorController c;
  final bool busy;
  const _Notes({super.key, required this.c, required this.busy});
  @override
  Widget build(BuildContext context) {
    final layers = c.step?.annotations ?? const <ProjectLayer>[];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, 'Notes on this step', 'Chú thích ở bước này'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: HandySpace.xs),
        if (layers.isEmpty)
          Text(
            tr(
              context,
              'Pick a tool above, then drag on the picture.',
              'Chọn một công cụ ở trên rồi kéo trên ảnh.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: HandyColors.of(context).muted,
            ),
          )
        else
          for (final (i, l) in layers.indexed.toList().reversed)
            HandyTile(
              key: Key('capture-layer-row-${l.id}'),
              icon: layerKinds.firstWhere((k) => k.$1 == l.kind).$2,
              title: [
                kindName(context, l.kind),
                if (l.text.isNotEmpty) l.text,
              ].join(' · '),
              subtitle: tr(context, 'Layer ${i + 1}', 'Lớp ${i + 1}'),
              onTap: busy ? null : () => c.select(l.id),
            ),
      ],
    );
  }
}

class _Layer extends StatelessWidget {
  final EditorController c;
  final ProjectLayer layer;
  final bool busy;
  final VoidCallback onRepeatMask;
  const _Layer({
    super.key,
    required this.c,
    required this.layer,
    required this.busy,
    required this.onRepeatMask,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = c.step!.annotations;
    final at = list.indexWhere((l) => l.id == layer.id);
    Widget icon(String key, IconData i, String tip, VoidCallback? tap) =>
        IconButton(
          key: Key(key),
          tooltip: tip,
          onPressed: busy ? null : tap,
          icon: Icon(i),
        );
    final words = layer.kind == 'text' || layer.kind == 'step';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                kindName(context, layer.kind),
                style: theme.textTheme.titleSmall,
              ),
            ),
            icon(
              'capture-layer-done',
              Icons.check,
              tr(context, 'Done', 'Xong'),
              () => c.select(null),
            ),
            icon(
              'capture-layer-remove',
              Icons.delete_outline,
              tr(context, 'Remove this note', 'Xóa chú thích này'),
              c.removeLayer,
            ),
          ],
        ),
        Wrap(
          spacing: HandySpace.xs,
          children: [
            for (final (hex, en, vi) in layerColors)
              _Swatch(
                hex: hex,
                label: tr(context, en, vi),
                on: layer.color.toUpperCase() == hex,
                onTap: busy
                    ? null
                    : () => c.editLayer(layer.copyWith(color: hex)),
              ),
          ],
        ),
        if (words) ...[
          const SizedBox(height: HandySpace.s),
          _Words(c: c, layer: layer, busy: busy),
        ],
        const SizedBox(height: HandySpace.s),
        Wrap(
          children: [
            for (final (a, i, en, vi) in const [
              ('left', Icons.align_horizontal_left, 'Align left', 'Căn trái'),
              (
                'center',
                Icons.align_horizontal_center,
                'Centre across',
                'Giữa ngang',
              ),
              (
                'right',
                Icons.align_horizontal_right,
                'Align right',
                'Căn phải',
              ),
              ('top', Icons.align_vertical_top, 'Align top', 'Căn trên'),
              (
                'middle',
                Icons.align_vertical_center,
                'Centre down',
                'Giữa dọc',
              ),
              (
                'bottom',
                Icons.align_vertical_bottom,
                'Align bottom',
                'Căn dưới',
              ),
            ])
              icon(
                'capture-align-$a',
                i,
                tr(context, en, vi),
                () => c.editLayer(
                  layer.copyWith(geometry: alignLayer(layer.geometry, a)),
                ),
              ),
            icon(
              'capture-layer-forward',
              Icons.flip_to_front,
              tr(context, 'Bring forward', 'Đưa lên trên'),
              at < list.length - 1 ? () => c.restack(1) : null,
            ),
            icon(
              'capture-layer-backward',
              Icons.flip_to_back,
              tr(context, 'Send backward', 'Đưa xuống dưới'),
              at > 0 ? () => c.restack(-1) : null,
            ),
          ],
        ),
        if (layer.kind == 'redact' && c.project.steps.length > 1)
          TextButton.icon(
            key: const Key('capture-repeat-mask'),
            onPressed: busy ? null : onRepeatMask,
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(
              tr(
                context,
                'Hide the same place on other steps',
                'Che cùng chỗ ở các bước khác',
              ),
            ),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final String hex, label;
  final bool on;
  final VoidCallback? onTap;
  const _Swatch({
    required this.hex,
    required this.label,
    required this.on,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse('FF${hex.substring(1)}', radix: 16));
    final ring = on
        ? Theme.of(context).colorScheme.primary
        : HandyColors.of(context).border;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: Key('capture-color-$hex'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: ring, width: on ? 3 : 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The words of a text note or a step number, written in place.
class _Words extends StatefulWidget {
  final EditorController c;
  final ProjectLayer layer;
  final bool busy;
  const _Words({required this.c, required this.layer, required this.busy});
  @override
  State<_Words> createState() => _WordsState();
}

class _WordsState extends State<_Words> {
  late final text = TextEditingController(text: widget.layer.text);
  bool marked = false;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: const Key('capture-layer-text'),
    controller: text,
    enabled: !widget.busy,
    maxLength: 500,
    minLines: 1,
    maxLines: 3,
    decoration: InputDecoration(
      labelText: tr(context, 'Words', 'Nội dung'),
      counterText: '',
    ),
    onChanged: (v) {
      final layer = widget.c.layer;
      if (layer == null) return;
      // One undo step for a whole edit, not one per letter.
      if (!marked) widget.c.checkpoint();
      marked = true;
      widget.c.editLayer(layer.copyWith(text: v), record: false);
    },
  );
}
