import 'package:handy_ui/kit.dart';
import '../design/looks.dart';
import '../design/theme.dart';
import '../pro/pro.dart';

/// The board's looks along the foot of the board: a tap shows it on the
/// board above at once; nothing is kept until Apply.
class LookPicker extends StatelessWidget {
  final String current;
  final ValueChanged<String> onPick;
  final VoidCallback onCancel, onApply;

  /// The board's cover picture, changed from here too (one place for how
  /// the board looks).
  final VoidCallback? onCover;
  const LookPicker({
    super.key,
    required this.current,
    required this.onPick,
    required this.onCancel,
    required this.onApply,
    this.onCover,
  });

  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final theme = Theme.of(context);
    final chosen = lookById(current);
    final locked = chosen.pro && !hasPro(context);
    return Material(
      color: p.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(context, 'Look and cover', 'Giao diện và ảnh bìa'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (onCover != null)
                    TextButton.icon(
                      key: const Key('look-cover'),
                      onPressed: onCover,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(tr(context, 'Cover…', 'Ảnh bìa…')),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 112,
              child: ListView(
                key: const Key('look-list'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  for (final l in boardLooks)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Semantics(
                        button: true,
                        selected: l.id == current,
                        label: l.pro
                            ? '${tr(context, l.nameEn, l.nameVi)}, Pro'
                            : tr(context, l.nameEn, l.nameVi),
                        excludeSemantics: true,
                        child: InkWell(
                          key: Key('look-${l.id}'),
                          borderRadius: BorderRadius.circular(
                            BoardsRadii.control,
                          ),
                          onTap: () => onPick(l.id),
                          child: SizedBox(
                            width: 92,
                            child: Column(
                              children: [
                                Container(
                                  height: 60,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: l.page(context),
                                    borderRadius: BorderRadius.circular(
                                      BoardsRadii.control,
                                    ),
                                    border: Border.all(
                                      color: l.id == current
                                          ? p.primary
                                          : p.line,
                                      width: l.id == current ? 2.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      for (var i = 0; i < 3; i++) ...[
                                        if (i > 0) const SizedBox(width: 4),
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: l.column(context),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            padding: const EdgeInsets.all(3),
                                            alignment: Alignment.topCenter,
                                            child: Container(
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: p.surface,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        tr(context, l.nameEn, l.nameVi),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelMedium,
                                      ),
                                    ),
                                    if (l.pro) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.workspace_premium_outlined,
                                        size: 14,
                                        color: p.muted,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: TextButton(
                      key: const Key('look-cancel'),
                      onPressed: onCancel,
                      child: Text(tr(context, 'Cancel', 'Huỷ')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FilledButton(
                      key: const Key('look-apply'),
                      onPressed: onApply,
                      child: Text(
                        locked
                            ? tr(context, 'Apply with Pro', 'Dùng với Pro')
                            : tr(context, 'Apply', 'Áp dụng'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
