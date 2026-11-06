import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';

/// Links saved more than once: each group lists its copies, the person
/// picks the one to keep (the oldest by default) and merges. Nothing is
/// merged without that tap; tags, notes, collection and opens carry over.
class DuplicatesPage extends StatefulWidget {
  final SaveScope scope;
  const DuplicatesPage({super.key, required this.scope});
  @override
  State<DuplicatesPage> createState() => _DuplicatesPageState();
}

class _DuplicatesPageState extends State<DuplicatesPage> {
  /// The copy to keep, per group (by its oldest link's id).
  final keep = <String, String>{};
  SaveScope get scope => widget.scope;

  Future<void> merge(List<Bookmark> group) async {
    final kept = keep[group.first.id] ?? group.first.id;
    final copyIds = scope.c.readingIds.keys.toSet();
    final ok = await scope.run(
      context,
      () => scope.c.update(
        (l) => mergeBookmarks(l, kept, [
          for (final b in group) b.id,
        ], now: DateTime.now().toUtc().toIso8601String()),
      ),
    );
    if (!ok || !mounted) return;
    final lostCopy =
        !copyIds.contains(kept) &&
        group.any((b) => b.id != kept && copyIds.contains(b.id));
    showHandyMessage(
      context,
      lostCopy
          ? tr(
              context,
              'Merged. The offline copy belonged to a removed copy; save it again from the link.',
              'Đã gộp. Bản đọc offline thuộc bản đã gỡ; hãy lưu lại từ link.',
            )
          : tr(context, 'Merged into one link.', 'Đã gộp thành một link.'),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.c,
    builder: (context, _) {
      final l = scope.c.library!;
      final groups = duplicateGroups(l);
      final theme = Theme.of(context);
      final p = BookmarkPalette.of(context);
      final names = {for (final x in l.collections) x.id: x.name};
      return Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'Saved twice', 'Link lưu trùng')),
        ),
        body: groups.isEmpty
            ? ListView(
                key: const Key('duplicates-none'),
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
                children: [
                  HandyContent(
                    maxWidth: 420,
                    child: Column(
                      children: [
                        Icon(Icons.done_all, size: 32, color: p.sage),
                        const SizedBox(height: 16),
                        Text(
                          tr(
                            context,
                            'Every link is saved once.',
                            'Mỗi link chỉ lưu một lần.',
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  HandyContent(
                    maxWidth: 720,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          tr(
                            context,
                            'Pick the copy to keep. Tags, notes, collection, favourite and opens from the others move onto it.',
                            'Chọn bản giữ lại. Nhãn, ghi chú, bộ sưu tập, yêu thích và số lần mở của các bản kia chuyển sang bản này.',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: p.muted,
                          ),
                        ),
                        for (final (gi, group) in groups.indexed) ...[
                          const SizedBox(height: 16),
                          Material(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(
                              BookmarkRadii.item,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    14,
                                    16,
                                    4,
                                  ),
                                  child: Semantics(
                                    header: true,
                                    child: Text(
                                      group.first.title.isNotEmpty
                                          ? group.first.title
                                          : group.first.sourceDomain,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                ),
                                RadioGroup<String>(
                                  groupValue:
                                      keep[group.first.id] ?? group.first.id,
                                  onChanged: (v) =>
                                      setState(() => keep[group.first.id] = v!),
                                  child: Column(
                                    children: [
                                      for (final b in group)
                                        RadioListTile<String>(
                                          key: Key('duplicates-keep-${b.id}'),
                                          value: b.id,
                                          title: Text(
                                            b.title.isNotEmpty
                                                ? b.title
                                                : b.originalUrl,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            [
                                              tr(
                                                context,
                                                'saved ${formatDay(context, b.savedAt.substring(0, 10))}',
                                                'lưu ${formatDay(context, b.savedAt.substring(0, 10))}',
                                              ),
                                              if (b.collectionId != null &&
                                                  names[b.collectionId] != null)
                                                names[b.collectionId]!,
                                              if (b.note.isNotEmpty)
                                                tr(
                                                  context,
                                                  'note',
                                                  'có ghi chú',
                                                ),
                                              if (scope.c.readingIds
                                                  .containsKey(b.id))
                                                tr(
                                                  context,
                                                  'offline copy',
                                                  'có bản đọc',
                                                ),
                                              if (b.isArchived)
                                                tr(
                                                  context,
                                                  'archived',
                                                  'đã lưu trữ',
                                                ),
                                            ].join(' · '),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    16,
                                  ),
                                  child: Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: FilledButton.tonal(
                                      key: Key('duplicates-merge-$gi'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: p.tint,
                                        foregroundColor:
                                            theme.brightness == Brightness.dark
                                            ? p.ink
                                            : p.pressed,
                                        minimumSize: const Size(48, 44),
                                        shape: const StadiumBorder(),
                                      ),
                                      onPressed: () => merge(group),
                                      child: Text(
                                        tr(
                                          context,
                                          'Merge ${group.length} into one',
                                          'Gộp ${group.length} thành một',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      );
    },
  );
}
