import 'package:flutter/services.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../bookmark/add_link.dart';
import '../scope.dart';
import '../shell/share_issues.dart';
import 'scenes.dart';

/// Step three's real controls: type or paste a link, or choose a picture.
/// A share from another app is noticed by the guide itself, so all three
/// ways end the same: the item is saved and stays.
class FirstSave extends StatefulWidget {
  final SaveScope scope;

  /// A link saved here (or an older copy the person chose to keep).
  final ValueChanged<Bookmark> onSaved;
  const FirstSave({super.key, required this.scope, required this.onSaved});
  @override
  State<FirstSave> createState() => _FirstSaveState();
}

class _FirstSaveState extends State<FirstSave> {
  final text = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> _save(String value) async {
    if (busy || value.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      final saved = await saveCapturedLinks(context, widget.scope, value);
      if (saved != null) widget.onSaved(saved);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _paste() async {
    final value = (await Clipboard.getData('text/plain'))?.text ?? '';
    if (!mounted) return;
    if (value.trim().isEmpty) {
      showHandyMessage(
        context,
        tr(
          context,
          'Nothing to paste. Copy a link first.',
          'Chưa có gì để dán. Hãy chép một link trước.',
        ),
      );
      return;
    }
    await _save(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('welcome-url'),
          controller: text,
          enabled: !busy,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 4096,
          onChanged: (_) => setState(() {}),
          onSubmitted: _save,
          decoration: InputDecoration(
            labelText: tr(context, 'Link to save', 'Link cần lưu'),
            hintText: 'https://',
            counterText: '',
            suffixIcon: IconButton(
              key: const Key('welcome-url-save'),
              tooltip: tr(context, 'Save link', 'Lưu link'),
              onPressed: busy || text.text.trim().isEmpty
                  ? null
                  : () => _save(text.text),
              icon: const Icon(Icons.bookmark_add_outlined),
            ),
          ),
        ),
        const SizedBox(height: HandySpace.m),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: [
            OutlinedButton.icon(
              key: const Key('welcome-paste'),
              onPressed: busy ? null : _paste,
              icon: const Icon(Icons.content_paste),
              label: Text(tr(context, 'Paste a link', 'Dán link')),
            ),
            OutlinedButton.icon(
              key: const Key('welcome-photo'),
              onPressed: busy ? null : () => widget.scope.addPhoto(context),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(tr(context, 'Choose a picture', 'Chọn ảnh')),
            ),
          ],
        ),
        if (canReceiveShares) ...[
          const SizedBox(height: HandySpace.l),
          Text(
            tr(
              context,
              'Or share something from another app now. This page will notice it.',
              'Hoặc chia sẻ từ app khác ngay bây giờ. Trang này sẽ tự nhận ra.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
          ),
        ],
        ShareIssues(controller: widget.scope.c),
      ],
    );
  }
}
