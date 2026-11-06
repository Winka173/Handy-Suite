import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';

/// Find in the article: the words, "3 of 12", previous, next, close.
/// Enter goes to the next match, Shift+Enter to the previous, Esc closes.
/// On a narrow screen or with large text the count and arrows take a
/// second line, so the field keeps room to type.
class ReaderFindBar extends StatelessWidget {
  const ReaderFindBar({
    super.key,
    required this.controller,
    required this.focus,
    required this.count,
    required this.current,
    required this.capped,
    required this.onChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final int count;
  final int? current;
  final bool capped;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext, onPrevious, onClose;

  String _count(BuildContext context) {
    if (controller.text.trim().isEmpty) return '';
    if (count == 0) return tr(context, 'No matches', 'Không thấy');
    final total = capped ? '$count+' : '$count';
    return tr(
      context,
      '${(current ?? 0) + 1} of $total',
      '${(current ?? 0) + 1}/$total',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context);
    final label = _count(context);
    final countText = Semantics(
      liveRegion: true,
      child: Text(
        label,
        key: const Key('reader-find-count'),
        maxLines: 1,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: count == 0 ? p.muted : p.ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    final field = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): onNext,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): onNext,
        const SingleActivator(LogicalKeyboardKey.enter, shift: true):
            onPrevious,
        const SingleActivator(LogicalKeyboardKey.numpadEnter, shift: true):
            onPrevious,
        const SingleActivator(LogicalKeyboardKey.escape): onClose,
      },
      child: TextField(
        key: const Key('reader-find-field'),
        controller: controller,
        focusNode: focus,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onNext(),
        // Keep the keyboard up between matches.
        onEditingComplete: () {},
        decoration: InputDecoration(
          isDense: true,
          hintText: tr(context, 'Find in article', 'Tìm trong bài'),
          prefixIcon: const Icon(Icons.search, size: 20),
        ),
      ),
    );
    final has = count > 0;
    final prev = IconButton(
      key: const Key('reader-find-prev'),
      tooltip: tr(context, 'Previous match', 'Kết quả trước'),
      onPressed: has ? onPrevious : null,
      icon: const Icon(Icons.keyboard_arrow_up),
    );
    final next = IconButton(
      key: const Key('reader-find-next'),
      tooltip: tr(context, 'Next match', 'Kết quả sau'),
      onPressed: has ? onNext : null,
      icon: const Icon(Icons.keyboard_arrow_down),
    );
    final close = IconButton(
      key: const Key('reader-find-close'),
      tooltip: tr(context, 'Close find', 'Đóng tìm kiếm'),
      onPressed: onClose,
      icon: const Icon(Icons.close),
    );
    return Material(
      color: p.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.line)),
        ),
        padding: const EdgeInsets.fromLTRB(
          HandySpace.l,
          HandySpace.s,
          HandySpace.xs,
          HandySpace.s,
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final wide =
                box.maxWidth >=
                3 * 48 + scale.scale(14) * 5 + scale.scale(16) * 7 + 12;
            if (wide) {
              return Row(
                children: [
                  Expanded(child: field),
                  const SizedBox(width: HandySpace.m),
                  countText,
                  prev,
                  next,
                  close,
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: field),
                    close,
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: countText),
                    prev,
                    next,
                    const SizedBox(width: 48),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
