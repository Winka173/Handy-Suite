import 'package:flutter/rendering.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';

/// The pieces every Settings view is built from, so rows, switches and
/// gaps line up the same way everywhere:
///
/// - [SettingsGroup]: one of the four groups. Phones: its name, its one
///   line, then its panels. From 640 px: name and line on the left, the
///   panels on the right (the kit's own settings layout).
/// - [SettingsPanel]: a small title over one white panel of rows.
/// - [SettingsRow], [SettingsSwitch], [SettingsChoice]: a row is a
///   24 px icon, its words and one control on the right, so every title
///   starts on the same edge, switch or not.
/// - [KitSection]: a kit section (Pro, other apps, automatic backup) set
///   into a group without the kit's own 24 px above and below it.

/// Space between panels inside a group.
const double _panelGap = 20;

/// Space above a group (not the first).
const double _groupGap = 44;

class SettingsGroup extends StatelessWidget {
  final String title;
  final String? note;
  final bool first;
  final List<Widget> children;

  /// Beside the title (a Pro tag).
  final Widget? badge;
  const SettingsGroup({
    super.key,
    required this.title,
    this.note,
    this.badge,
    this.first = false,
    required this.children,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(fontSize: 22),
              ),
            ),
            ?badge,
          ],
        ),
        if (note != null) ...[
          const SizedBox(height: HandySpace.xs),
          Text(
            note!,
            style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
          ),
        ],
      ],
    );
    final panels = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    return Padding(
      padding: EdgeInsets.only(top: first ? HandySpace.s : _groupGap),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 640
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 200, child: head),
                  const SizedBox(width: HandySpace.xxl),
                  Expanded(child: panels),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  head,
                  const SizedBox(height: HandySpace.l),
                  panels,
                ],
              ),
      ),
    );
  }
}

/// A titled panel of rows inside a group. [gap]: false for the group's
/// first panel.
class SettingsPanel extends StatelessWidget {
  final String? title, note;
  final List<Widget> rows;
  final bool gap;
  const SettingsPanel({
    super.key,
    this.title,
    this.note,
    this.gap = true,
    required this.rows,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final list = <Widget>[];
    for (final r in rows) {
      // Rows that build to nothing take no divider either.
      if (list.isNotEmpty) list.add(const Divider(indent: 56));
      list.add(r);
    }
    return Padding(
      padding: EdgeInsets.only(top: gap ? _panelGap : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Semantics(
              header: true,
              child: Text(title!, style: theme.textTheme.titleMedium),
            ),
            if (note != null) ...[
              const SizedBox(height: HandySpace.xs),
              Text(
                note!,
                style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
              ),
            ],
            const SizedBox(height: HandySpace.m),
          ],
          Material(
            color: p.surface,
            borderRadius: BorderRadius.circular(BoardsRadii.tile),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: list,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row: icon, title, an optional line under it, and one control (or
/// a chevron when it opens something).
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool navigates, destructive;
  final int subtitleLines;
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.navigates = false,
    this.destructive = false,
    this.subtitleLines = 4,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final ink = destructive ? p.danger : null;
    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          HandySpace.l,
          HandySpace.m,
          trailing == null && !navigates ? HandySpace.l : HandySpace.s,
          HandySpace.m,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Icon(icon, size: 22, color: ink ?? p.muted),
            ),
            const SizedBox(width: HandySpace.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(color: ink),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: subtitleLines,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: HandySpace.s),
              trailing!,
            ] else if (navigates) ...[
              const SizedBox(width: HandySpace.xs),
              Icon(Icons.chevron_right, color: p.muted),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
  }
}

/// A row whose control is a switch; the whole row toggles it.
class SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const SettingsSwitch({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: SettingsRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Padding(
        padding: const EdgeInsets.only(right: HandySpace.xs),
        child: Switch.adaptive(value: value, onChanged: onChanged),
      ),
    ),
  );
}

/// A row with a choice of two to four words under its title.
class SettingsChoice<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  /// The key of the segmented control itself (tests tap its segments).
  final Key? controlKey;
  const SettingsChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.controlKey,
  });

  /// Whether every word fits a segment of [width]; when one would break,
  /// the choices stack as a list instead.
  bool _fits(BuildContext context, double width) {
    final style = Theme.of(context).textTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);
    final each = width / options.length - 24;
    for (final o in options) {
      for (final word in o.$2.split(' ')) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        final wide = painter.width > each;
        painter.dispose();
        if (wide) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: HandySpace.m),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(icon: icon, title: title),
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth - 2 * HandySpace.l;
            if (_fits(context, width)) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  HandySpace.l,
                  0,
                  HandySpace.l,
                  HandySpace.xs,
                ),
                child: SegmentedButton<T>(
                  key: controlKey,
                  showSelectedIcon: false,
                  segments: [
                    for (final o in options)
                      ButtonSegment(
                        value: o.$1,
                        label: Text(
                          o.$2,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                  selected: {value},
                  onSelectionChanged: (s) => onChanged(s.first),
                ),
              );
            }
            // Narrow, or very large text: one choice per line, the
            // chosen one ticked and tinted.
            final p = BoardsPalette.of(context);
            final dark = Theme.of(context).brightness == Brightness.dark;
            return Column(
              key: controlKey,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final o in options)
                  Semantics(
                    button: true,
                    selected: o.$1 == value,
                    inMutuallyExclusiveGroup: true,
                    child: Material(
                      color: o.$1 == value ? p.tint : Colors.transparent,
                      child: InkWell(
                        onTap: () => onChanged(o.$1),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              56,
                              HandySpace.s,
                              HandySpace.l,
                              HandySpace.s,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    o.$2,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: o.$1 == value
                                              ? (dark ? p.ink : p.pressed)
                                              : null,
                                        ),
                                  ),
                                ),
                                if (o.$1 == value)
                                  Icon(
                                    Icons.check,
                                    size: 20,
                                    color: dark ? p.ink : p.pressed,
                                  ),
                              ],
                            ),
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
  );
}

/// A pushed view under Settings (advanced tools, storage): the same title
/// bar and column as Settings itself.
Future<void> pushSettingsView(
  BuildContext context,
  String title,
  List<Widget> Function(BuildContext context) children, {
  Listenable? listenable,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (context) => listenable == null
        ? HandyPage(title: title, children: _top(children(context)))
        : ListenableBuilder(
            listenable: listenable,
            builder: (context, _) =>
                HandyPage(title: title, children: _top(children(context))),
          ),
  ),
);

/// A view's first panel sits a step below the title bar.
List<Widget> _top(List<Widget> children) => [
  const SizedBox(height: HandySpace.m),
  ...children,
];

/// A kit settings section placed in a group: the kit pads its sections
/// by [HandySpace.xl] above and below; here that becomes the group's own
/// panel gap. A section that hides itself (no store page, no Pro model)
/// takes no room at all.
class KitSection extends SingleChildRenderObjectWidget {
  const KitSection({super.key, required Widget super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTrim();
}

class _RenderTrim extends RenderShiftedBox {
  _RenderTrim() : super(null);
  static const _trim = HandySpace.xl;

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(
      BoxConstraints.tightFor(width: constraints.maxWidth),
      parentUsesSize: true,
    );
    final h = c.size.height;
    final shown = h > 2 * _trim;
    size = constraints.constrain(
      Size(c.size.width, shown ? h - 2 * _trim + _panelGap : 0),
    );
    (c.parentData! as BoxParentData).offset = Offset(
      0,
      shown ? _panelGap - _trim : 0,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.height > 0) super.paint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      size.height > 0 && super.hitTestChildren(result, position: position);
}
