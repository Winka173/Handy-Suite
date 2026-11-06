import 'dart:async';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';

/// Tags and the note, open on the page rather than behind Edit: tags as
/// chips with a remove mark and "Add tag", the note as a field that saves
/// itself a moment after typing stops and when it loses focus.
class DetailNotes extends StatefulWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const DetailNotes({super.key, required this.scope, required this.bookmark});
  @override
  State<DetailNotes> createState() => _DetailNotesState();
}

class _DetailNotesState extends State<DetailNotes> {
  late final _note = TextEditingController(text: widget.bookmark.note);
  final _focus = FocusNode();
  Timer? _wait;

  SaveScope get scope => widget.scope;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _saveNote();
    });
  }

  @override
  void didUpdateWidget(DetailNotes old) {
    super.didUpdateWidget(old);
    // A change made elsewhere (Edit, Undo) shows here unless typing.
    if (!_focus.hasFocus && widget.bookmark.note != _note.text)
      _note.text = widget.bookmark.note;
  }

  @override
  void dispose() {
    _wait?.cancel();
    _saveNote();
    _focus.dispose();
    _note.dispose();
    super.dispose();
  }

  void _saveNote() {
    _wait?.cancel();
    final b = scope.find(widget.bookmark.id);
    if (b == null || b.note == _note.text) return;
    unawaited(
      scope.put(b.copyWith(note: _note.text)).catchError((Object _) {}),
    );
  }

  Future<void> _setTags(List<String> tags) async {
    final b = scope.find(widget.bookmark.id);
    if (b == null) return;
    await scope.run(context, () => scope.put(b.copyWith(tags: tags)));
  }

  Future<void> _addTag() async {
    final b = widget.bookmark;
    final known = {
      ...scope.library.tags,
      ...scope.library.bookmarks.expand((x) => x.tags),
    }.where((t) => !b.tags.contains(t)).toList()..sort();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _AddTag(known: known),
    );
    final tag = picked?.trim().replaceFirst(RegExp(r'^#+'), '');
    if (tag == null || tag.isEmpty || b.tags.contains(tag) || !mounted) return;
    await _setTags([...b.tags, tag]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final b = widget.bookmark;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.s),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Column(
      key: const Key('detail-notes'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label(tr(context, 'Tags', 'Thẻ')),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final t in b.tags)
              InputChip(
                key: Key('detail-tag-$t'),
                label: Text('#$t'),
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/tag/${Uri.encodeComponent(t)}',
                ),
                deleteButtonTooltipMessage: tr(context, 'Remove #$t', 'Bỏ #$t'),
                onDeleted: () => _setTags([
                  for (final x in b.tags)
                    if (x != t) x,
                ]),
              ),
            ActionChip(
              key: const Key('detail-tag-add'),
              avatar: const Icon(Icons.add, size: 18),
              label: Text(tr(context, 'Add tag', 'Thêm thẻ')),
              onPressed: _addTag,
            ),
          ],
        ),
        const SizedBox(height: HandySpace.l),
        label(tr(context, 'Note', 'Ghi chú')),
        TextField(
          key: const Key('detail-note'),
          controller: _note,
          focusNode: _focus,
          minLines: 2,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          style: theme.textTheme.bodyLarge?.copyWith(color: p.ink),
          decoration: InputDecoration(
            hintText: tr(context, 'Tap to add a note…', 'Chạm để ghi chú…'),
            filled: true,
            fillColor: p.sageTint,
          ),
          onChanged: (_) {
            _wait?.cancel();
            _wait = Timer(const Duration(milliseconds: 700), _saveNote);
          },
          onTapOutside: (_) => _focus.unfocus(),
        ),
      ],
    );
  }
}

/// Type a tag, or pick one already used.
class _AddTag extends StatefulWidget {
  final List<String> known;
  const _AddTag({required this.known});
  @override
  State<_AddTag> createState() => _AddTagState();
}

class _AddTagState extends State<_AddTag> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typed = _text.text.trim().toLowerCase();
    final matches = [
      for (final t in widget.known)
        if (typed.isEmpty || t.toLowerCase().contains(typed)) t,
    ].take(12);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('tag-input'),
            controller: _text,
            autofocus: true,
            decoration: InputDecoration(
              prefixText: '#',
              hintText: tr(context, 'New tag', 'Thẻ mới'),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          if (matches.isNotEmpty) ...[
            const SizedBox(height: HandySpace.m),
            Wrap(
              spacing: HandySpace.s,
              runSpacing: HandySpace.s,
              children: [
                for (final t in matches)
                  ActionChip(
                    key: Key('tag-pick-$t'),
                    label: Text('#$t'),
                    onPressed: () => Navigator.pop(context, t),
                  ),
              ],
            ),
          ],
          const SizedBox(height: HandySpace.m),
          FilledButton(
            key: const Key('tag-add'),
            onPressed: typed.isEmpty
                ? null
                : () => Navigator.pop(context, _text.text),
            child: Text(tr(context, 'Add', 'Thêm')),
          ),
        ],
      ),
    );
  }
}
