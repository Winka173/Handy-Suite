import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import 'identity.dart';

/// A small label over a group of choices, like a field's label.
class PickerLabel extends StatelessWidget {
  final String text;
  const PickerLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: HandySpace.s),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

/// Ready starts for a new collection. Only those whose name is not taken.
class TemplatePicker extends StatelessWidget {
  final Set<String> taken;
  final ValueChanged<CollectionTemplate> onPick;
  const TemplatePicker({super.key, required this.taken, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final free = [
      for (final t in collectionTemplates)
        if (!taken.contains(tr(context, t.en, t.vi).toLowerCase())) t,
    ];
    if (free.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('collection-templates'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PickerLabel(tr(context, 'Start from', 'Bắt đầu từ')),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: [
            for (final t in free)
              ActionChip(
                key: Key('template-${t.icon}-${t.hue}'),
                avatar: Icon(collectionIcons[t.icon], size: 18),
                label: Text(tr(context, t.en, t.vi)),
                onPressed: () => onPick(t),
              ),
          ],
        ),
      ],
    );
  }
}

/// Auto, then each identity colour this app can use, as round swatches.
class HuePicker extends StatelessWidget {
  final int? value;
  final int autoHue;
  final ValueChanged<int?> onChanged;
  const HuePicker({
    super.key,
    required this.value,
    required this.autoHue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    Widget swatch({
      required Key key,
      required String label,
      required bool selected,
      required Color fill,
      required VoidCallback onTap,
      Widget? child,
    }) => Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          key: key,
          onTap: onTap,
          radius: 24,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? p.ink : Colors.transparent,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
    final auto = tr(context, 'Auto', 'Tự động');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PickerLabel(tr(context, 'Colour', 'Màu')),
        Wrap(
          spacing: HandySpace.xs,
          runSpacing: HandySpace.xs,
          children: [
            swatch(
              key: const Key('hue-auto'),
              label: tr(
                context,
                '$auto (${hueName(context, autoHue)})',
                '$auto (${hueName(context, autoHue)})',
              ),
              selected: value == null,
              fill: HandyPalette.of(context, autoHue).tint,
              onTap: () => onChanged(null),
              child: Text(
                'A',
                style: TextStyle(
                  color: HandyPalette.of(context, autoHue).mark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (var i = 0; i < usableHues(context); i++)
              swatch(
                key: Key('hue-$i'),
                label: hueName(context, i),
                selected: value == i,
                fill: HandyPalette.of(context, i).mark,
                onTap: () => onChanged(i),
              ),
          ],
        ),
      ],
    );
  }
}

/// None, the curated icons, and one emoji the person types.
class MarkPicker extends StatefulWidget {
  final CollectionMark? value;
  final int hue;
  final ValueChanged<CollectionMark?> onChanged;
  const MarkPicker({
    super.key,
    required this.value,
    required this.hue,
    required this.onChanged,
  });
  @override
  State<MarkPicker> createState() => _MarkPickerState();
}

class _MarkPickerState extends State<MarkPicker> {
  late final TextEditingController _emoji = TextEditingController(
    text: switch (widget.value) {
      EmojiMark(:final emoji) => emoji,
      _ => '',
    },
  );

  @override
  void didUpdateWidget(MarkPicker old) {
    super.didUpdateWidget(old);
    // A template or an icon replaces a typed emoji.
    if (widget.value is! EmojiMark && _emoji.text.isNotEmpty) _emoji.clear();
  }

  @override
  void dispose() {
    _emoji.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final wash = HandyPalette.of(context, widget.hue).tint;
    Widget cell({
      required Key key,
      required String label,
      required bool selected,
      required Widget child,
      required VoidCallback onTap,
    }) => Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: selected ? wash : Colors.transparent,
          shape: CircleBorder(
            side: BorderSide(
              color: selected ? p.ink : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            key: key,
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(dimension: 44, child: Center(child: child)),
          ),
        ),
      ),
    );
    final value = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PickerLabel(tr(context, 'Icon', 'Biểu tượng')),
        Wrap(
          spacing: HandySpace.xs,
          runSpacing: HandySpace.xs,
          children: [
            cell(
              key: const Key('mark-none'),
              label: tr(context, 'No icon', 'Không biểu tượng'),
              selected: value == null,
              onTap: () => widget.onChanged(null),
              child: Icon(Icons.block, size: 20, color: p.muted),
            ),
            for (final e in collectionIcons.entries)
              cell(
                key: Key('mark-${e.key}'),
                label: iconLabel(context, e.key),
                selected: value is IconMark && value.key == e.key,
                onTap: () => widget.onChanged(IconMark(e.key)),
                child: Icon(e.value, size: 22, color: p.ink),
              ),
          ],
        ),
        const SizedBox(height: HandySpace.m),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: TextField(
            key: const Key('mark-emoji'),
            controller: _emoji,
            textAlign: TextAlign.start,
            decoration: InputDecoration(
              labelText: tr(context, 'Or one emoji', 'Hoặc một emoji'),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: tr(context, 'Type or paste', 'Gõ hoặc dán'),
              filled: value is EmojiMark,
              fillColor: wash,
            ),
            onChanged: (text) {
              final one = firstCharacter(text);
              if (one != text) {
                _emoji.value = TextEditingValue(
                  text: one,
                  selection: TextSelection.collapsed(offset: one.length),
                );
              }
              widget.onChanged(one.isEmpty ? null : EmojiMark(one));
            },
          ),
        ),
      ],
    );
  }
}
