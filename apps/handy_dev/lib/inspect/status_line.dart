import 'package:handy_ui/kit.dart';

/// One segment of the status line: plain text, or a good/bad signal.
class StatusPart {
  final String text;
  final bool? good;
  const StatusPart(this.text, {this.good});
}

/// Dev's signature: an editor's status line under the result. What the data
/// is, how big, whether it is valid, and the path of the chosen node, which
/// copies on tap.
class StatusLine extends StatelessWidget {
  final List<StatusPart> parts;
  final String? path;
  const StatusLine({super.key, required this.parts, this.path});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(fontFeatures: tabular);
    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      if (i > 0)
        children.add(Text(' · ', style: small?.copyWith(color: c.muted)));
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p.good != null) ...[
              Icon(
                p.good! ? Icons.check_circle : Icons.error,
                size: 14,
                color: p.good! ? c.accent : c.negative,
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                p.text,
                style: small?.copyWith(
                  color: p.good == false
                      ? c.negative
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      key: const Key('status-line'),
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: HandySpace.m,
        vertical: HandySpace.xs,
      ),
      decoration: BoxDecoration(
        color: c.select,
        borderRadius: BorderRadius.circular(HandyRadius.control),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 2,
              children: children,
            ),
          ),
          if (path != null)
            Semantics(
              button: true,
              label: tr(context, 'Copy path $path', 'Chép đường dẫn $path'),
              excludeSemantics: true,
              child: InkWell(
                key: const Key('status-path'),
                borderRadius: BorderRadius.circular(HandyRadius.control),
                onTap: () => copyToClipboard(context, path!),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 48,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HandySpace.s,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            path!,
                            overflow: TextOverflow.ellipsis,
                            style: small?.copyWith(
                              fontFamily: 'GeistMono',
                              package: 'handy_ui',
                              color: c.selectInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 14, color: c.selectInk),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `2.412` bytes → `2,4 KB`, in the reader's own number style.
String formatBytes(BuildContext context, int bytes) {
  if (bytes < 1024) return '${formatFigure(context, '$bytes')} B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${formatFigure(context, kb.toStringAsFixed(1))} KB';
  return '${formatFigure(context, (kb / 1024).toStringAsFixed(1))} MB';
}
