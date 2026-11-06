import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import 'identity.dart';

/// The rows of the collection sheet: each one line that scrolls sideways,
/// so the sheet stays short.

/// A small label over a row of choices.
class PickerLabel extends StatelessWidget {
  final String text;
  const PickerLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: HandySpace.xs),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: BookmarkPalette.of(context).muted,
      ),
    ),
  );
}

/// One row that scrolls sideways when it does not fit, bleeding to the
/// sheet's edges so the cut-off item shows there is more.
class _Row extends StatelessWidget {
  final List<Widget> children;
  const _Row({required this.children});
  @override
  // Built whole (a few dozen items at most), so every choice can be reached
  // by focus and scrolled into view; as tall as its tallest item, so large
  // text is never cut.
  // On a wide sheet the choices wrap onto more lines; on a phone they
  // scroll sideways, cut at the sheet's own edge.
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => box.maxWidth >= 440
        ? Wrap(
            spacing: HandySpace.xs,
            runSpacing: HandySpace.xs,
            children: children,
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.hardEdge,
            child: Row(
              children: [
                for (final (i, c) in children.indexed) ...[
                  if (i > 0) const SizedBox(width: HandySpace.xs),
                  c,
                ],
              ],
            ),
          ),
  );
}

/// A round choice of 44 px with a name for the screen reader.
class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final Color fill;
  final Widget? child;
  final VoidCallback onTap;
  const _Choice({
    super.key,
    required this.label,
    required this.selected,
    required this.fill,
    required this.onTap,
    this.child,
  });
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: fill,
          shape: CircleBorder(
            side: BorderSide(
              color: selected ? p.ink : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(dimension: 44, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

/// Ready starts for a new collection; only those whose name is free.
class TemplateRow extends StatelessWidget {
  final Set<String> taken;
  final ValueChanged<CollectionTemplate> onPick;
  const TemplateRow({super.key, required this.taken, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final free = [
      for (final t in collectionTemplates)
        if (!taken.contains(tr(context, t.en, t.vi).toLowerCase())) t,
    ];
    if (free.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('collection-templates'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerLabel(tr(context, 'Start from', 'Bắt đầu từ')),
        _Row(
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

/// None, the icons, and one emoji the person types.
class MarkRow extends StatefulWidget {
  final CollectionMark? value;
  final int hue;
  final ValueChanged<CollectionMark?> onChanged;
  const MarkRow({
    super.key,
    required this.value,
    required this.hue,
    required this.onChanged,
  });
  @override
  State<MarkRow> createState() => _MarkRowState();
}

class _MarkRowState extends State<MarkRow> {
  late bool _typing = widget.value is EmojiMark;
  late final TextEditingController _emoji = TextEditingController(
    text: switch (widget.value) {
      EmojiMark(:final emoji) => emoji,
      _ => '',
    },
  );

  @override
  void didUpdateWidget(MarkRow old) {
    super.didUpdateWidget(old);
    // A template or an icon replaces a typed emoji.
    if (widget.value is! EmojiMark && old.value is EmojiMark) {
      _emoji.clear();
      _typing = false;
    }
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
    final value = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerLabel(tr(context, 'Icon', 'Biểu tượng')),
        _Row(
          children: [
            _Choice(
              key: const Key('mark-none'),
              label: tr(context, 'No icon', 'Không biểu tượng'),
              selected: value == null && !_typing,
              fill: value == null && !_typing ? wash : Colors.transparent,
              onTap: () {
                setState(() => _typing = false);
                widget.onChanged(null);
              },
              child: Icon(Icons.block, size: 20, color: p.muted),
            ),
            for (final e in collectionIcons.entries)
              _Choice(
                key: Key('mark-${e.key}'),
                label: iconLabel(context, e.key),
                selected: value is IconMark && value.key == e.key,
                fill: value is IconMark && value.key == e.key
                    ? wash
                    : Colors.transparent,
                onTap: () {
                  setState(() => _typing = false);
                  widget.onChanged(IconMark(e.key));
                },
                child: Icon(e.value, size: 22, color: p.ink),
              ),
            _Choice(
              key: const Key('mark-emoji-open'),
              label: tr(context, 'An emoji', 'Một emoji'),
              selected: _typing,
              fill: _typing ? wash : Colors.transparent,
              onTap: () => setState(() => _typing = true),
              child: value is EmojiMark
                  ? Text(
                      value.emoji,
                      style: const TextStyle(fontSize: 22, height: 1),
                    )
                  : Icon(Icons.add_reaction_outlined, size: 22, color: p.ink),
            ),
          ],
        ),
        if (_typing)
          Padding(
            padding: const EdgeInsets.only(top: HandySpace.s),
            child: TextField(
              key: const Key('mark-emoji'),
              controller: _emoji,
              autofocus: value is! EmojiMark,
              decoration: InputDecoration(
                hintText: tr(
                  context,
                  'Type or paste one emoji',
                  'Gõ hoặc dán một emoji',
                ),
                isDense: true,
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

/// Auto, then each identity colour this app can use.
class HueRow extends StatelessWidget {
  final int? value;
  final int autoHue;
  final ValueChanged<int?> onChanged;
  const HueRow({
    super.key,
    required this.value,
    required this.autoHue,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final auto = tr(context, 'Auto', 'Tự động');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerLabel(tr(context, 'Colour', 'Màu')),
        _Row(
          children: [
            _Choice(
              key: const Key('hue-auto'),
              label: '$auto (${hueName(context, autoHue)})',
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
              _Choice(
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
