import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../bookmark/add_link.dart';
import '../design/theme.dart';
import '../scope.dart';

/// The save sheet's link field: a roomy field, Paste beside the one Save
/// button, and one line under the field that says what happened. The
/// typed text is kept through a failed save; it clears only once saved.
class LinkCapture extends StatefulWidget {
  final SaveScope scope;

  /// After a save: shows the link (by default its page).
  final void Function(BuildContext context, Bookmark saved)? onSaved;
  const LinkCapture({super.key, required this.scope, this.onSaved});
  @override
  State<LinkCapture> createState() => _LinkCaptureState();
}

enum _Said { help, noLink, saved, clipboardSeen, clipboardFailed }

class _LinkCaptureState extends State<LinkCapture> {
  final text = TextEditingController();
  bool busy = false;
  _Said said = _Said.help;
  int savedCount = 0;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> paste() async {
    if (busy) return;
    try {
      final value = await widget.scope.c.clipboard();
      if (!mounted) return;
      if (value == null) {
        setState(() => said = _Said.clipboardSeen);
        return;
      }
      text.value = TextEditingValue(
        text: value.trim(),
        selection: TextSelection.collapsed(offset: value.trim().length),
      );
      setState(
        () =>
            said = UrlTools.extract(value).isEmpty ? _Said.noLink : _Said.help,
      );
    } catch (_) {
      if (mounted) setState(() => said = _Said.clipboardFailed);
    }
  }

  Future<void> save() async {
    final value = text.text;
    if (busy || value.trim().isEmpty) return;
    final count = UrlTools.extract(value).length;
    if (count == 0) {
      setState(() => said = _Said.noLink);
      return;
    }
    setState(() {
      busy = true;
      said = _Said.help;
    });
    try {
      final show = await saveCapturedLinks(
        context,
        widget.scope,
        value,
        onSaved: () {
          if (!mounted) return;
          text.clear();
          setState(() {
            said = _Said.saved;
            savedCount = count;
          });
        },
      );
      if (show != null && mounted) {
        if (widget.onSaved != null) {
          widget.onSaved!(context, show);
        } else {
          await Navigator.pushNamed(context, '/bookmark/${show.id}');
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final empty = text.text.trim().isEmpty;
    final (line, color, icon) = switch (said) {
      _Said.noLink => (
        tr(
          context,
          'No link here yet. Links start with http:// or https://.',
          'Chưa thấy link nào. Link bắt đầu bằng http:// hoặc https://.',
        ),
        p.danger,
        Icons.error_outline,
      ),
      _Said.saved => (
        savedCount == 1
            ? tr(
                context,
                'Saved to Not sorted. Add another, or close.',
                'Đã lưu vào Chưa xếp. Lưu tiếp, hoặc đóng lại.',
              )
            : tr(
                context,
                '$savedCount links saved to Not sorted.',
                'Đã lưu $savedCount link vào Chưa xếp.',
              ),
        p.sage,
        Icons.check_circle_outline,
      ),
      _Said.clipboardSeen => (
        tr(
          context,
          'That clipboard text was already offered.',
          'Nội dung clipboard này đã được dùng.',
        ),
        p.muted,
        Icons.info_outline,
      ),
      _Said.clipboardFailed => (
        tr(
          context,
          'The clipboard could not be read. Type or paste the link instead.',
          'Chưa đọc được clipboard. Hãy gõ hoặc dán link vào ô.',
        ),
        p.danger,
        Icons.error_outline,
      ),
      _Said.help => (
        tr(
          context,
          'Kept on this device, even offline.',
          'Lưu trên máy này, kể cả khi không có mạng.',
        ),
        p.muted,
        null,
      ),
    };
    final pasteButton = OutlinedButton.icon(
      key: const Key('save-paste'),
      onPressed: busy ? null : paste,
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 50)),
      icon: const Icon(Icons.content_paste_rounded, size: 20),
      label: Text(tr(context, 'Paste', 'Dán')),
    );
    final saveButton = FilledButton(
      key: const Key('bookmark-inline-save'),
      onPressed: busy || empty ? null : save,
      // Words, not a spinner: the wait may be a question (already
      // saved?) rather than work, and the label says which state it is.
      child: Text(
        busy ? tr(context, 'Saving…', 'Đang lưu…') : tr(context, 'Save', 'Lưu'),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('bookmark-inline-url'),
          controller: text,
          enabled: !busy,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          minLines: 1,
          maxLines: 3,
          maxLength: 4096,
          style: theme.textTheme.bodyLarge,
          onChanged: (_) => setState(() {
            if (said != _Said.help) said = _Said.help;
          }),
          onSubmitted: (_) => save(),
          decoration: InputDecoration(
            hintText: tr(
              context,
              'Paste or type a link',
              'Dán hoặc gõ một link',
            ),
            counterText: '',
            prefixIcon: const Icon(Icons.link_rounded),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            fillColor: theme.brightness == Brightness.dark
                ? p.raised
                : p.canvas,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BookmarkRadii.field),
              borderSide: BorderSide.none,
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BookmarkRadii.field),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    line,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, box) => box.maxWidth < 260
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    saveButton,
                    const SizedBox(height: 8),
                    pasteButton,
                  ],
                )
              : Row(
                  children: [
                    pasteButton,
                    const SizedBox(width: 10),
                    Expanded(child: saveButton),
                  ],
                ),
        ),
      ],
    );
  }
}
