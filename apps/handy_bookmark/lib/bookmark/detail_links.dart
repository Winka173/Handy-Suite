import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../links/link_actions.dart';
import '../links/link_tasks.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'detail_facts.dart';

/// A link's offline copy and its last check, each with the one thing to do
/// next. Nothing here touches the network until a button is pressed.
class DetailLinks extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const DetailLinks({super.key, required this.scope, required this.bookmark});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.tasks,
    builder: (context, _) {
      final b = bookmark;
      final p = BookmarkPalette.of(context);
      final theme = Theme.of(context);
      final muted = theme.textTheme.bodyMedium?.copyWith(color: p.muted);
      final tasks = scope.tasks;
      final net = scope.c.networkAvailable;
      final mine = tasks.running && tasks.currentId == b.id;
      final saving = mine && tasks.job == LinkJob.reading;
      final checking = mine && tasks.job == LinkJob.check;
      final copiedAt = scope.c.readingIds[b.id];
      final check = b.linkCheck;
      final tool = detailToolStyle(context);
      Widget busy(String key) => TextButton.icon(
        key: Key(key),
        onPressed: tasks.cancel,
        icon: const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(tr(context, 'Stop', 'Dừng')),
      );
      Widget buttons(List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: HandySpace.s),
        child: Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: children,
        ),
      );
      final offWeb = tr(
        context,
        'Not available in the browser.',
        'Không có trên trình duyệt.',
      );
      String day(String iso) => formatDay(
        context,
        DateTime.parse(iso).toLocal().toIso8601String().substring(0, 10),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailToolHead(tr(context, 'Offline copy', 'Bản đọc offline')),
          Text(
            copiedAt == null
                ? tr(
                    context,
                    'Keep the page\'s text and its pictures (up to 20) to read without a connection.',
                    'Giữ chữ và ảnh của bài (tối đa 20 ảnh) để đọc khi không có mạng.',
                  )
                : tr(
                    context,
                    'Saved ${day(copiedAt)}.',
                    'Đã lưu ${day(copiedAt)}.',
                  ),
            style: muted,
          ),
          if (!net) Text(offWeb, style: muted),
          buttons([
            if (copiedAt != null)
              FilledButton.icon(
                key: const Key('detail-read-offline'),
                style: tool.copyWith(
                  backgroundColor: WidgetStatePropertyAll(p.tint),
                  foregroundColor: WidgetStatePropertyAll(
                    theme.brightness == Brightness.dark ? p.ink : p.pressed,
                  ),
                ),
                onPressed: () => Navigator.pushNamed(context, '/read/${b.id}'),
                icon: const Icon(Icons.chrome_reader_mode_outlined, size: 20),
                label: Text(tr(context, 'Read offline', 'Đọc offline')),
              ),
            if (saving)
              busy('detail-copy-stop')
            else
              FilledButton(
                key: const Key('detail-copy-save'),
                style: tool,
                onPressed: net
                    ? () => scope.saveCopies(context, [b.id])
                    : () => showNotInBrowser(context),
                child: Text(
                  copiedAt == null
                      ? tr(context, 'Save offline copy', 'Lưu bản đọc offline')
                      : tr(context, 'Save again', 'Lưu lại'),
                ),
              ),
            if (copiedAt != null && !saving)
              TextButton(
                key: const Key('detail-copy-remove'),
                onPressed: () => scope.removeCopy(context, b),
                child: Text(tr(context, 'Remove copy', 'Xóa bản đọc')),
              ),
          ]),
          DetailToolHead(
            tr(context, 'Does it still open?', 'Còn mở được không?'),
          ),
          Text(
            check == null
                ? tr(
                    context,
                    'Not checked. A check asks the site once, only when you press it.',
                    'Chưa kiểm tra. Kiểm tra hỏi trang web một lần, chỉ khi bạn bấm.',
                  )
                : linkCheckLine(context, check),
            key: const Key('detail-check-status'),
            style: check == null
                ? muted
                : theme.textTheme.bodyMedium?.copyWith(
                    color: check.status == 'gone' ? p.danger : p.ink,
                    fontWeight: FontWeight.w500,
                  ),
          ),
          if (check != null)
            Text(linkReasonWords(context, check), style: muted)
          else if (!net)
            Text(offWeb, style: muted),
          if (check?.status == 'moved') ...[
            const SizedBox(height: HandySpace.s),
            Container(
              padding: const EdgeInsets.all(HandySpace.m),
              decoration: BoxDecoration(
                color: p.warningTint,
                borderRadius: BorderRadius.circular(BookmarkRadii.thumb),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, 'The new address', 'Địa chỉ mới'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: p.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    check!.movedTo!,
                    minLines: 1,
                    maxLines: 3,
                    style: theme.textTheme.bodyMedium?.copyWith(color: p.ink),
                  ),
                ],
              ),
            ),
          ],
          buttons([
            if (check?.status == 'moved')
              FilledButton(
                key: const Key('detail-adopt'),
                style: tool.copyWith(
                  backgroundColor: WidgetStatePropertyAll(p.tint),
                  foregroundColor: WidgetStatePropertyAll(
                    theme.brightness == Brightness.dark ? p.ink : p.pressed,
                  ),
                ),
                onPressed: () => scope.adoptMoved(context, b),
                child: Text(
                  tr(context, 'Use the new address', 'Dùng địa chỉ mới'),
                ),
              ),
            if (checking)
              busy('detail-check-stop')
            else
              FilledButton(
                key: const Key('detail-check'),
                style: tool,
                onPressed: net
                    ? () => scope.checkLinks(context, [b.id])
                    : () => showNotInBrowser(context),
                child: Text(
                  check == null
                      ? tr(context, 'Check this link', 'Kiểm tra link này')
                      : tr(context, 'Check again', 'Kiểm tra lại'),
                ),
              ),
          ]),
        ],
      );
    },
  );
}
