import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../links/link_actions.dart';
import '../links/link_tasks.dart';
import '../scope.dart';
import '../ui/words.dart';

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
      final c = HandyColors.of(context);
      final theme = Theme.of(context);
      final tasks = scope.tasks;
      final net = scope.c.networkAvailable;
      final mine = tasks.running && tasks.currentId == b.id;
      final saving = mine && tasks.job == LinkJob.reading;
      final checking = mine && tasks.job == LinkJob.check;
      final copiedAt = scope.c.readingIds[b.id];
      final check = b.linkCheck;
      Widget busy(String key) => TextButton.icon(
        key: Key(key),
        onPressed: tasks.cancel,
        icon: const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(tr(context, 'Stop', 'Dừng')),
      );
      Widget pad(Widget child) => Padding(
        padding: const EdgeInsets.fromLTRB(
          HandySpace.l,
          0,
          HandySpace.l,
          HandySpace.l,
        ),
        child: child,
      );
      final offWeb = tr(
        context,
        'Not available in the browser.',
        'Không có trên trình duyệt.',
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HandyLabel(tr(context, 'Offline copy', 'Bản đọc offline')),
          HandyGroup(
            children: [
              ListTile(
                title: Text(
                  copiedAt == null
                      ? tr(
                          context,
                          'Keep the page\'s text to read without a connection. Pictures are left out.',
                          'Giữ phần chữ của trang để đọc khi không có mạng. Không giữ ảnh.',
                        )
                      : tr(
                          context,
                          'Saved ${formatDay(context, DateTime.parse(copiedAt).toLocal().toIso8601String().substring(0, 10))}. Text only.',
                          'Đã lưu ${formatDay(context, DateTime.parse(copiedAt).toLocal().toIso8601String().substring(0, 10))}. Chỉ phần chữ.',
                        ),
                ),
                subtitle: net ? null : Text(offWeb),
                textColor: c.muted,
              ),
              pad(
                Wrap(
                  spacing: HandySpace.s,
                  runSpacing: HandySpace.s,
                  children: [
                    if (copiedAt != null)
                      FilledButton.tonalIcon(
                        key: const Key('detail-read-offline'),
                        onPressed: () =>
                            Navigator.pushNamed(context, '/read/${b.id}'),
                        icon: const Icon(Icons.chrome_reader_mode_outlined),
                        label: Text(tr(context, 'Read offline', 'Đọc offline')),
                      ),
                    if (saving)
                      busy('detail-copy-stop')
                    else
                      OutlinedButton(
                        key: const Key('detail-copy-save'),
                        onPressed: net
                            ? () => scope.saveCopies(context, [b.id])
                            : () => showNotInBrowser(context),
                        child: Text(
                          copiedAt == null
                              ? tr(
                                  context,
                                  'Save offline copy',
                                  'Lưu bản đọc offline',
                                )
                              : tr(context, 'Save again', 'Lưu lại'),
                        ),
                      ),
                    if (copiedAt != null && !saving)
                      TextButton(
                        key: const Key('detail-copy-remove'),
                        onPressed: () => scope.removeCopy(context, b),
                        child: Text(tr(context, 'Remove copy', 'Xóa bản đọc')),
                      ),
                  ],
                ),
              ),
            ],
          ),
          HandyLabel(tr(context, 'Does it still open?', 'Còn mở được không?')),
          HandyGroup(
            children: [
              ListTile(
                key: const Key('detail-check-status'),
                title: Text(
                  check == null
                      ? tr(
                          context,
                          'Not checked. A check asks the site once, only when you press it.',
                          'Chưa kiểm tra. Kiểm tra hỏi trang web một lần, chỉ khi bạn bấm.',
                        )
                      : linkCheckLine(context, check),
                  style: check?.status == 'gone'
                      ? TextStyle(color: c.negative)
                      : null,
                ),
                subtitle: check == null
                    ? (net ? null : Text(offWeb))
                    : Text(linkReasonWords(context, check)),
                textColor: check == null ? c.muted : null,
              ),
              if (check?.status == 'moved')
                ListTile(
                  title: SelectableText(
                    check!.movedTo!,
                    maxLines: 3,
                    style: theme.textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    tr(context, 'The new address', 'Địa chỉ mới'),
                    style: TextStyle(color: c.muted),
                  ),
                ),
              pad(
                Wrap(
                  spacing: HandySpace.s,
                  runSpacing: HandySpace.s,
                  children: [
                    if (check?.status == 'moved')
                      FilledButton.tonal(
                        key: const Key('detail-adopt'),
                        onPressed: () => scope.adoptMoved(context, b),
                        child: Text(
                          tr(
                            context,
                            'Use the new address',
                            'Dùng địa chỉ mới',
                          ),
                        ),
                      ),
                    if (checking)
                      busy('detail-check-stop')
                    else
                      OutlinedButton(
                        key: const Key('detail-check'),
                        onPressed: net
                            ? () => scope.checkLinks(context, [b.id])
                            : () => showNotInBrowser(context),
                        child: Text(
                          check == null
                              ? tr(
                                  context,
                                  'Check this link',
                                  'Kiểm tra link này',
                                )
                              : tr(context, 'Check again', 'Kiểm tra lại'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
