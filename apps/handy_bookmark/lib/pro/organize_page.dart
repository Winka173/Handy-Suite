import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';
import 'entitlements.dart';

/// The person's rules: the presets with their own destinations.
List<OrganizeRule> organizeRules(SaveController c) {
  final saved = {
    for (final r in c.preferences['organizeRules'] as List? ?? const [])
      if (r is Map) OrganizeRule.fromJson(Map<String, dynamic>.from(r)),
  };
  final byId = {for (final r in saved) r.id: r};
  return [for (final p in organizePresets) byId[p.id] ?? p];
}

String _ruleName(BuildContext context, OrganizeRule r) => switch (r.id) {
  'videos' => tr(context, 'Videos', 'Video'),
  'shopping' => tr(context, 'Shopping', 'Mua sắm'),
  'development' => tr(context, 'Development', 'Lập trình'),
  'pictures' => tr(context, 'Pictures', 'Ảnh'),
  _ => r.name,
};

/// What rules did on their own to new saves, newest first (kept 50).
List<Map<String, dynamic>> organizeLog(SaveController c) => [
  for (final e in c.preferences['organizeLog'] as List? ?? const [])
    if (e is Map) Map<String, dynamic>.from(e),
];

/// Runs the enabled rules on saves that just arrived, when the person
/// turned automation on and Pro is verified. Filed saves are never moved.
Future<void> organizeNewSaves(SaveController c, Iterable<String> ids) async {
  if (c.preferences['organizeAuto'] != true || c.library == null) return;
  final plan = planOrganize(c.library!, organizeRules(c), ids: ids);
  if (plan.isEmpty) return;
  final now = DateTime.now().toUtc().toIso8601String();
  final log = [
    for (final ch in plan)
      {
        'id': ch.bookmarkId,
        'to': ?ch.toCollection,
        'tag': ?ch.addTag,
        'at': now,
      },
    ...organizeLog(c),
  ].take(50).toList();
  await c.update(
    (l) => applyOrganize(l, plan, now),
    prefs: {...c.preferences, 'organizeLog': log},
  );
}

/// Auto organize: presets with a destination each, a dry run on what is
/// not sorted yet, automation for new saves, and a log to undo from.
class OrganizePage extends StatelessWidget {
  final SaveScope scope;
  const OrganizePage({super.key, required this.scope});

  Future<void> _save(List<OrganizeRule> rules) => scope.c.update(
    (l) => l,
    prefs: {
      ...scope.c.preferences,
      'organizeRules': [for (final r in rules) r.toJson()],
    },
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    return ListenableBuilder(
      listenable: scope.c,
      builder: (context, _) {
        final c = scope.c;
        final rules = organizeRules(c);
        final log = organizeLog(c);
        final names = {
          for (final col in scope.library.collections) col.id: col.name,
        };
        return Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'Auto organize', 'Tự sắp xếp')),
          ),
          body: ListView(
            key: const Key('organize-page'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Text(
                tr(
                  context,
                  'Rules put new saves in a collection by where they come from. They never move something you already filed, and run only on this device.',
                  'Quy tắc xếp mục mới vào bộ sưu tập theo nguồn. Không bao giờ chuyển mục bạn đã xếp, và chỉ chạy trên máy này.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const Key('organize-auto'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  tr(
                    context,
                    'Organize new saves automatically',
                    'Tự xếp mục mới lưu',
                  ),
                ),
                subtitle: Text(
                  tr(
                    context,
                    'Pro · off until you turn it on',
                    'Pro · tắt cho tới khi bạn bật',
                  ),
                ),
                value: c.preferences['organizeAuto'] == true && hasPro(context),
                onChanged: (on) async {
                  if (on && !await requirePro(context, ProFeature.autoOrganize))
                    return;
                  await c.update(
                    (l) => l,
                    prefs: {...c.preferences, 'organizeAuto': on},
                  );
                },
              ),
              const SizedBox(height: 8),
              for (final r in rules)
                Container(
                  key: Key('rule-${r.id}'),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(BookmarkRadii.item),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _ruleName(context, r),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Switch(
                            key: Key('rule-${r.id}-on'),
                            value: r.enabled && r.collectionId != null,
                            onChanged: r.collectionId == null
                                ? null
                                : (on) => _save([
                                    for (final x in rules)
                                      x.id == r.id
                                          ? x.copyWith(enabled: on)
                                          : x,
                                  ]),
                          ),
                        ],
                      ),
                      Text(
                        r.kind == 'image'
                            ? tr(context, 'Pictures you add', 'Ảnh bạn thêm')
                            : r.sources
                                  .where((s) => !s.contains('.'))
                                  .join(', '),
                        style: theme.textTheme.bodySmall,
                      ),
                      TextButton.icon(
                        key: Key('rule-${r.id}-to'),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () async {
                          final id = await pickCollection(
                            context,
                            scope.library,
                            allowInbox: false,
                          );
                          if (id == null || id.isEmpty) return;
                          await _save([
                            for (final x in rules)
                              x.id == r.id
                                  ? x.copyWith(collectionId: id, enabled: true)
                                  : x,
                          ]);
                        },
                        icon: const Icon(
                          Icons.drive_file_move_outline,
                          size: 18,
                        ),
                        label: Text(
                          names[r.collectionId] == null
                              ? tr(
                                  context,
                                  'Choose where they go',
                                  'Chọn nơi xếp vào',
                                )
                              : tr(
                                  context,
                                  'Into ${names[r.collectionId]}',
                                  'Vào ${names[r.collectionId]}',
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('organize-preview'),
                onPressed: () => showOrganizePreview(context, scope),
                icon: const Icon(Icons.visibility_outlined),
                label: Text(
                  tr(
                    context,
                    'Try on what is not sorted',
                    'Thử trên mục chưa xếp',
                  ),
                ),
              ),
              if (log.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  tr(context, 'Done on their own', 'Đã tự xếp'),
                  style: theme.textTheme.titleLarge,
                ),
                for (final e in log.take(20))
                  if (scope.library.bookmarks
                          .where((b) => b.id == e['id'])
                          .firstOrNull
                      case final b?)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        b.title.isEmpty ? b.sourceDomain : b.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if (names[e['to']] != null) '→ ${names[e['to']]}',
                          if (e['tag'] != null) '#${e['tag']}',
                        ].join(' · '),
                      ),
                      trailing: TextButton(
                        onPressed: () => scope.view.change(
                          (l) => l.copyWith(
                            bookmarks: [
                              for (final x in l.bookmarks)
                                x.id == b.id
                                    ? x.copyWith(
                                        collectionId: x.collectionId == e['to']
                                            ? null
                                            : x.collectionId,
                                        tags: [
                                          for (final t in x.tags)
                                            if (t != e['tag']) t,
                                        ],
                                        updatedAt: DateTime.now()
                                            .toUtc()
                                            .toIso8601String(),
                                      )
                                    : x,
                            ],
                          ),
                          prefs: {
                            ...c.preferences,
                            'organizeLog': [
                              for (final x in log)
                                if (x != e) x,
                            ],
                          },
                        ),
                        child: Text(tr(context, 'Undo', 'Hoàn tác')),
                      ),
                    ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A dry run of the rules on [ids] (unsorted saves when null): how many
/// would change and the first of them, then Apply (Pro) with Undo.
Future<void> showOrganizePreview(
  BuildContext context,
  SaveScope scope, {
  Iterable<String>? ids,
}) {
  final l = scope.library;
  final targets =
      ids ??
      [
        for (final b in l.bookmarks)
          if (b.collectionId == null && !b.isArchived) b.id,
      ];
  final plan = planOrganize(l, organizeRules(scope.c), ids: targets);
  final names = {for (final col in l.collections) col.id: col.name};
  final titles = {
    for (final b in l.bookmarks)
      b.id: b.title.isEmpty ? b.sourceDomain : b.title,
  };
  return _preview(
    context,
    title: tr(context, 'Organize with your rules', 'Xếp theo quy tắc của bạn'),
    count: plan.length,
    rows: [
      for (final ch in plan)
        (
          titles[ch.bookmarkId] ?? '',
          [
            if (ch.toCollection != null) names[ch.toCollection],
            if (ch.addTag != null) '#${ch.addTag}',
          ].join(' · '),
        ),
    ],
    feature: ProFeature.autoOrganize,
    apply: () => scope.view.change(
      (x) => applyOrganize(x, plan, DateTime.now().toUtc().toIso8601String()),
    ),
    scope: scope,
  );
}

/// Site names trimmed from the selected titles, shown before and after.
Future<void> showTitleCleanup(
  BuildContext context,
  SaveScope scope,
  Iterable<String> ids,
) {
  final plan = planTitleCleanup(scope.library, ids);
  return _preview(
    context,
    title: tr(context, 'Clean up titles', 'Dọn tiêu đề'),
    count: plan.length,
    rows: [for (final c in plan) (c.$2, c.$3)],
    feature: ProFeature.advancedBulk,
    apply: () => scope.view.change(
      (x) =>
          applyTitleCleanup(x, plan, DateTime.now().toUtc().toIso8601String()),
    ),
    scope: scope,
  );
}

Future<void> _preview(
  BuildContext context, {
  required String title,
  required int count,
  required List<(String, String)> rows,
  required ProFeature feature,
  required Future<void> Function() apply,
  required SaveScope scope,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheet) {
    final theme = Theme.of(sheet);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * .8,
        ),
        child: Column(
          key: const Key('organize-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    count == 0
                        ? tr(
                            sheet,
                            'Nothing would change.',
                            'Không có gì thay đổi.',
                          )
                        : tr(
                            sheet,
                            '$count would change. Nothing is written until you apply.',
                            '$count mục sẽ đổi. Chưa ghi gì cho tới khi bạn áp dụng.',
                          ),
                    key: const Key('organize-count'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final (before, after) in rows.take(30))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        before,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '→ $after',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheet),
                      child: Text(tr(sheet, 'Cancel', 'Hủy')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const Key('organize-apply'),
                      onPressed: count == 0
                          ? null
                          : () async {
                              if (!await requirePro(sheet, feature) ||
                                  !sheet.mounted)
                                return;
                              await apply();
                              if (!sheet.mounted) return;
                              Navigator.pop(sheet);
                              if (context.mounted)
                                scope.undoMessage(
                                  context,
                                  tr(
                                    context,
                                    '$count changed.',
                                    'Đã đổi $count mục.',
                                  ),
                                );
                            },
                      child: Text(
                        hasPro(sheet)
                            ? tr(sheet, 'Apply', 'Áp dụng')
                            : tr(sheet, 'Apply with Pro', 'Áp dụng với Pro'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  },
);
