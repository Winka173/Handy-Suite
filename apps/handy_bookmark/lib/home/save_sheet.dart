import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../welcome/motion.dart';
import 'link_capture.dart';

/// The one Save button's sheet. A link comes first (type it, or Paste,
/// then Save); below it, the two other ways in: several links at once, or
/// a picture. On phones it also points to saving from other apps, which
/// needs no sheet at all.
Future<void> showSaveSheet(
  BuildContext context,
  SaveScope scope, {
  required Future<void> Function({bool clipboard}) onAdd,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (sheet) {
    void close() => Navigator.of(sheet).pop();
    final theme = Theme.of(sheet);
    final p = BookmarkPalette.of(sheet);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            key: const Key('save-sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  tr(sheet, 'Save something', 'Lưu một mục'),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              LinkCapture(
                scope: scope,
                onSaved: (_, saved) {
                  close();
                  Navigator.of(context).pushNamed('/bookmark/${saved.id}');
                },
              ),
              const SizedBox(height: 24),
              Text(
                tr(sheet, 'Or add', 'Hoặc thêm'),
                style: theme.textTheme.titleSmall?.copyWith(color: p.muted),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (_, box) {
                  final several = _Way(
                    key: const Key('save-add'),
                    icon: Icons.playlist_add_rounded,
                    title: tr(sheet, 'Several links', 'Nhiều link'),
                    note: tr(
                      sheet,
                      'A list, one per line',
                      'Một danh sách, mỗi dòng một link',
                    ),
                    onTap: () {
                      close();
                      onAdd();
                    },
                  );
                  final picture = _Way(
                    key: const Key('save-photo'),
                    icon: Icons.add_photo_alternate_outlined,
                    title: tr(sheet, 'A picture', 'Một ảnh'),
                    note: tr(
                      sheet,
                      'From photos or files',
                      'Từ thư viện ảnh hoặc tệp',
                    ),
                    onTap: () {
                      close();
                      scope.addPhoto(context);
                    },
                  );
                  // Side by side while each keeps room for its words.
                  final scale = MediaQuery.textScalerOf(sheet).scale(1);
                  if (box.maxWidth / scale < 300) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [several, const SizedBox(height: 10), picture],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: several),
                        const SizedBox(width: 10),
                        Expanded(child: picture),
                      ],
                    ),
                  );
                },
              ),
              if (canReceiveShares) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const Key('save-how'),
                    onPressed: () {
                      close();
                      Navigator.of(context).pushNamed('/welcome');
                    },
                    icon: const Icon(Icons.ios_share_rounded, size: 20),
                    label: Text(
                      tr(
                        sheet,
                        'Save from other apps with Share',
                        'Lưu từ app khác bằng nút Chia sẻ',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  },
);

/// One other way to save: a soft tile with its mark, name and a short
/// line on what it takes.
class _Way extends StatelessWidget {
  final IconData icon;
  final String title, note;
  final VoidCallback onTap;
  const _Way({
    super.key,
    required this.icon,
    required this.title,
    required this.note,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: dark ? p.raised : p.canvas,
      borderRadius: BorderRadius.circular(BookmarkRadii.item),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 26, color: dark ? p.primary : p.pressed),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(note, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Save button that opens [showSaveSheet].
class SaveButton extends StatelessWidget {
  final SaveScope scope;
  final Future<void> Function({bool clipboard}) onAdd;
  final bool expand;
  const SaveButton({
    super.key,
    required this.scope,
    required this.onAdd,
    this.expand = false,
  });
  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      key: const Key('save-new'),
      onPressed: () => showSaveSheet(context, scope, onAdd: onAdd),
      icon: const Icon(Icons.add),
      label: Text(tr(context, 'Save', 'Lưu')),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
