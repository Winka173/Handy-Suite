import 'package:handy_ui/kit.dart';
import 'share_how_to.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../welcome/motion.dart';

/// The + sheet beside Home's link field: the other ways to save. A
/// picture first; several links at once and how to save from other apps
/// stay quiet under it. A single link is typed in the field itself.
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
                  tr(sheet, 'More ways to save', 'Cách lưu khác'),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              _Way(
                key: const Key('save-photo'),
                icon: Icons.add_photo_alternate_outlined,
                title: tr(sheet, 'Save a picture', 'Lưu một ảnh'),
                note: tr(
                  sheet,
                  'A screenshot or photo, from your photos or files',
                  'Ảnh chụp màn hình hoặc ảnh, từ thư viện ảnh hay tệp',
                ),
                onTap: () {
                  close();
                  scope.addPhoto(context);
                },
              ),
              const SizedBox(height: 8),
              // The rarer ways stay quiet: several links at once, and
              // (where the system offers Share) how to save from apps.
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    key: const Key('save-add'),
                    onPressed: () {
                      close();
                      onAdd();
                    },
                    icon: const Icon(Icons.playlist_add_rounded, size: 20),
                    label: Text(
                      tr(sheet, 'Several links at once', 'Nhiều link một lúc'),
                    ),
                  ),
                  if (canReceiveShares)
                    TextButton.icon(
                      key: const Key('save-how'),
                      // The steps on one short sheet, not the whole guide.
                      onPressed: () {
                        close();
                        showShareHowTo(context);
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  },
);

/// The other way to save, a picture: a soft tile with its mark, name and
/// a short line on what it takes.
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
