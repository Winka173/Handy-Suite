import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../scope.dart';
import 'link_tasks.dart';
import 'batch_size.dart';

/// Says plainly that a network tool is off in the browser, and why.
Future<void> showNotInBrowser(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(
      tr(context, 'Not available in the browser', 'Không có trên trình duyệt'),
    ),
    content: Text(
      tr(
        context,
        'Saving offline copies and checking links need network checks a browser cannot guarantee (which address is really contacted). Use Handy Bookmark on Android, iOS or Windows. Copies restored from a backup can still be read here.',
        'Lưu bản đọc offline và kiểm tra link cần kiểm soát mạng mà trình duyệt không bảo đảm được (thật sự kết nối tới địa chỉ nào). Hãy dùng Handy Bookmark trên Android, iOS hoặc Windows. Bản đọc khôi phục từ bản sao lưu vẫn đọc được ở đây.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr(context, 'Close', 'Đóng')),
      ),
    ],
  ),
);

/// The person's own actions on link checks, reading copies and saved
/// searches. The network is touched only from here, on a tap.
extension LinkActions on SaveScope {
  Future<bool> _ready(BuildContext context) async {
    if (!c.networkAvailable) {
      await showNotInBrowser(context);
      return false;
    }
    if (tasks.running) {
      showHandyMessage(
        context,
        tr(
          context,
          'Another job is running. Stop it or wait for it to finish.',
          'Đang có việc khác chạy. Hãy dừng hoặc chờ nó xong.',
        ),
      );
      return false;
    }
    return true;
  }

  /// Checks [ids] (HEAD, then GET), recording a status on each.
  Future<void> checkLinks(BuildContext context, Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty || !await _ready(context)) return;
    if (!context.mounted) return;
    final limit = await chooseLinkBatch(
      context,
      count: list.toSet().length,
      maximum: LinkTasks.maxChecks,
      reading: false,
    );
    if (limit == null || !context.mounted) return;
    await run(context, () => tasks.checkLinks(list, limit: limit));
  }

  /// Checks every link the current list holds (a collection, All links…).
  Future<void> checkHere(BuildContext context) async {
    if (!context.mounted) return;
    final ids = await view.allIds();
    if (context.mounted) await checkLinks(context, ids);
  }

  /// Saves offline reading copies of [ids].
  Future<void> saveCopies(BuildContext context, Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty || !await _ready(context)) return;
    if (!context.mounted) return;
    final limit = await chooseLinkBatch(
      context,
      count: list.toSet().length,
      maximum: LinkTasks.maxCopies,
      reading: true,
    );
    if (limit == null || !context.mounted) return;
    final report = await tasks.saveCopies(list, limit: limit);
    if (list.length == 1 && context.mounted && !report.cancelled) {
      showHandyMessage(
        context,
        report.count('saved') == 1
            ? tr(
                context,
                'Saved for offline reading.',
                'Đã lưu bản đọc offline.',
              )
            : report.count('noText') == 1
            ? tr(
                context,
                'This page has no readable text to keep (a video, an app page or a sign-in wall).',
                'Trang này không có chữ để giữ (video, trang app hoặc yêu cầu đăng nhập).',
              )
            : tr(
                context,
                'Could not read the page. Nothing was saved.',
                'Chưa đọc được trang. Không có gì được lưu.',
              ),
      );
    }
  }

  Future<void> removeCopy(BuildContext context, Bookmark b) =>
      run(context, () => c.deleteReadingCopy(b.id));

  /// Points the link at the address its check found, with Undo.
  Future<void> adoptMoved(BuildContext context, Bookmark b) async {
    final done = await run(
      context,
      () => view.change(
        (l) => l.copyWith(
          bookmarks: [
            for (final x in l.bookmarks)
              x.id == b.id ? adoptMovedUrl(x, saveTime()) : x,
          ],
        ),
      ),
    );
    if (done && context.mounted)
      undoMessage(
        context,
        tr(context, 'Now using the new address.', 'Đã dùng địa chỉ mới.'),
      );
  }

  /// Saved searches are part of Pro; without it, say so plainly.
  Future<void> saveSearch(BuildContext context) async {
    if (LifetimeScope.maybeOf(context)?.pro != true) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            tr(
              context,
              'Saved filters are in Pro',
              'Bộ lọc đã lưu có trong bản Pro',
            ),
          ),
          content: Text(
            tr(
              context,
              'Keep a search with its place and filters, and come back to it in one tap. Pro Lifetime is a one-time purchase in Settings.',
              'Giữ một tìm kiếm cùng nơi và bộ lọc, rồi mở lại chỉ với một chạm. Pro Lifetime mua một lần trong Cài đặt.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'Close', 'Đóng')),
            ),
          ],
        ),
      );
      return;
    }
    final name = await _name(
      context,
      tr(context, 'Save this search', 'Lưu tìm kiếm này'),
      view.text.trim(),
    );
    if (name == null || !context.mounted) return;
    final query = view.savedQuery();
    final done = await run(
      context,
      () => view.change(
        (l) => l.copyWith(
          savedSearches: [
            ...l.savedSearches,
            SavedSearch(id: saveId(), name: name, query: query),
          ],
        ),
      ),
    );
    if (done && context.mounted)
      showHandyMessage(
        context,
        tr(context, 'Search saved.', 'Đã lưu tìm kiếm.'),
      );
  }

  Future<void> renameSaved(BuildContext context, SavedSearch s) async {
    final name = await _name(
      context,
      tr(context, 'Rename search', 'Đổi tên tìm kiếm'),
      s.name,
    );
    if (name == null || !context.mounted) return;
    await run(
      context,
      () => view.change(
        (l) => l.copyWith(
          savedSearches: [
            for (final x in l.savedSearches)
              x.id == s.id ? x.copyWith(name: name) : x,
          ],
        ),
      ),
    );
  }

  Future<void> deleteSaved(BuildContext context, SavedSearch s) async {
    final done = await run(
      context,
      () => view.change(
        (l) => l.copyWith(
          savedSearches: [
            for (final x in l.savedSearches)
              if (x.id != s.id) x,
          ],
        ),
      ),
    );
    if (done && context.mounted)
      undoMessage(
        context,
        tr(context, 'Saved search deleted.', 'Đã xóa tìm kiếm đã lưu.'),
      );
  }

  Future<String?> _name(
    BuildContext context,
    String title,
    String initial,
  ) async {
    final input = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('saved-search-name'),
          controller: input,
          autofocus: true,
          maxLength: 120,
          decoration: InputDecoration(
            labelText: tr(context, 'Name', 'Tên'),
            counterText: '',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Cancel', 'Hủy')),
          ),
          FilledButton(
            key: const Key('saved-search-ok'),
            onPressed: () => Navigator.pop(context, input.text),
            child: Text(tr(context, 'Save', 'Lưu')),
          ),
        ],
      ),
    );
    input.dispose();
    final t = name?.trim() ?? '';
    return t.isEmpty ? null : t;
  }
}
