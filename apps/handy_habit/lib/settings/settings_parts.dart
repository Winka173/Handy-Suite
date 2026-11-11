import 'package:flutter/rendering.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import '../pro/entitlements.dart';

/// The pieces every Settings view is built from, on the same frame as
/// Handy Boards and Handy Bookmark, so rows, switches and gaps line up:
///
/// - [SettingsGroup]: a group's name (and one line), then its panels;
///   from 640 px the name sits on the left, the panels on the right.
/// - [SettingsPanel]: an optional small title over one white panel of rows.
/// - [SettingsRow], [SettingsSwitch], [SettingsChoice]: a 24 px icon, the
///   words and one control on the right, so every title starts on one edge.
/// - [KitSection]: a kit section (other apps, automatic backup) set into a
///   group without the kit's own space above and below it.

const double _panelGap = 20;
const double _groupGap = 44;
const double _radius = 16;

class SettingsGroup extends StatelessWidget {
  final String title;
  final String? note;
  final bool first;
  final List<Widget> children;

  /// Beside the title (a Pro pill).
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
    final p = HabitPalette.of(context);
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
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
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

/// A titled panel of rows inside a group. [gap]: false for the first.
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
    final p = HabitPalette.of(context);
    final list = <Widget>[];
    for (final r in rows) {
      if (list.isNotEmpty)
        list.add(Divider(height: 1, indent: 56, color: p.line));
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
            borderRadius: BorderRadius.circular(_radius),
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

/// One row: icon, title (with an optional pill beside it), a line under
/// it, and one control, or a chevron when it opens something.
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing, badge;
  final VoidCallback? onTap;
  final bool navigates, destructive;
  final int subtitleLines;
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.badge,
    this.onTap,
    this.navigates = false,
    this.destructive = false,
    this.subtitleLines = 4,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = HabitPalette.of(context);
    final ink = destructive ? theme.colorScheme.error : p.ink;
    final name = Text(
      title,
      style: theme.textTheme.bodyLarge?.copyWith(color: ink),
    );
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
              child: Icon(icon, size: 22, color: destructive ? ink : p.muted),
            ),
            const SizedBox(width: HandySpace.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (badge == null)
                    name
                  else
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [name, badge!],
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
  final ValueChanged<bool>? onChanged;
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
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: Padding(
        padding: const EdgeInsets.only(right: HandySpace.xs),
        child: Switch.adaptive(value: value, onChanged: onChanged),
      ),
    ),
  );
}

/// A row with a choice of two to four words under its title. Each segment
/// is keyed '<id>-<value>'; when a word would break, the choices stack.
class SettingsChoice extends StatelessWidget {
  final String id;
  final IconData icon;
  final String title;
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;
  const SettingsChoice({
    super.key,
    required this.id,
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

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
    key: Key(id),
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
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    for (final o in options)
                      ButtonSegment(
                        value: o.$1,
                        label: Text(
                          o.$2,
                          key: Key('$id-${o.$1}'),
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
            final p = HabitPalette.of(context);
            return Column(
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
                        key: Key('$id-${o.$1}'),
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
                                              ? p.anchor
                                              : null,
                                        ),
                                  ),
                                ),
                                if (o.$1 == value)
                                  Icon(Icons.check, size: 20, color: p.anchor),
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

/// A row that opens a Pro feature, with the pill beside its name while
/// Pro is not owned.
class HabitProSettingTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool pro;
  final VoidCallback onTap;
  const HabitProSettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pro,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: pro ? null : '$title, Pro',
    child: SettingsRow(
      icon: icon,
      title: title,
      badge: pro ? null : const HabitProPill(),
      subtitle: subtitle,
      navigates: true,
      onTap: onTap,
    ),
  );
}

/// A row that picks one of a few values in a dialog; options are keyed
/// '<id>-<value>'.
class HabitSettingChoice extends StatelessWidget {
  final String id, title, value;
  final IconData icon;
  final Map<String, String> options;
  final Future<void> Function(String) onChanged;
  const HabitSettingChoice({
    super.key,
    required this.id,
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => SettingsRow(
    key: Key(id),
    icon: icon,
    title: title,
    subtitle: options[value] ?? value,
    navigates: true,
    onTap: () async {
      final picked = await showDialog<String>(
        context: context,
        animationStyle: AnimationStyle(
          duration: HandyMotion.of(context),
          reverseDuration: HandyMotion.of(context),
        ),
        builder: (context) => SimpleDialog(
          title: Text(title),
          children: [
            for (final o in options.entries)
              SimpleDialogOption(
                key: Key('$id-${o.key}'),
                onPressed: () => Navigator.pop(context, o.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(o.value)),
                      if (o.key == value) const Icon(Icons.check),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
      if (picked != null) await onChanged(picked);
    },
  );
}

/// A switch row keyed [id].
class HabitSettingToggle extends StatelessWidget {
  final String id, title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final Future<void> Function(bool) onChanged;
  const HabitSettingToggle({
    super.key,
    required this.id,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => SettingsSwitch(
    key: Key(id),
    icon: icon,
    title: title,
    subtitle: subtitle,
    value: value,
    onChanged: (v) => onChanged(v),
  );
}

/// A pushed view under Settings: the same title bar and column.
class HabitSettingsView extends StatelessWidget {
  final String title;
  final Listenable listenable;
  final List<Widget> Function(BuildContext context) children;
  const HabitSettingsView({
    super.key,
    required this.title,
    required this.listenable,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: listenable,
    builder: (context, _) => HandyPage(
      title: title,
      children: [
        const SizedBox(height: HandySpace.s),
        ...children(context),
      ],
    ),
  );
}

/// A kit settings section placed in a group: the kit pads its sections by
/// [HandySpace.xl] above and below; here that becomes the panel gap. A
/// section that hides itself takes no room at all.
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

const habitPreferenceKeys = {
  'studio',
  'showMoodToday',
  'theme',
  'locale',
  'density',
  'reducedMotion',
  'weekStart',
  'dayBoundaryMinutes',
  'backfill',
  'defaultGoal',
  'defaultSchedule',
  'routineAutoTimer',
  'routineHaptics',
  'confirmRoutineExit',
};

String habitZoneLabel(BuildContext context, String zone, DateTime now) {
  final minutes = location(
    zone,
  ).timeZone(now.millisecondsSinceEpoch).offset.inMinutes;
  final hours = minutes.abs() ~/ 60;
  final remainder = minutes.abs() % 60;
  final offset = minutes == 0
      ? 'GMT'
      : 'GMT${minutes < 0 ? '−' : '+'}$hours${remainder == 0 ? '' : ':${remainder.toString().padLeft(2, '0')}'}';
  final name = switch (zone) {
    'Asia/Ho_Chi_Minh' ||
    'Asia/Saigon' => tr(context, 'Vietnam time', 'Giờ Việt Nam'),
    'UTC' ||
    'Etc/UTC' ||
    'Etc/GMT' => tr(context, 'Coordinated universal time', 'Giờ quốc tế'),
    _ => zone.split('/').last.replaceAll('_', ' '),
  };
  return '$name ($offset)';
}
