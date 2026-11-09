import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n.dart';
import 'palette.dart';
import 'theme.dart';

/// One readable column, centred on wide screens; the child takes its full
/// width so every block shares the same left and right edges.
class HandyContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const HandyContent({
    super.key,
    required this.child,
    this.maxWidth = HandySpace.content,
  });
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// Pushed page: title bar, one scrolling column, and an optional pinned
/// bottom bar that holds the screen's single primary action.
class HandyPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  final Widget? bottom;
  final Widget? body;
  const HandyPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.children = const [],
    this.bottom,
    this.body,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Wide screens put the title on the content column's left edge.
    final wide = MediaQuery.sizeOf(context).width >= HandySpace.wide;
    return Scaffold(
      appBar: AppBar(
        title: wide ? null : Text(title),
        actions: [
          ...actions,
          const SizedBox(width: HandySpace.xs),
        ],
      ),
      body: SafeArea(
        bottom: bottom == null,
        child:
            body ??
            ListView(
              padding: const EdgeInsets.fromLTRB(
                HandySpace.l,
                0,
                HandySpace.l,
                HandySpace.xxl,
              ),
              children: [
                if (wide)
                  HandyContent(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: HandySpace.s),
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  ),
                if (subtitle != null)
                  HandyContent(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: HandySpace.s),
                      child: Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: HandyColors.of(context).muted,
                        ),
                      ),
                    ),
                  ),
                for (final child in children) HandyContent(child: child),
              ],
            ),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : HandyBottomBar(child: bottom!),
    );
  }
}

class HandyBottomBar extends StatelessWidget {
  final Widget child;
  const HandyBottomBar({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.ground,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(HandySpace.m),
          child: HandyContent(child: child),
        ),
      ),
    );
  }
}

/// Heading above a group, in the brand's way (`HandyHeading`).
class HandyLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const HandyLabel(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final heading = HandyBrand.current.heading;
    final label = switch (heading) {
      HandyHeading.caps => Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: c.muted,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      ),
      HandyHeading.mono => Row(
        children: [
          ExcludeSemantics(
            child: Text(
              '// ',
              style: theme.textTheme.labelLarge?.copyWith(
                fontFamily: handyFontFamily('GeistMono'),
                color: c.accent,
              ),
            ),
          ),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.labelLarge?.copyWith(
                fontFamily: handyFontFamily('GeistMono'),
                color: c.muted,
              ),
            ),
          ),
        ],
      ),
      HandyHeading.large ||
      HandyHeading.rule => Text(text, style: theme.textTheme.titleLarge),
      HandyHeading.plain => Text(text, style: theme.textTheme.titleMedium),
    };
    final row = SizedBox(
      height: trailing == null ? null : 48,
      child: Row(
        children: [
          Expanded(
            child: heading == HandyHeading.caps
                // Read in the words' own case, not letter by letter.
                ? Semantics(
                    header: true,
                    label: text,
                    child: ExcludeSemantics(child: label),
                  )
                : Semantics(header: true, child: label),
          ),
          ?trailing,
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        2,
        heading == HandyHeading.large ? HandySpace.xxl : HandySpace.xl,
        trailing == null ? 2 : 0,
        HandySpace.s,
      ),
      child: heading == HandyHeading.rule
          ? DecoratedBox(
              // A newspaper's section head: an ink rule, then the name.
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.colorScheme.onSurface, width: 2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: HandySpace.s),
                child: row,
              ),
            )
          : row,
    );
  }
}

/// Rows split by faint rules: on a panel, or open on the page between
/// hairlines (`HandyRows.open`).
class HandyGroup extends StatelessWidget {
  final List<Widget> children;

  /// Fill for the panel that answers the screen's question.
  final Color? color;
  const HandyGroup({super.key, required this.children, this.color});
  @override
  Widget build(BuildContext context) {
    final open = HandyBrand.current.rows == HandyRows.open;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Divider(indent: open ? 0 : HandySpace.l));
      rows.add(children[i]);
    }
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
    if (open) {
      final c = HandyColors.of(context);
      return DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          border: Border(
            top: BorderSide(color: c.border),
            bottom: BorderSide(color: c.border),
          ),
        ),
        child: ListTileTheme.merge(
          contentPadding: const EdgeInsets.symmetric(horizontal: HandySpace.xs),
          child: column,
        ),
      );
    }
    return Card(color: color, clipBehavior: Clip.antiAlias, child: column);
  }
}

class HandySection extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final List<Widget> children;
  const HandySection({
    super.key,
    this.title,
    this.trailing,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (title != null)
        HandyLabel(title!, trailing: trailing)
      else
        const SizedBox(height: HandySpace.l),
      HandyGroup(children: children),
    ],
  );
}

/// List row: optional 20px grey outline icon, label, value or chevron.
class HandyTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool navigates, destructive;
  final int subtitleLines;

  /// The identity colour (`HandyPalette`) of what this row belongs to, as a
  /// dot before the subtitle, which names it. The icon stays grey.
  final int? hue;
  const HandyTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.subtitleLines = 2,
    this.trailing,
    this.onTap,
    this.navigates = false,
    this.destructive = false,
    this.hue,
  });
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final color = destructive ? c.negative : null;
    return ListTile(
      leading: icon == null ? null : Icon(icon, size: 20, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null
          ? null
          : Text.rich(
              TextSpan(
                children: [
                  if (hue != null) ...[
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: HandyDot(hue!, size: 8),
                    ),
                    const TextSpan(text: ' '),
                  ],
                  TextSpan(text: subtitle),
                ],
              ),
              maxLines: subtitleLines,
              overflow: TextOverflow.ellipsis,
            ),
      trailing:
          trailing ??
          (navigates ? Icon(Icons.chevron_right, color: c.muted) : null),
      onTap: onTap,
    );
  }
}

/// A form field with its label above it and any limit visible beneath.
class HandyField extends StatelessWidget {
  final String label;
  final String? help;
  final Widget child;
  const HandyField({
    super.key,
    required this.label,
    this.help,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: theme.textTheme.titleSmall),
          const SizedBox(height: HandySpace.s),
          child,
          if (help != null) ...[
            const SizedBox(height: 6),
            Text(help!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class HandySearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  const HandySearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.autofocus = false,
  });
  @override
  State<HandySearchField> createState() => _HandySearchFieldState();
}

class _HandySearchFieldState extends State<HandySearchField> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: widget.autofocus,
    maxLength: 200,
    textInputAction: TextInputAction.search,
    onChanged: (v) {
      setState(() {});
      widget.onChanged(v);
    },
    decoration: InputDecoration(
      hintText: widget.hint,
      counterText: '',
      prefixIcon: const Icon(Icons.search, size: 20),
      suffixIcon: controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: tr(context, 'Clear search', 'Xóa tìm kiếm'),
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                controller.clear();
                setState(() {});
                widget.onChanged('');
              },
            ),
    ),
  );
}

/// An empty block keeps its frame: one sentence, and the next step if any.
class HandyEmpty extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? action;
  const HandyEmpty({super.key, required this.title, this.message, this.action});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HandySpace.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HandyRadius.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: HandySpace.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: HandySpace.l),
            action!,
          ],
        ],
      ),
    );
  }
}

enum HandyTone { info, warning, error, success }

/// Inline message in the block it concerns. Pale tint, dark text, same hue.
class HandyNotice extends StatelessWidget {
  final String message;
  final HandyTone tone;
  final Widget? action;
  const HandyNotice(
    this.message, {
    super.key,
    this.tone = HandyTone.info,
    this.action,
  });
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final (icon, ink, bg) = switch (tone) {
      HandyTone.error => (Icons.error_outline, c.negative, c.negativeBg),
      HandyTone.warning => (
        Icons.warning_amber_rounded,
        c.warning,
        c.warningBg,
      ),
      HandyTone.success => (Icons.check, c.positive, c.positiveBg),
      HandyTone.info => (Icons.info_outline, c.muted, c.raised),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HandySpace.m,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(HandyRadius.control),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ink),
          const SizedBox(width: HandySpace.s),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tone == HandyTone.info
                    ? Theme.of(context).colorScheme.onSurface
                    : ink,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class HandyMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  final Key? key;
  const HandyMenuItem(
    this.icon,
    this.label,
    this.onTap, {
    this.destructive = false,
    this.key,
  });
}

/// `⋯` overflow for everything that is not the primary action.
class HandyMenuButton extends StatelessWidget {
  final List<HandyMenuItem> items;
  final String? tooltip;
  const HandyMenuButton({super.key, required this.items, this.tooltip});
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    return PopupMenuButton<int>(
      key: const Key('more-menu'),
      tooltip: tooltip ?? tr(context, 'More', 'Thêm'),
      icon: const Icon(Icons.more_horiz),
      position: PopupMenuPosition.under,
      onSelected: (i) => items[i].onTap?.call(),
      itemBuilder: (context) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem<int>(
            key: items[i].key,
            value: i,
            enabled: items[i].onTap != null,
            height: 44,
            child: Row(
              children: [
                Icon(
                  items[i].icon,
                  size: 18,
                  color: items[i].destructive ? c.negative : c.muted,
                ),
                const SizedBox(width: HandySpace.m),
                Flexible(
                  child: Text(
                    items[i].label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: items[i].destructive ? c.negative : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The screen's answer. Short values are set large in the app's data hue;
/// long values read as a block of text in ink.
class HandyResultView extends StatelessWidget {
  final String value;
  final String? caption;
  final bool monospace, money;
  const HandyResultView(
    this.value, {
    super.key,
    this.caption,
    this.monospace = false,
    this.money = false,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final short = !value.contains('\n') && value.length <= 24 && !monospace;
    final style = short
        ? theme.textTheme.headlineMedium?.copyWith(
            color: c.accent,
            fontWeight: money ? FontWeight.w700 : FontWeight.w500,
          )
        : theme.textTheme.bodyLarge?.copyWith(
            fontFamily: monospace ? 'GeistMono' : null,
            package: monospace ? 'handy_ui' : null,
            fontFeatures: tabular,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (caption != null) ...[
          Text(
            caption!,
            style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
          ),
          const SizedBox(height: HandySpace.xs),
        ],
        // Selectable without becoming a tiny read-only text field for
        // assistive tech; Copy is the primary way out.
        SelectionArea(
          child: Text(
            short ? formatFigure(context, value) : value,
            key: const Key('result-value'),
            style: style,
          ),
        ),
      ],
    );
  }
}

/// Labelled figures: label left in grey, value right in ink, one right edge.
/// [lead] marks the row that answers the screen's question.
class HandyValueRows extends StatelessWidget {
  final List<(String, String)> rows;
  final int lead;
  const HandyValueRows(this.rows, {super.key, this.lead = -1});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return HandyGroup(
      color: c.lead,
      children: [
        // Each row copies its own figure (the engine value, not the
        // formatted one): "just the interest" is one tap.
        for (var i = 0; i < rows.length; i++)
          Semantics(
            button: true,
            label: '${rows[i].$1}: ${formatFigure(context, rows[i].$2)}',
            hint: tr(context, 'Copy this figure', 'Chép con số này'),
            excludeSemantics: true,
            child: InkWell(
              key: Key('value-row-$i'),
              onTap: () => copyToClipboard(context, rows[i].$2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: HandySpace.l,
                    vertical: i == lead ? 14 : 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          rows[i].$1,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: c.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: HandySpace.m),
                      Expanded(
                        flex: 3,
                        child: Text(
                          formatFigure(context, rows[i].$2),
                          textAlign: TextAlign.end,
                          style:
                              (i == lead
                                      ? theme.textTheme.titleLarge?.copyWith(
                                          color: c.accent,
                                        )
                                      : theme.textTheme.bodyLarge)
                                  ?.copyWith(fontFeatures: tabular),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Future<bool> confirmHandy(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async =>
    await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) {
        final c = HandyColors.of(context);
        final ios = Theme.of(context).platform == TargetPlatform.iOS;
        Widget action(
          Key? key,
          String label,
          bool value, {
          bool primary = false,
        }) => ios
            ? CupertinoDialogAction(
                key: key,
                isDestructiveAction: primary && destructive,
                isDefaultAction: primary && !destructive,
                onPressed: () => Navigator.pop(context, value),
                child: Text(label),
              )
            : primary
            ? FilledButton(
                key: key,
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: c.negative,
                        foregroundColor: Colors.white,
                      )
                    : null,
                onPressed: () => Navigator.pop(context, value),
                child: Text(label),
              )
            : TextButton(
                key: key,
                onPressed: () => Navigator.pop(context, value),
                child: Text(label),
              );
        return AlertDialog.adaptive(
          title: Text(title),
          content: message == null ? null : Text(message),
          actions: [
            action(
              const Key('confirm-cancel'),
              cancelLabel ?? tr(context, 'Cancel', 'Hủy'),
              false,
            ),
            action(
              const Key('confirm-action'),
              confirmLabel,
              true,
              primary: true,
            ),
          ],
        );
      },
    ) ??
    false;

void showHandyMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // Shown long enough to act on, then it goes (with an action
        // Flutter would keep it until dismissed).
        persist: false,
        content: Text(message),
      ),
    );
}

Future<void> copyToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android))
    await HapticFeedback.selectionClick();
  if (context.mounted)
    showHandyMessage(context, tr(context, 'Copied', 'Đã sao chép'));
}
