import 'package:handy_ui/kit.dart';

/// Asked when leaving the editor with words not yet saved: 'save',
/// 'discard', or null to keep writing.
Future<String?> askLeave(BuildContext context) async {
  return showAdaptiveDialog<String>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(tr(context, 'Save the draft first?', 'Lưu bản nháp trước?')),
      content: Text(
        tr(
          context,
          'Your latest changes are only on screen until you save.',
          'Những thay đổi mới chỉ ở trên màn hình cho tới khi bạn lưu.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Keep writing', 'Viết tiếp')),
        ),
        TextButton(
          key: const Key('write-leave-discard'),
          onPressed: () => Navigator.pop(context, 'discard'),
          child: Text(tr(context, 'Discard changes', 'Bỏ thay đổi')),
        ),
        FilledButton(
          key: const Key('write-leave-save'),
          onPressed: () => Navigator.pop(context, 'save'),
          child: Text(tr(context, 'Save', 'Lưu')),
        ),
      ],
    ),
  );
}
