import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../bookmark/add_link.dart';
import '../design/theme.dart';
import '../controller.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';

enum _Problem { none, noLink, notWeb, clipboardSeen, clipboardFailed }

/// Home's one way to save: a single-line link field, and beside it the
/// one general Save control. Empty, it is + (a picture, several links,
/// saving from apps); with text in the field it says Save and saves that
/// text. The text stays through a failed save and clears once saved.
class QuickSaveBar extends StatefulWidget {
  final SaveScope scope;

  /// The + sheet: a picture, several links, Share help.
  final VoidCallback onMore;

  /// Where a save goes when the person is inside a collection.
  final String? collectionId;
  const QuickSaveBar({
    super.key,
    required this.scope,
    required this.onMore,
    this.collectionId,
  });
  @override
  State<QuickSaveBar> createState() => _QuickSaveBarState();
}

class _QuickSaveBarState extends State<QuickSaveBar> {
  final text = TextEditingController();
  bool busy = false;
  _Problem problem = _Problem.none;

  SaveScope get scope => widget.scope;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> paste() async {
    if (busy) return;
    try {
      final value = await scope.c.clipboard();
      if (!mounted) return;
      if (value == null) {
        setState(() => problem = _Problem.clipboardSeen);
        return;
      }
      final v = value.trim();
      text.value = TextEditingValue(
        text: v,
        selection: TextSelection.collapsed(offset: v.length),
      );
      setState(() => problem = _check(v));
    } catch (_) {
      if (mounted) setState(() => problem = _Problem.clipboardFailed);
    }
  }

  /// Why [value] cannot be saved, before anything is written.
  _Problem _check(String value) {
    if (UrlTools.extract(value).isNotEmpty) return _Problem.none;
    return RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(value)
        ? _Problem.notWeb
        : _Problem.noLink;
  }

  Future<void> save() async {
    final value = text.text.trim();
    if (busy || value.isEmpty) return;
    final problem = _check(value);
    if (problem != _Problem.none) {
      setState(() => this.problem = problem);
      return;
    }
    setState(() {
      busy = true;
      this.problem = _Problem.none;
    });
    final before = {for (final b in scope.library.bookmarks) b.id};
    try {
      final show = await saveCapturedLinks(
        context,
        scope,
        value,
        collectionId: widget.collectionId,
        onSavedItems: (saved) {
          if (!mounted) return;
          text.clear();
          _announce(saved, before);
        },
      );
      if (show != null && mounted)
        await Navigator.pushNamed(context, '/bookmark/${show.id}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Saved: where it went, View, and Undo for what is new (to Trash, so
  /// nothing is ever lost by a quick tap).
  void _announce(List<Bookmark> saved, Set<String> before) {
    final fresh = [
      for (final b in saved)
        if (!before.contains(b.id)) b.id,
    ];
    final first = saved.firstOrNull;
    final into = widget.collectionId == null
        ? null
        : collectionOf(scope.library, widget.collectionId)?.$1.name;
    final where = into ?? tr(context, 'Not sorted', 'Chưa xếp');
    final message = fresh.isEmpty
        ? tr(context, 'Already saved.', 'Đã có sẵn.')
        : fresh.length == 1
        ? tr(context, 'Saved to $where.', 'Đã lưu vào $where.')
        : tr(
            context,
            '${fresh.length} links saved to $where.',
            'Đã lưu ${fresh.length} link vào $where.',
          );
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final theme = Theme.of(context);
    final nav = Navigator.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('quick-saved'),
          content: Row(
            children: [
              Expanded(child: Text(message)),
              if (first != null)
                TextButton(
                  key: const Key('quick-view'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        theme.snackBarTheme.actionTextColor ??
                        theme.colorScheme.inversePrimary,
                    // The same weight as Undo beside it.
                    textStyle:
                        (theme.snackBarTheme.contentTextStyle ??
                                theme.textTheme.bodyMedium)
                            ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    nav.pushNamed('/bookmark/${first.id}');
                  },
                  child: Text(tr(context, 'View', 'Xem')),
                ),
            ],
          ),
          action: fresh.isEmpty
              ? null
              : SnackBarAction(
                  key: const Key('quick-undo'),
                  label: tr(context, 'Undo', 'Hoàn tác'),
                  onPressed: () =>
                      scope.c.update((l) => moveToTrash(l, fresh, saveTime())),
                ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final empty = text.text.trim().isEmpty;
    final line = switch (problem) {
      _Problem.none => null,
      _Problem.noLink => tr(
        context,
        'No link in this text. Links start with http:// or https://.',
        'Chưa thấy link nào. Link bắt đầu bằng http:// hoặc https://.',
      ),
      _Problem.notWeb => tr(
        context,
        'Only web links (http or https) can be saved.',
        'Chỉ lưu được link web (http hoặc https).',
      ),
      _Problem.clipboardSeen => tr(
        context,
        'That clipboard text was already offered.',
        'Nội dung clipboard này đã được dùng.',
      ),
      _Problem.clipboardFailed => tr(
        context,
        'The clipboard could not be read. Type or paste the link instead.',
        'Chưa đọc được clipboard. Hãy gõ hoặc dán link vào ô.',
      ),
    };
    final radius = BorderRadius.circular(BookmarkRadii.field);
    final field = TextField(
      key: const Key('bookmark-inline-url'),
      controller: text,
      readOnly: busy,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      maxLength: 4096,
      style: theme.textTheme.bodyLarge,
      onChanged: (_) => setState(() => problem = _Problem.none),
      onSubmitted: (_) => save(),
      decoration: InputDecoration(
        hintText: tr(context, 'Paste a link to save…', 'Dán link để lưu…'),
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: theme.brightness == Brightness.dark ? p.raised : p.surface,
        prefixIcon: const Icon(Icons.link_rounded),
        suffixIcon: empty
            ? IconButton(
                key: const Key('save-paste'),
                tooltip: tr(context, 'Paste', 'Dán'),
                onPressed: busy ? null : paste,
                icon: const Icon(Icons.content_paste_rounded),
              )
            : IconButton(
                key: const Key('quick-clear'),
                tooltip: tr(context, 'Clear', 'Xóa chữ'),
                onPressed: busy
                    ? null
                    : () => setState(() {
                        text.clear();
                        problem = _Problem.none;
                      }),
                icon: const Icon(Icons.close_rounded),
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: problem == _Problem.none
              ? BorderSide.none
              : BorderSide(color: p.danger, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: problem == _Problem.none ? p.primary : p.danger,
            width: 1.5,
          ),
        ),
      ),
    );
    final button = empty
        ? IconButton.filled(
            key: const Key('save-new'),
            tooltip: tr(
              context,
              'Save a picture, several links…',
              'Lưu ảnh, nhiều link…',
            ),
            style: IconButton.styleFrom(
              fixedSize: const Size(52, 52),
              shape: RoundedRectangleBorder(borderRadius: radius),
            ),
            onPressed: busy ? null : widget.onMore,
            icon: const Icon(Icons.add_rounded, size: 26),
          )
        : FilledButton(
            key: const Key('bookmark-inline-save'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(76, 52),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(borderRadius: radius),
            ),
            onPressed: busy ? null : save,
            // Words, not a spinner: the wait may be a question (already
            // saved?) rather than work.
            child: Text(
              busy
                  ? tr(context, 'Saving…', 'Đang lưu…')
                  : tr(context, 'Save', 'Lưu'),
            ),
          );
    return Column(
      key: const Key('quick-save'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: field),
            const SizedBox(width: HandySpace.s),
            button,
          ],
        ),
        Semantics(
          liveRegion: true,
          child: HandyReveal(
            child: line == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.error_outline,
                            size: 16,
                            color: p.danger,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            line,
                            key: const Key('quick-problem'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: p.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
