import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../ui/collection_picker.dart';
import '../ui/words.dart';

/// Links saved from other apps that have no collection yet, newest first,
/// each with the usual collections one tap away. Filing one slides it out.
class TriageStrip extends StatelessWidget {
  final SaveController controller;
  final Future<void> Function(Bookmark, String collectionId) onFile;
  final ValueChanged<Bookmark> onOpen;
  final VoidCallback onAll;
  const TriageStrip({
    super.key,
    required this.controller,
    required this.onFile,
    required this.onOpen,
    required this.onAll,
  });

  @override
  Widget build(BuildContext context) {
    final l = controller.library!;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final waiting = [
      for (final b in l.bookmarks)
        if (b.collectionId == null && !b.isArchived) b,
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final usual = usualCollections(l);
    if (l.bookmarks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: HandySpace.xl),
        child: HandyGroup(
          color: c.lead,
          children: [
            Padding(
              padding: const EdgeInsets.all(HandySpace.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, 'Save your first link', 'Lưu link đầu tiên'),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: HandySpace.s),
                  Text(
                    tr(
                      context,
                      'In YouTube, TikTok, Facebook, Shopee or your browser, tap Share (then More, if it is not listed) and pick Handy Bookmark. Or copy a link and press Paste below.',
                      'Ở YouTube, TikTok, Facebook, Shopee hay trình duyệt, bấm Chia sẻ (không thấy thì bấm Khác) rồi chọn Handy Bookmark. Hoặc chép link rồi bấm Dán link bên dưới.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return HandyReveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HandyLabel(
            waiting.isEmpty
                ? tr(context, 'All sorted', 'Đã xếp hết')
                : tr(
                    context,
                    '${waiting.length} not sorted yet',
                    '${waiting.length} link chưa xếp',
                  ),
            trailing: waiting.isEmpty
                ? null
                : TextButton(
                    key: const Key('triage-all'),
                    onPressed: onAll,
                    child: Text(tr(context, 'See all', 'Xem tất cả')),
                  ),
          ),
          if (waiting.isEmpty)
            Text(
              tr(
                context,
                'Links you share to Handy Bookmark land here, ready to file.',
                'Link bạn chia sẻ vào Handy Bookmark sẽ nằm ở đây, chờ xếp chỗ.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
            )
          else
            SizedBox(
              // Room for two rows of chips (long collection names wrap on
              // real devices), growing with the reader's text size.
              height:
                  264 +
                  (MediaQuery.textScalerOf(context).scale(14) / 14 - 1) * 170,
              child: ListView.separated(
                key: const Key('triage'),
                scrollDirection: Axis.horizontal,
                itemCount: waiting.take(12).length,
                separatorBuilder: (_, _) => const SizedBox(width: HandySpace.m),
                itemBuilder: (context, i) => _TriageCard(
                  key: ValueKey('triage-${waiting[i].id}'),
                  controller: controller,
                  bookmark: waiting[i],
                  usual: usual,
                  onFile: onFile,
                  onOpen: onOpen,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TriageCard extends StatefulWidget {
  final SaveController controller;
  final Bookmark bookmark;
  final List<SaveCollection> usual;
  final Future<void> Function(Bookmark, String) onFile;
  final ValueChanged<Bookmark> onOpen;
  const _TriageCard({
    super.key,
    required this.controller,
    required this.bookmark,
    required this.usual,
    required this.onFile,
    required this.onOpen,
  });
  @override
  State<_TriageCard> createState() => _TriageCardState();
}

class _TriageCardState extends State<_TriageCard> {
  bool leaving = false;

  Future<void> file(String id) async {
    setState(() => leaving = true);
    await Future<void>.delayed(HandyMotion.of(context, HandyMotion.medium));
    try {
      await widget.onFile(widget.bookmark, id);
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        HapticFeedback.selectionClick();
      }
    } catch (_) {
      // The write failed and nothing moved: bring the card back.
      if (mounted) setState(() => leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bookmark;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return AnimatedSlide(
      offset: leaving ? const Offset(0, -.15) : Offset.zero,
      duration: HandyMotion.of(context),
      curve: HandyMotion.curve,
      child: AnimatedOpacity(
        opacity: leaving ? 0 : 1,
        duration: HandyMotion.of(context),
        child: SizedBox(
          width: 288,
          child: Card(
            color: c.lead,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => widget.onOpen(b),
                  child: Padding(
                    padding: const EdgeInsets.all(HandySpace.m),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinkThumb(widget.controller, b, size: 64),
                        const SizedBox(width: HandySpace.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.title.isEmpty ? b.sourceDomain : b.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontFamily:
                                      theme.textTheme.titleLarge?.fontFamily,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: HandySpace.xs),
                              Text(
                                '${sourceLine(b)} · ${ago(context, b.savedAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: c.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HandySpace.m,
                    0,
                    HandySpace.m,
                    HandySpace.m,
                  ),
                  child: Wrap(
                    spacing: HandySpace.s,
                    runSpacing: HandySpace.s,
                    children: [
                      for (final col in widget.usual)
                        ActionChip(
                          key: Key('file-${b.id}-${col.id}'),
                          avatar: HandyDot(
                            collectionHue(widget.controller.library!, col.id),
                          ),
                          label: Text(
                            col.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: leaving ? null : () => file(col.id),
                        ),
                      ActionChip(
                        key: Key('file-${b.id}-other'),
                        avatar: const Icon(Icons.more_horiz, size: 18),
                        label: Text(
                          widget.usual.isEmpty
                              ? tr(context, 'Choose…', 'Chọn chỗ…')
                              : tr(context, 'Other…', 'Khác…'),
                        ),
                        onPressed: leaving
                            ? null
                            : () async {
                                final id = await pickCollection(
                                  context,
                                  widget.controller.library!,
                                  allowInbox: false,
                                );
                                if (id != null && id.isNotEmpty) await file(id);
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
