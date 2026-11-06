import 'dart:math';

import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'ui/collection_picker.dart';

String _newId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256),
).map((n) => n.toRadixString(16).padLeft(2, '0')).join();

String _invalid(BuildContext context) => tr(
  context,
  'Check the fields and try again. Your changes have not been saved.',
  'Hãy kiểm tra các trường và thử lại. Thay đổi của bạn chưa được lưu.',
);

/// The frame every Save editor shares: close on the left, Save in the bar
/// at the foot, the form in one readable column. Cancel returns nothing.
class _EditorPage extends StatelessWidget {
  final String title;
  final GlobalKey<FormState> form;
  final VoidCallback save;
  final List<Widget> children;
  final String? error;
  const _EditorPage({
    required this.title,
    required this.form,
    required this.save,
    required this.children,
    this.error,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        key: const Key('editor-cancel'),
        tooltip: tr(context, 'Cancel', 'Hủy'),
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(title),
    ),
    bottomNavigationBar: HandyBottomBar(
      child: FilledButton(
        key: const Key('editor-save'),
        onPressed: save,
        child: Text(tr(context, 'Save', 'Lưu')),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(HandySpace.l),
      children: [
        HandyContent(
          // Labels stay above their value, never inside as a placeholder.
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: Theme.of(context).inputDecorationTheme
                  .copyWith(
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
            ),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HandyReveal(
                    child: error == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(
                              bottom: HandySpace.l,
                            ),
                            child: Semantics(
                              liveRegion: true,
                              child: HandyNotice(error!, tone: HandyTone.error),
                            ),
                          ),
                  ),
                  for (final child in children)
                    Padding(
                      padding: const EdgeInsets.only(bottom: HandySpace.l),
                      child: child,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class BookmarkEditor extends StatefulWidget {
  final Bookmark initial;
  final SaveLibrary library;
  const BookmarkEditor({
    super.key,
    required this.initial,
    required this.library,
  });
  @override
  State<BookmarkEditor> createState() => _BookmarkEditorState();
}

class _BookmarkEditorState extends State<BookmarkEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _url, _title, _description, _note, _tags;
  late String _collection;
  late bool _favorite, _pinned, _archived, _read;
  String? _error;
  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    _url = TextEditingController(text: b.originalUrl);
    _title = TextEditingController(text: b.title);
    _description = TextEditingController(text: b.description ?? '');
    _note = TextEditingController(text: b.note);
    _tags = TextEditingController(text: b.tags.join(', '));
    _collection = b.collectionId ?? '';
    _favorite = b.isFavorite;
    _pinned = b.isPinned;
    _archived = b.isArchived;
    _read = b.isRead;
  }

  @override
  void dispose() {
    for (final controller in [_url, _title, _description, _note, _tags]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    try {
      final previous = widget.initial;
      final url = UrlTools.normalize(_url.text.trim());
      final changedUrl = url.originalUrl != previous.originalUrl;
      final result = previous.copyWith(
        originalUrl: url.originalUrl,
        normalizedUrl: changedUrl ? url.normalizedUrl : previous.normalizedUrl,
        canonicalUrl: changedUrl ? null : previous.canonicalUrl,
        platform: changedUrl ? url.platform : previous.platform,
        sourceDomain: changedUrl ? url.sourceDomain : previous.sourceDomain,
        contentType: changedUrl ? url.contentType : previous.contentType,
        thumbnailUrl: changedUrl ? null : previous.thumbnailUrl,
        siteName: changedUrl ? null : previous.siteName,
        author: changedUrl ? null : previous.author,
        metadataStatus: changedUrl ? 'pending' : previous.metadataStatus,
        // A check describes the address it checked.
        linkCheck: changedUrl ? null : previous.linkCheck,
        metadataSource: 'user',
        title: _title.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        note: _note.text,
        tags: _tags.text == previous.tags.join(', ')
            ? previous.tags
            : _tags.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList(),
        collectionId: _collection.isEmpty ? null : _collection,
        isFavorite: _favorite,
        isPinned: _pinned,
        isArchived: _archived,
        isRead: _read,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
      widget.library
          .copyWith(
            bookmarks: [
              for (final b in widget.library.bookmarks)
                if (b.id != result.id) b,
              result,
            ],
          )
          .validate();
      Navigator.pop(context, result);
    } catch (_) {
      setState(() => _error = _invalid(context));
    }
  }

  @override
  Widget build(BuildContext context) => _EditorPage(
    title: tr(context, 'Edit bookmark', 'Sửa dấu trang'),
    form: _form,
    save: _save,
    error: _error,
    children: [
      TextFormField(
        key: const Key('bookmark-url'),
        controller: _url,
        maxLength: 8192,
        keyboardType: TextInputType.url,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: tr(context, 'Original URL', 'URL gốc'),
        ),
        validator: (value) {
          try {
            final u = UrlTools.normalize(value ?? '');
            if (Uri.parse(u.originalUrl).userInfo.isNotEmpty)
              return tr(
                context,
                'Remove login details from the URL',
                'Xóa thông tin đăng nhập khỏi URL',
              );
            return null;
          } catch (_) {
            return tr(
              context,
              'Enter a valid HTTP or HTTPS URL',
              'Nhập URL HTTP hoặc HTTPS hợp lệ',
            );
          }
        },
      ),
      TextFormField(
        key: const Key('bookmark-title'),
        controller: _title,
        maxLength: 8192,
        decoration: InputDecoration(labelText: tr(context, 'Title', 'Tiêu đề')),
      ),
      TextFormField(
        key: const Key('bookmark-description'),
        controller: _description,
        maxLength: 65536,
        minLines: 2,
        maxLines: 5,
        decoration: InputDecoration(
          labelText: tr(context, 'Note (optional)', 'Ghi chú (không bắt buộc)'),
        ),
      ),
      TextFormField(
        key: const Key('bookmark-note'),
        controller: _note,
        maxLength: 262144,
        minLines: 3,
        maxLines: 8,
        decoration: InputDecoration(labelText: tr(context, 'Notes', 'Ghi chú')),
      ),
      TextFormField(
        key: const Key('bookmark-tags'),
        controller: _tags,
        onChanged: (_) => setState(() {}),
        maxLength: 262144,
        decoration: InputDecoration(
          labelText: tr(
            context,
            'Tags, separated by commas',
            'Nhãn, phân cách bằng dấu phẩy',
          ),
        ),
        validator: (value) =>
            (value ?? '').split(',').any((s) => s.trim().length > 512)
            ? tr(
                context,
                'Each tag can contain up to 512 characters',
                'Mỗi nhãn tối đa 512 ký tự',
              )
            : null,
      ),
      if (_tags.text.split(',').last.trim().isNotEmpty)
        Wrap(
          spacing: 6,
          children: [
            for (final suggestion
                in {
                      ...widget.library.tags,
                      ...widget.library.bookmarks.expand((b) => b.tags),
                    }
                    .where(
                      (tag) => tag.toLowerCase().startsWith(
                        _tags.text.split(',').last.trim().toLowerCase(),
                      ),
                    )
                    .take(8))
              ActionChip(
                label: Text(suggestion),
                onPressed: () => setState(() {
                  final pieces = _tags.text.split(',')..removeLast();
                  _tags.text = [
                    ...pieces.map((v) => v.trim()),
                    suggestion,
                    '',
                  ].join(', ');
                }),
              ),
          ],
        ),
      DropdownButtonFormField<String>(
        key: const Key('bookmark-collection'),
        initialValue: _collection,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: tr(context, 'Collection', 'Bộ sưu tập'),
        ),
        items: [
          DropdownMenuItem(
            value: '',
            child: Text(tr(context, 'Not sorted', 'Chưa xếp')),
          ),
          for (final c in widget.library.collections)
            DropdownMenuItem(
              value: c.id,
              child: Text(c.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) => setState(() => _collection = value ?? ''),
      ),
      // The item's states, together in one soft panel.
      _Panel(
        children: [
          SwitchListTile.adaptive(
            title: Text(tr(context, 'Favorite', 'Yêu thích')),
            value: _favorite,
            onChanged: (v) => setState(() => _favorite = v),
          ),
          // Pins are retired (2026-11-06): a save pinned before keeps its
          // switch so it can be unpinned; nothing new is pinned.
          if (widget.initial.isPinned)
            SwitchListTile.adaptive(
              key: const Key('bookmark-pinned'),
              title: Text(tr(context, 'Pinned', 'Đã ghim')),
              value: _pinned,
              onChanged: (v) => setState(() => _pinned = v),
            ),
          SwitchListTile.adaptive(
            title: Text(tr(context, 'Archived', 'Đã lưu trữ')),
            value: _archived,
            onChanged: (v) => setState(() => _archived = v),
          ),
          SwitchListTile.adaptive(
            title: Text(tr(context, 'Read', 'Đã đọc')),
            value: _read,
            onChanged: (v) => setState(() => _read = v),
          ),
        ],
      ),
    ],
  );
}

class CollectionEditor extends StatefulWidget {
  final SaveCollection? initial;
  final SaveLibrary library;
  const CollectionEditor({super.key, this.initial, required this.library});
  @override
  State<CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends State<CollectionEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _description;
  late final String _id;
  late String _parent;

  /// Kept as they were; the app shows each collection in its own place's
  /// colour, so the editor no longer asks for one.
  late final String _color, _icon;
  String? _error;
  static const _colors = [
    '#6366F1',
    '#0EA5E9',
    '#10B981',
    '#F59E0B',
    '#EF4444',
    '#EC4899',
  ];
  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _id = c?.id ?? _newId();
    _name = TextEditingController(text: c?.name ?? '');
    _description = TextEditingController(text: c?.description ?? '');
    _parent = c?.parentId ?? '';
    _color = c?.color ?? _colors.first;
    _icon = c?.icon ?? 'folder';
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool _validParent(String? selected) {
    final byId = {for (final c in widget.library.collections) c.id: c};
    String? current = selected == '' ? null : selected;
    final seen = <String>{};
    while (current != null) {
      if (current == _id || !seen.add(current) || !byId.containsKey(current))
        return false;
      current = byId[current]!.parentId;
    }
    return true;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    try {
      final result = SaveCollection(
        id: _id,
        name: _name.text.trim(),
        description: _description.text.trim(),
        parentId: _parent.isEmpty ? null : _parent,
        color: _color,
        icon: _icon,
        position: widget.initial?.position ?? widget.library.collections.length,
      );
      widget.library
          .copyWith(
            collections: [
              for (final c in widget.library.collections)
                if (c.id != result.id) c,
              result,
            ],
          )
          .validate();
      Navigator.pop(context, result);
    } catch (_) {
      setState(() => _error = _invalid(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorPage(
      title: widget.initial == null
          ? tr(context, 'New collection', 'Bộ sưu tập mới')
          : tr(context, 'Edit collection', 'Sửa bộ sưu tập'),
      form: _form,
      save: _save,
      error: _error,
      children: [
        TextFormField(
          key: const Key('collection-name'),
          controller: _name,
          maxLength: 8192,
          decoration: InputDecoration(labelText: tr(context, 'Name', 'Tên')),
          validator: (v) => v == null || v.trim().isEmpty
              ? tr(context, 'Enter a name', 'Nhập tên')
              : null,
        ),
        DropdownButtonFormField<String>(
          key: const Key('collection-parent'),
          initialValue: _parent,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tr(context, 'Inside', 'Nằm trong'),
            helperText: tr(
              context,
              'Optional: put it inside another collection',
              'Không bắt buộc: đặt trong một bộ sưu tập khác',
            ),
          ),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(tr(context, 'None', 'Không có')),
            ),
            for (final (c, depth) in collectionTree(widget.library))
              if (c.id != _id)
                DropdownMenuItem(
                  value: c.id,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(start: depth * 16.0),
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
          ],
          onChanged: (v) => setState(() => _parent = v ?? ''),
          validator: (v) => _validParent(v)
              ? null
              : tr(
                  context,
                  'Choose a parent outside this collection',
                  'Chọn bộ sưu tập cha không nằm trong bộ sưu tập này',
                ),
        ),
        TextFormField(
          key: const Key('collection-description'),
          controller: _description,
          maxLength: 65536,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: tr(
              context,
              'Note (optional)',
              'Ghi chú (không bắt buộc)',
            ),
          ),
        ),
      ],
    );
  }
}

class _RuleDraft {
  String field, operator;
  bool boolean;
  final TextEditingController value;
  final String id = _newId();
  _RuleDraft(SmartRule rule)
    : field = rule.field,
      operator = rule.operator,
      boolean = rule.value == true,
      value = TextEditingController(text: rule.value?.toString() ?? '');
  bool get isBoolean =>
      operator == 'exists' ||
      {'isRead', 'isFavorite', 'isPinned', 'isArchived'}.contains(field);
  bool get isDate => {'savedAt', 'updatedAt', 'reminderAt'}.contains(field);
  bool get isNumber => operator == 'withinDays' || field == 'openedCount';
  List<String> get operators => isDate
      ? ['withinDays', 'before', 'after']
      : {'isRead', 'isFavorite', 'isPinned', 'isArchived'}.contains(field)
      ? ['equals', 'notEquals']
      : field == 'openedCount'
      ? ['equals', 'greaterThan', 'lessThan']
      : field == 'collectionId'
      ? ['equals', 'notEquals']
      : ['equals', 'contains', 'notEquals'];
  void changeField(String next) {
    field = next;
    operator = isDate ? 'withinDays' : 'equals';
    boolean = false;
    value.text = isDate ? '7' : '';
  }

  Object? parsedValue() {
    if (isBoolean) return boolean;
    if (isNumber) return int.parse(value.text.trim());
    if (isDate)
      return DateTime.parse(value.text.trim()).toUtc().toIso8601String();
    if (field == 'collectionId' && value.text.isEmpty) return null;
    return value.text.trim();
  }

  SmartRule build() =>
      SmartRule(field: field, operator: operator, value: parsedValue());
}

class SmartCollectionEditor extends StatefulWidget {
  final SmartCollection? initial;
  final SaveLibrary library;
  const SmartCollectionEditor({super.key, this.initial, required this.library});
  @override
  State<SmartCollectionEditor> createState() => _SmartCollectionEditorState();
}

class _SmartCollectionEditorState extends State<SmartCollectionEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final List<_RuleDraft> _rules;
  late final String _id;
  late String _mode;
  String? _error;
  static const _fields = [
    'platform',
    'isRead',
    'isFavorite',
    'tags',
    'collectionId',
    'sourceDomain',
    'savedAt',
  ];
  @override
  void initState() {
    super.initState();
    _id = widget.initial?.id ?? _newId();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _mode = widget.initial?.mode ?? 'all';
    _rules =
        (widget.initial?.rules.isNotEmpty == true
                ? widget.initial!.rules
                : [
                    SmartRule(
                      field: 'isRead',
                      operator: 'equals',
                      value: false,
                    ),
                  ])
            .map(_RuleDraft.new)
            .toList();
  }

  @override
  void dispose() {
    _name.dispose();
    for (final rule in _rules) {
      rule.value.dispose();
    }
    super.dispose();
  }

  String _fieldLabel(String value) => switch (value) {
    'platform' => tr(context, 'Platform', 'Nền tảng'),
    'isRead' => tr(context, 'Read', 'Đã đọc'),
    'isFavorite' => tr(context, 'Favorite', 'Yêu thích'),
    'tags' => tr(context, 'Tags', 'Nhãn'),
    'collectionId' => tr(context, 'Collection', 'Bộ sưu tập'),
    'sourceDomain' => tr(context, 'Website domain', 'Tên miền trang web'),
    'savedAt' => tr(context, 'Saved date', 'Ngày lưu'),
    'updatedAt' => tr(context, 'Updated date', 'Ngày cập nhật'),
    'reminderAt' => tr(context, 'Reminder date', 'Ngày nhắc'),
    'isPinned' => tr(context, 'Pinned', 'Đã ghim'),
    'isArchived' => tr(context, 'Archived', 'Đã lưu trữ'),
    'openedCount' => tr(context, 'Times opened', 'Số lần mở'),
    'title' => tr(context, 'Title', 'Tiêu đề'),
    'note' => tr(context, 'Notes', 'Ghi chú'),
    'text' => tr(context, 'All text', 'Tất cả văn bản'),
    'contentType' => tr(context, 'Content type', 'Loại nội dung'),
    _ => tr(context, 'Field', 'Trường'),
  };
  String _operatorLabel(String value) => switch (value) {
    'equals' => tr(context, 'Is', 'Là'),
    'notEquals' => tr(context, 'Is not', 'Không là'),
    'contains' => tr(context, 'Contains', 'Chứa'),
    'before' => tr(context, 'Before', 'Trước'),
    'after' => tr(context, 'After', 'Sau'),
    'withinDays' => tr(
      context,
      'Within the last days',
      'Trong số ngày gần nhất',
    ),
    'greaterThan' => tr(context, 'Greater than', 'Lớn hơn'),
    'lessThan' => tr(context, 'Less than', 'Nhỏ hơn'),
    'exists' => tr(context, 'Has a value', 'Có giá trị'),
    _ => tr(context, 'Matches', 'Khớp'),
  };
  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_rules.isEmpty || _rules.length > 12) {
      setState(
        () => _error = tr(
          context,
          'Use between 1 and 12 rules',
          'Sử dụng từ 1 đến 12 quy tắc',
        ),
      );
      return;
    }
    try {
      final result = SmartCollection(
        id: _id,
        name: _name.text.trim(),
        mode: _mode,
        rules: _rules.map((rule) => rule.build()).toList(),
      );
      widget.library
          .copyWith(
            smartCollections: [
              for (final collection in widget.library.smartCollections)
                if (collection.id != result.id) collection,
              result,
            ],
          )
          .validate();
      Navigator.pop(context, result);
    } catch (_) {
      setState(() => _error = _invalid(context));
    }
  }

  String? _validateValue(_RuleDraft draft, String? input) {
    final value = input?.trim() ?? '';
    if (draft.isNumber) {
      final number = int.tryParse(value);
      if (number == null ||
          number < (draft.operator == 'withinDays' ? 1 : 0) ||
          number > 36500) {
        return tr(
          context,
          'Enter a whole number between 1 and 36500',
          'Nhập số nguyên từ 1 đến 36500',
        );
      }
    } else if (draft.isDate) {
      final date = DateTime.tryParse(value);
      if (date == null ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}($|T)').hasMatch(value) ||
          (value.length == 10 && !date.toIso8601String().startsWith(value))) {
        return tr(
          context,
          'Enter a valid date, such as 2026-12-31',
          'Nhập ngày hợp lệ, ví dụ 2026-12-31',
        );
      }
    } else if (value.isEmpty) {
      return tr(context, 'Enter a value', 'Nhập giá trị');
    }
    return null;
  }

  Widget _valueEditor(_RuleDraft rule, int index) {
    if (rule.isBoolean) {
      return DropdownButtonFormField<bool>(
        isExpanded: true,
        key: ValueKey('smart-value-$index-${rule.field}-${rule.operator}'),
        initialValue: rule.boolean,
        decoration: InputDecoration(labelText: tr(context, 'Value', 'Giá trị')),
        items: [
          DropdownMenuItem(value: true, child: Text(tr(context, 'Yes', 'Có'))),
          DropdownMenuItem(
            value: false,
            child: Text(tr(context, 'No', 'Không')),
          ),
        ],
        onChanged: (v) => setState(() => rule.boolean = v ?? false),
      );
    }
    if (rule.field == 'collectionId') {
      final selected = rule.value.text;
      return DropdownButtonFormField<String>(
        key: ValueKey('smart-value-$index-${rule.field}-${rule.operator}'),
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: tr(context, 'Collection', 'Bộ sưu tập'),
        ),
        items: [
          DropdownMenuItem(
            value: '',
            child: Text(tr(context, 'Not sorted', 'Chưa xếp')),
          ),
          for (final c in widget.library.collections)
            DropdownMenuItem(
              value: c.id,
              child: Text(c.name, overflow: TextOverflow.ellipsis),
            ),
          if (selected.isNotEmpty &&
              !widget.library.collections.any((c) => c.id == selected))
            DropdownMenuItem(
              value: selected,
              child: Text(
                tr(
                  context,
                  'Unavailable collection',
                  'Bộ sưu tập không còn khả dụng',
                ),
              ),
            ),
        ],
        validator: (v) =>
            v != null &&
                (v.isEmpty || widget.library.collections.any((c) => c.id == v))
            ? null
            : tr(
                context,
                'Choose an available collection',
                'Chọn bộ sưu tập còn khả dụng',
              ),
        onChanged: (v) => setState(() => rule.value.text = v ?? ''),
      );
    }
    return TextFormField(
      key: ValueKey('smart-value-$index-${rule.field}-${rule.operator}'),
      controller: rule.value,
      maxLength: rule.isNumber ? 5 : 8192,
      keyboardType: rule.isNumber
          ? TextInputType.number
          : rule.isDate
          ? TextInputType.datetime
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: rule.operator == 'withinDays'
            ? tr(context, 'Number of days', 'Số ngày')
            : rule.isDate
            ? tr(
                context,
                'Date (YYYY-MM-DD or ISO 8601)',
                'Ngày (YYYY-MM-DD hoặc ISO 8601)',
              )
            : tr(context, 'Value', 'Giá trị'),
        hintText: rule.field == 'platform'
            ? 'youtube, facebook, instagram…'
            : rule.field == 'sourceDomain'
            ? 'example.com'
            : null,
      ),
      validator: (value) => _validateValue(rule, value),
    );
  }

  Widget _ruleEditor(_RuleDraft rule, int index) {
    final operators = {...rule.operators, rule.operator};
    return Card(
      key: ValueKey(rule.id),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${tr(context, 'Rule', 'Quy tắc')} ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: ValueKey('smart-remove-$index'),
                  tooltip: tr(context, 'Remove rule', 'Xóa quy tắc'),
                  onPressed: _rules.length <= 1
                      ? null
                      : () {
                          setState(() => _rules.remove(rule));
                          rule.value.dispose();
                        },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey('smart-field-$index'),
              initialValue: rule.field,
              decoration: InputDecoration(
                labelText: tr(context, 'Field', 'Trường'),
              ),
              items: [
                for (final field in {..._fields, rule.field})
                  DropdownMenuItem(
                    value: field,
                    child: Text(
                      _fieldLabel(field),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => rule.changeField(v));
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey('smart-operator-$index-${rule.field}'),
              initialValue: rule.operator,
              decoration: InputDecoration(
                labelText: tr(context, 'Condition', 'Điều kiện'),
              ),
              items: [
                for (final op in operators)
                  DropdownMenuItem(
                    value: op,
                    child: Text(
                      _operatorLabel(op),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null)
                  setState(() {
                    rule.operator = v;
                    rule.value.clear();
                  });
              },
            ),
            const SizedBox(height: 16),
            _valueEditor(rule, index),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _EditorPage(
    title: widget.initial == null
        ? tr(context, 'New smart collection', 'Bộ sưu tập thông minh mới')
        : tr(context, 'Edit smart collection', 'Sửa bộ sưu tập thông minh'),
    form: _form,
    save: _save,
    error: _error,
    children: [
      TextFormField(
        key: const Key('smart-name'),
        controller: _name,
        maxLength: 8192,
        decoration: InputDecoration(labelText: tr(context, 'Name', 'Tên')),
        validator: (v) => v == null || v.trim().isEmpty
            ? tr(context, 'Enter a name', 'Nhập tên')
            : null,
      ),
      DropdownButtonFormField<String>(
        isExpanded: true,
        key: const Key('smart-mode'),
        initialValue: _mode,
        decoration: InputDecoration(labelText: tr(context, 'Match', 'Khớp')),
        items: [
          DropdownMenuItem(
            value: 'all',
            child: Text(tr(context, 'All rules (AND)', 'Tất cả quy tắc (VÀ)')),
          ),
          DropdownMenuItem(
            value: 'any',
            child: Text(
              tr(context, 'Any rule (OR)', 'Bất kỳ quy tắc nào (HOẶC)'),
            ),
          ),
        ],
        onChanged: (v) => setState(() => _mode = v ?? 'all'),
      ),
      for (var i = 0; i < _rules.length; i++) _ruleEditor(_rules[i], i),
      OutlinedButton.icon(
        key: const Key('smart-add'),
        onPressed: _rules.length >= 12
            ? null
            : () => setState(
                () => _rules.add(
                  _RuleDraft(
                    SmartRule(
                      field: 'isRead',
                      operator: 'equals',
                      value: false,
                    ),
                  ),
                ),
              ),
        icon: const Icon(Icons.add),
        label: Text(tr(context, 'Add rule', 'Thêm quy tắc')),
      ),
      Text(
        tr(
          context,
          'Use 1–12 rules. Changes are saved only when you choose Save.',
          'Sử dụng 1–12 quy tắc. Thay đổi chỉ được lưu khi bạn chọn Lưu.',
        ),
      ),
    ],
  );
}

/// Switches grouped on one rounded surface, parted by tone from the page.
class _Panel extends StatelessWidget {
  final List<Widget> children;
  const _Panel({required this.children});
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Column(mainAxisSize: MainAxisSize.min, children: children),
  );
}
