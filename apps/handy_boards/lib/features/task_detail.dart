import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../scope.dart';
import '../ui/form.dart';
import 'editors.dart';
import 'task_tools.dart';
import 'exam_editor.dart';
import '../ui/labels.dart';

Future<void> showTask(BuildContext context, BoardsScope scope, String id) =>
    Navigator.of(context).pushNamed('/task/$id', arguments: scope);

class TaskDetail extends StatelessWidget {
  final BoardsScope scope;
  final String id;
  const TaskDetail({super.key, required this.scope, required this.id});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: scope.controller,
    builder: (context, _) {
      final s = scope.state, t = s.maybe('tasks', id);
      if (t == null)
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Text(
              tr(context, 'Task no longer exists', 'Task không còn tồn tại'),
            ),
          ),
        );
      final checklist =
          s.rows('checklist').where((r) => r.str('task') == id).toList()
            ..sort((a, b) => a.number('order').compareTo(b.number('order')));
      final children = s
          .rows('tasks')
          .where((r) => r.str('parent') == id && !r.flag('trashed'))
          .toList();
      final events = s
          .rows('events')
          .where((r) => r.str('task') == id)
          .toList()
          .reversed
          .take(100);
      return Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'Task', 'Task')),
          actions: [
            IconButton(
              tooltip: tr(context, 'Edit task', 'Sửa task'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: scope.controller.busy
                  ? null
                  : () =>
                        scope.run(context, () => editTask(context, scope, id)),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => scope.run(context, () async {
                switch (v) {
                  case 'copy':
                    await Clipboard.setData(
                      ClipboardData(
                        text: '${t.str('title')}\n${t.str('notes')}',
                      ),
                    );
                  case 'duplicate':
                    await scope.controller.change(
                      (s) => duplicateTask(s, id, now: scope.clock()),
                    );
                  case 'archive':
                    await scope.controller.change(
                      (s) => s.put(
                        'tasks',
                        t.copy({'archived': !t.flag('archived')}),
                      ),
                    );
                  case 'trash':
                    if (await confirmBoards(
                      context,
                      tr(context, 'Move to trash?', 'Chuyển vào thùng rác?'),
                      t.str('title'),
                    )) {
                      await scope.controller.change(
                        (s) => trashTasks(s, {id}, restore: t.flag('trashed')),
                      );
                    }
                  case 'move':
                    if (context.mounted)
                      await moveTaskDialog(context, scope, t);
                }
              }),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'copy',
                  child: Text(tr(context, 'Copy text', 'Sao chép văn bản')),
                ),
                PopupMenuItem(
                  value: 'duplicate',
                  child: Text(
                    tr(context, 'Duplicate safely', 'Nhân bản an toàn'),
                  ),
                ),
                PopupMenuItem(
                  value: 'move',
                  child: Text(
                    tr(context, 'Move to board/category', 'Chuyển bảng/nhóm'),
                  ),
                ),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(
                    tr(
                      context,
                      t.flag('archived') ? 'Unarchive' : 'Archive',
                      t.flag('archived') ? 'Bỏ lưu trữ' : 'Lưu trữ',
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'trash',
                  child: Text(
                    tr(
                      context,
                      t.flag('trashed') ? 'Restore' : 'Move to trash',
                      t.flag('trashed') ? 'Khôi phục' : 'Chuyển vào thùng rác',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  t.str('title'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                if (t.str('kind') == 'exam') ...[
                  Text(
                    '${tr(context, 'Exam', 'Kỳ thi')}: ${object(t.data['exam'] ?? {})['location'] ?? '—'}',
                  ),
                  if (object(t.data['exam'] ?? {})['durationMinutes'] != null)
                    Text(
                      '${object(t.data['exam'])['durationMinutes']} ${tr(context, 'minutes', 'phút')}',
                    ),
                  if ((object(t.data['exam'] ?? {})['materials'] as String? ??
                          '')
                      .isNotEmpty)
                    Text(object(t.data['exam'])['materials']),
                  if (t.data['category'] != null)
                    TextButton(
                      onPressed: () => scope.run(
                        context,
                        () => editExam(
                          context,
                          scope,
                          t.str('board'),
                          t.str('category'),
                          task: t,
                        ),
                      ),
                      child: Text(
                        tr(
                          context,
                          'Edit exam details',
                          'Sửa thông tin kỳ thi',
                        ),
                      ),
                    ),
                ],
                Text(
                  s.maybe('categories', t.data['category'])?.str('title') ??
                      tr(context, 'Uncategorized', 'Chưa phân nhóm'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: t.str('status'),
                  key: ValueKey(t.str('status')),
                  isExpanded: true,
                  items: [
                    for (final st
                        in s
                            .rows('statuses')
                            .where((r) => r.str('board') == t.str('board')))
                      DropdownMenuItem(
                        value: st.id,
                        child: Text(st.str('title')),
                      ),
                  ],
                  onChanged: scope.controller.busy
                      ? null
                      : (v) => scope.run(
                          context,
                          () => scope.controller.change(
                            (s) => changeStatus(s, id, v!, now: scope.clock()),
                          ),
                        ),
                ),
                if (blocked(s, t))
                  Text(
                    tr(
                      context,
                      'Blocked by unfinished predecessors',
                      'Bị chặn bởi công việc trước chưa xong',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (s.maybe('statuses', t.data['suggestedStatus'])
                    case final BoardRecord suggested)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${tr(context, 'Suggested status', 'Trạng thái đề xuất')}: ${suggested.str('title')}',
                          ),
                          Wrap(
                            children: [
                              TextButton(
                                onPressed: () => scope.run(
                                  context,
                                  () => scope.controller.change(
                                    (s) => changeStatus(
                                      s,
                                      id,
                                      suggested.id,
                                      now: scope.clock(),
                                    ),
                                  ),
                                ),
                                child: Text(tr(context, 'Accept', 'Áp dụng')),
                              ),
                              TextButton(
                                onPressed: () => scope.run(
                                  context,
                                  () => scope.controller.change(
                                    (s) => s.put(
                                      'tasks',
                                      s.get('tasks', id).copy({
                                        'suggestedStatus': null,
                                      }),
                                    ),
                                  ),
                                ),
                                child: Text(tr(context, 'Dismiss', 'Bỏ qua')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (t.data['due'] != null)
                  Text(
                    '${tr(context, 'Due', 'Hạn')}: ${deadlineLabel(context, object(t.data['due']), s.get('boards', t.str('board')).str('zone'))}',
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => scope.run(
                        context,
                        () => taskTags(context, scope, id),
                      ),
                      icon: const Icon(Icons.sell_outlined),
                      label: Text(tr(context, 'Tags', 'Tag')),
                    ),
                    TextButton.icon(
                      onPressed: () => scope.run(
                        context,
                        () => taskRecurrence(context, scope, id),
                      ),
                      icon: const Icon(Icons.repeat),
                      label: Text(tr(context, 'Recurrence', 'Lặp lại')),
                    ),
                    TextButton.icon(
                      onPressed: () => scope.run(
                        context,
                        () => taskReminder(context, scope, id),
                      ),
                      icon: const Icon(Icons.notifications_outlined),
                      label: Text(tr(context, 'Reminder', 'Nhắc')),
                    ),
                    TextButton.icon(
                      onPressed: () => scope.run(
                        context,
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FocusPage(scope: scope, task: id),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.center_focus_strong),
                      label: Text(tr(context, 'Focus', 'Tập trung')),
                    ),
                    TextButton.icon(
                      onPressed: () => scope.run(
                        context,
                        () => taskCustomFields(context, scope, id),
                      ),
                      icon: const Icon(Icons.tune),
                      label: Text(
                        tr(context, 'Custom fields', 'Trường tùy chỉnh'),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => scope.run(
                        context,
                        () => boardForm(
                          context,
                          tr(
                            context,
                            'Add a dated note',
                            'Thêm ghi chú có ngày',
                          ),
                          [
                            const BoardField(
                              'body',
                              'Note',
                              'Ghi chú',
                              kind: 'note',
                            ),
                          ],
                          {'body': ''},
                          (v) async {
                            await scope.controller.change(
                              (s) => addComment(
                                s,
                                id,
                                v['body'],
                                now: scope.clock(),
                              ),
                            );
                          },
                        ),
                      ),
                      key: const Key('task-note'),
                      icon: const Icon(Icons.edit_note),
                      label: Text(tr(context, 'Note', 'Ghi chú')),
                    ),
                  ],
                ),
                for (final r
                    in s.rows('reminders').where((r) => r.str('task') == id))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${tr(context, 'Reminder', 'Nhắc')}: ${r.str('at')}',
                    ),
                    trailing: IconButton(
                      tooltip: tr(context, 'Remove reminder', 'Xóa nhắc'),
                      icon: const Icon(Icons.close),
                      onPressed: () => scope.run(
                        context,
                        () => scope.controller.change(
                          (s) => s.remove('reminders', {r.id}),
                        ),
                      ),
                    ),
                  ),
                for (final occurrence
                    in s.rows('occurrences').where((r) => r.str('task') == id))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${tr(context, 'Recurring occurrence', 'Lần lặp')}: ${occurrence.str('day')}',
                    ),
                    subtitle: Text(occurrence.str('state')),
                    trailing: TextButton(
                      onPressed: () => scope.run(
                        context,
                        () => scope.controller.change(
                          (s) => skipOccurrence(s, occurrence.id),
                        ),
                      ),
                      child: Text(
                        tr(context, 'Skip this occurrence', 'Bỏ qua lần này'),
                      ),
                    ),
                  ),
                for (final value in object(t.data['custom'] ?? {}).entries)
                  Text(
                    '${s.get('fields', value.key).str('title')}: ${value.value}',
                  ),
                if (t.str('notes').isNotEmpty)
                  MarkdownBody(
                    data: t.str('notes'),
                    selectable: true,
                    imageBuilder: (uri, title, alt) => Text(
                      alt ??
                          tr(
                            context,
                            'External image not loaded',
                            'Không tải ảnh bên ngoài',
                          ),
                    ),
                    onTapLink: (label, href, title) =>
                        scope.run(context, () async {
                          if (href == null) return;
                          final url = safeUrl(href);
                          if (await confirmBoards(
                            context,
                            tr(
                              context,
                              'Open external link?',
                              'Mở link bên ngoài?',
                            ),
                            href,
                          ))
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                        }),
                  ),
                const Divider(height: 32),
                _Heading(
                  tr(context, 'Checklist', 'Checklist'),
                  () => scope.run(
                    context,
                    () => boardForm(
                      context,
                      tr(context, 'Checklist item', 'Mục checklist'),
                      [const BoardField('title', 'Item', 'Nội dung')],
                      {'title': ''},
                      (v) async {
                        await scope.controller.change(
                          (s) => s.put(
                            'checklist',
                            BoardRecord({
                              'id': newId(),
                              'task': id,
                              'title': v['title'],
                              'order': checklist.length,
                              'done': false,
                            }),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Text(
                  '${checklist.where((r) => r.flag('done')).length} / ${checklist.length}',
                ),
                for (final r in checklist)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.str('title')),
                    value: r.flag('done'),
                    onChanged: scope.controller.busy
                        ? null
                        : (v) => scope.run(
                            context,
                            () => scope.controller.change(
                              (s) => toggleChecklist(
                                s,
                                r.id,
                                v!,
                                now: scope.clock(),
                              ),
                            ),
                          ),
                    secondary: PopupMenuButton<String>(
                      tooltip: tr(
                        context,
                        'Checklist actions',
                        'Thao tác checklist',
                      ),
                      onSelected: (action) => scope.run(
                        context,
                        () => scope.controller.change((s) {
                          if (action == 'remove')
                            return s.remove('checklist', {r.id});
                          final ids = checklist.map((r) => r.id).toList(),
                              i = ids.indexOf(r.id),
                              j = action == 'up' ? i - 1 : i + 1;
                          if (j < 0 || j >= ids.length) return s;
                          ids[i] = ids[j];
                          ids[j] = r.id;
                          return reorder(s, 'checklist', ids);
                        }),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'up',
                          child: Text(
                            tr(context, 'Move earlier', 'Chuyển lên'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'down',
                          child: Text(
                            tr(context, 'Move later', 'Chuyển xuống'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(tr(context, 'Remove item', 'Xóa mục')),
                        ),
                      ],
                    ),
                  ),
                _Heading(
                  tr(context, 'Subtasks', 'Task con'),
                  () => scope.run(
                    context,
                    () => quickTask(
                      context,
                      scope,
                      t.str('board'),
                      category: t.data['category'],
                      parent: id,
                    ),
                  ),
                ),
                for (final child in children)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(child.str('title')),
                    subtitle: Text(
                      s.get('statuses', child.str('status')).str('title'),
                    ),
                    onTap: () => showTask(context, scope, child.id),
                  ),
                _Heading(
                  tr(context, 'Predecessors', 'Công việc cần xong trước'),
                  () => scope.run(
                    context,
                    () => addPredecessor(context, scope, t),
                  ),
                ),
                for (final d
                    in s
                        .rows('dependencies')
                        .where((r) => r.str('after') == id))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.get('tasks', d.str('before')).str('title')),
                    trailing: IconButton(
                      tooltip: tr(context, 'Remove dependency', 'Gỡ phụ thuộc'),
                      icon: const Icon(Icons.link_off),
                      onPressed: () => scope.run(
                        context,
                        () => scope.controller.change(
                          (s) => s.remove('dependencies', {d.id}),
                        ),
                      ),
                    ),
                  ),
                _Heading(
                  tr(context, 'Attachments', 'Tệp đính kèm'),
                  () => scope.run(context, () => attachFile(context, scope, t)),
                ),
                TextButton.icon(
                  onPressed: () =>
                      scope.run(context, () => attachLink(context, scope, t)),
                  icon: const Icon(Icons.link),
                  label: Text(tr(context, 'Attach link', 'Đính kèm link')),
                ),
                for (final a
                    in s.rows('attachments').where((r) => r.str('task') == id))
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (a.data['preview'] != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: s.hasFile(a.str('preview'))
                              ? FutureBuilder<Uint8List>(
                                  future: s.readFile(a.str('preview')),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError)
                                      return Text(
                                        tr(
                                          context,
                                          'Preview unavailable; original file is retained',
                                          'Không mở được ảnh xem trước; vẫn giữ tệp gốc',
                                        ),
                                      );
                                    if (!snapshot.hasData)
                                      return const SizedBox(
                                        height: 180,
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    return Image.memory(
                                      snapshot.data!,
                                      height: 180,
                                      fit: BoxFit.contain,
                                      cacheWidth: 640,
                                      errorBuilder: (context, error, stack) => Text(
                                        tr(
                                          context,
                                          'Preview unavailable; original file is retained',
                                          'Không mở được ảnh xem trước; vẫn giữ tệp gốc',
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Text(
                                  tr(
                                    context,
                                    'Preview is missing; original file can still be exported',
                                    'Thiếu ảnh xem trước; vẫn có thể xuất tệp gốc',
                                  ),
                                ),
                        ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(a.str('name', a.str('url'))),
                        subtitle: Text(
                          a.data['path'] == null
                              ? 'HTTP(S)'
                              : tr(
                                  context,
                                  'Managed copy',
                                  'Bản sao trong app',
                                ),
                        ),
                        onTap: () => scope.run(context, () async {
                          if (a.data['path'] != null) {
                            await scope.files.exportBytes(
                              a.str('name'),
                              await s.readFile(a.str('path')),
                              mimeType: 'application/octet-stream',
                            );
                          } else if (await confirmBoards(
                            context,
                            tr(
                              context,
                              'Open external link?',
                              'Mở link bên ngoài?',
                            ),
                            a.str('url'),
                          )) {
                            await launchUrl(
                              safeUrl(a.str('url')),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        }),
                        trailing: IconButton(
                          tooltip: tr(context, 'Detach', 'Gỡ tệp'),
                          icon: const Icon(Icons.close),
                          onPressed: () => scope.run(
                            context,
                            () => scope.controller.change(
                              (s) => s.remove('attachments', {a.id}),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                const Divider(height: 32),
                Text(
                  tr(
                    context,
                    'Local activity (latest 100)',
                    'Lịch sử cục bộ (100 mục gần nhất)',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final e in events)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(_action(context, e.str('action'))),
                    subtitle: Text(
                      '${e.str('at')}${e.str('body').isEmpty ? '' : '\n${e.str('body')}'}',
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Heading extends StatelessWidget {
  final String title;
  final VoidCallback add;
  const _Heading(this.title, this.add);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          tooltip: tr(context, 'Add', 'Thêm'),
          onPressed: add,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}

// Comments became dated notes (2026-11); their stored action stays.
String _action(BuildContext context, String action) => action == 'comment'
    ? tr(context, 'Note', 'Ghi chú')
    : tr(
        context,
        action,
        {
              'created': 'Đã tạo',
              'edited': 'Đã sửa',
              'moved': 'Đã chuyển',
              'completed': 'Đã hoàn tất',
              'status changed': 'Đã đổi trạng thái',
              'trashed': 'Đã chuyển vào thùng rác',
              'restored': 'Đã khôi phục',
            }[action] ??
            action,
      );
Future<void> moveTaskDialog(
  BuildContext context,
  BoardsScope scope,
  BoardRecord t,
) async {
  String? target;
  await boardForm(
    context,
    tr(context, 'Move task', 'Chuyển task'),
    [
      BoardField(
        'board',
        'Destination board',
        'Bảng đích',
        kind: 'select',
        options: {
          for (final b in scope.state.rows('boards')) b.id: b.str('title'),
        },
      ),
    ],
    {'board': t.str('board')},
    (v) async {
      target = v['board'];
    },
  );
  if (target == null || !context.mounted) return;
  await boardForm(
    context,
    tr(context, 'Choose category', 'Chọn nhóm'),
    [
      BoardField(
        'category',
        'Destination category',
        'Nhóm đích',
        kind: 'select',
        options: {
          '': tr(context, 'Uncategorized', 'Chưa phân nhóm'),
          ...choices(scope.state, 'categories', target!),
        },
      ),
    ],
    {'category': ''},
    (v) async {
      await scope.controller.change(
        (s) => moveTasks(
          s,
          {t.id},
          target!,
          category: v['category'] == '' ? null : v['category'],
          now: scope.clock(),
        ),
      );
    },
    footer: [
      Text(
        tr(
          context,
          'Subtasks move together. Cross-board tags and custom values are cleared; external dependencies must be resolved first.',
          'Task con chuyển cùng. Tag và giá trị tùy chỉnh khác bảng sẽ được bỏ; cần xử lý liên kết phụ thuộc ngoài nhóm chuyển trước.',
        ),
      ),
    ],
  );
}

Future<void> addPredecessor(
  BuildContext context,
  BoardsScope scope,
  BoardRecord t,
) async {
  final options = {
    for (final other
        in scope.state
            .rows('tasks')
            .where(
              (r) =>
                  r.id != t.id &&
                  r.str('board') == t.str('board') &&
                  activeTask(r),
            ))
      other.id: other.str('title'),
  };
  if (options.isEmpty) return;
  await boardForm(
    context,
    tr(context, 'Add predecessor', 'Thêm công việc trước'),
    [BoardField('task', 'Task', 'Task', kind: 'select', options: options)],
    {'task': options.keys.first},
    (v) async {
      await scope.controller.change((s) => addDependency(s, v['task'], t.id));
    },
  );
}

Future<void> attachFile(
  BuildContext context,
  BoardsScope scope,
  BoardRecord t,
) async {
  final file = await scope.files.importBytes(
    extensions: [
      'jpg',
      'jpeg',
      'png',
      'webp',
      'pdf',
      'txt',
      'md',
      'csv',
      'json',
      'zip',
    ],
    maxBytes: 12000000,
  );
  if (file == null) return;
  final id = newId(), ext = file.name.split('.').last.toLowerCase();
  if (!RegExp(r'^[a-z0-9]{1,8}$').hasMatch(ext))
    throw const FormatException('Invalid extension');
  final path = 'assets/$id.$ext';
  final preview = ['jpg', 'jpeg', 'png', 'webp'].contains(ext)
      ? await compute(attachmentPreview, file.bytes)
      : null;
  final previewPath = 'assets/${id}_preview.jpg';
  await scope.controller.change(
    (s) =>
        (preview == null
                ? s.putFile(path, file.bytes)
                : s.putFile(path, file.bytes).putFile(previewPath, preview))
            .put(
              'attachments',
              BoardRecord({
                'id': id,
                'task': t.id,
                'board': t.str('board'),
                'name': file.name,
                'path': path,
                'sha256': sha256.convert(file.bytes).toString(),
                if (preview != null) 'preview': previewPath,
              }),
            ),
  );
}

Future<void> attachLink(
  BuildContext context,
  BoardsScope scope,
  BoardRecord t,
) => boardForm(
  context,
  tr(context, 'Attach link', 'Đính kèm link'),
  [const BoardField('url', 'HTTP(S) URL', 'URL HTTP(S)')],
  {'url': ''},
  (v) async {
    safeUrl(v['url']);
    await scope.controller.change(
      (s) => s.put(
        'attachments',
        BoardRecord({'id': newId(), 'task': t.id, 'url': v['url']}),
      ),
    );
  },
);
