import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';

/// The longest name a saved item may have (the engine's title bound).
const maxItemName = 8192;

/// [b] with the person's own name. Marked as the person's words
/// (`metadataSource: 'user'`), so reading the page again never replaces
/// it. The address, the picture and the ids stay as they were.
Bookmark renamedItem(Bookmark b, String name) =>
    b.copyWith(title: name.trim(), metadataSource: 'user');

extension RenameItem on SaveScope {
  /// Asks for a new name and writes it (undoable). The sheet stays open
  /// with the reason when the write fails, so nothing typed is lost.
  Future<void> rename(BuildContext context, Bookmark b) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) => RenameSheet(
        item: b,
        onSave: (name) async {
          final current = find(b.id);
          if (current == null)
            throw const FormatException(
              'This item was deleted / Mục này đã bị xóa',
            );
          await put(renamedItem(current, name));
        },
      ),
    );
    if (done == true && context.mounted)
      undoMessage(context, tr(context, 'Renamed.', 'Đã đổi tên.'));
  }
}

/// One field and Save: the name, selected so typing replaces it.
class RenameSheet extends StatefulWidget {
  final Bookmark item;
  final Future<void> Function(String name) onSave;
  const RenameSheet({super.key, required this.item, required this.onSave});
  @override
  State<RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<RenameSheet> {
  late final TextEditingController name =
      TextEditingController(text: widget.item.title)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.item.title.length,
        );
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    name.addListener(() {
      if (error != null) setState(() => error = null);
    });
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  bool get _ready =>
      !saving &&
      name.text.trim().isNotEmpty &&
      name.text.trim() != widget.item.title;

  Future<void> _save() async {
    if (!_ready) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(name.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() {
          saving = false;
          error = tr(
            context,
            'Not saved: ${errorText(context, e)}. The old name is kept.',
            'Chưa lưu được: ${errorText(context, e)}. Tên cũ vẫn giữ nguyên.',
          );
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final b = widget.item;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        key: const Key('rename-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              tr(context, 'Rename', 'Đổi tên'),
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            b.isImage
                ? tr(
                    context,
                    'The picture itself stays as it is.',
                    'Ảnh vẫn giữ nguyên.',
                  )
                : tr(
                    context,
                    'Only the name changes. Reading the page again will not replace it.',
                    'Chỉ đổi tên. Đọc lại trang cũng không thay tên này.',
                  ),
            style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('rename-field'),
            controller: name,
            autofocus: true,
            maxLength: maxItemName,
            minLines: 1,
            maxLines: 3,
            enabled: !saving,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: tr(context, 'Name', 'Tên'),
              counterText: '',
              errorText: error,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('rename-cancel'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: Text(tr(context, 'Cancel', 'Hủy')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('rename-save'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _ready ? _save : null,
                  child: saving
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: tr(context, 'Saving', 'Đang lưu'),
                          ),
                        )
                      : Text(tr(context, 'Save', 'Lưu')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
