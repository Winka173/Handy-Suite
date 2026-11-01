import 'package:handy_save_engine/handy_save_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';

/// Saves links the person pasted or typed. The clipboard is read only when
/// they ask ([fromClipboard]); nothing is fetched. A single link that is
/// already saved asks first: open it, review it, or add a copy anyway.
/// Returns the bookmark to show, if any.
Future<Bookmark?> addLinks(
  BuildContext context,
  SaveScope scope, {
  bool fromClipboard = false,
}) async {
  final c = scope.c;
  c.adsVisible.value = false;
  var initial = '';
  if (fromClipboard) {
    try {
      final text = await c.clipboard();
      if (text == null) {
        if (context.mounted) {
          showHandyMessage(
            context,
            tr(
              context,
              'That clipboard text was already offered.',
              'Nội dung clipboard này đã được dùng.',
            ),
          );
        }
        return null;
      }
      initial = text;
    } catch (_) {
      if (context.mounted)
        showHandyMessage(
          context,
          tr(
            context,
            'The clipboard could not be read.',
            'Chưa đọc được clipboard.',
          ),
        );
      return null;
    }
  }
  if (!context.mounted) return null;
  final input = TextEditingController(text: initial);
  final text = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr(context, 'Save links', 'Lưu link')),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: HandyField(
          label: tr(context, 'One or more links', 'Một hoặc nhiều link'),
          help: tr(
            context,
            'Links starting with http or https. Saving works offline.',
            'Link bắt đầu bằng http hoặc https. Lưu được cả khi không có mạng.',
          ),
          child: TextField(
            key: const Key('save-text-input'),
            controller: input,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            maxLength: 262144,
            decoration: const InputDecoration(
              hintText: 'https://…',
              counterText: '',
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Cancel', 'Hủy')),
        ),
        FilledButton(
          key: const Key('save-text-confirm'),
          onPressed: () => Navigator.pop(context, input.text),
          child: Text(tr(context, 'Save', 'Lưu')),
        ),
      ],
    ),
  );
  if (text == null || text.trim().isEmpty || !context.mounted) return null;
  final found = UrlTools.extract(text);
  if (found.isEmpty) {
    showHandyMessage(
      context,
      tr(
        context,
        'No http or https link found.',
        'Không thấy link http hoặc https nào.',
      ),
    );
    return null;
  }
  if (found.length == 1) {
    final u = found.single;
    final old = scope.library.bookmarks
        .where(
          (b) =>
              b.normalizedUrl == u.normalizedUrl ||
              UrlTools.normalize(b.originalUrl).canonicalUrl == u.canonicalUrl,
        )
        .firstOrNull;
    if (old != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr(context, 'Already saved', 'Link này đã được lưu')),
          content: Text(old.title.isEmpty ? old.originalUrl : old.title),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'Cancel', 'Hủy')),
            ),
            TextButton(
              key: const Key('dup-open'),
              onPressed: () => Navigator.pop(context, 'open'),
              child: Text(tr(context, 'Show it', 'Xem link cũ')),
            ),
            TextButton(
              key: const Key('dup-edit'),
              onPressed: () => Navigator.pop(context, 'edit'),
              child: Text(tr(context, 'Review details', 'Xem lại chi tiết')),
            ),
            FilledButton(
              key: const Key('dup-copy'),
              onPressed: () => Navigator.pop(context, 'copy'),
              child: Text(tr(context, 'Add anyway', 'Vẫn lưu bản mới')),
            ),
          ],
        ),
      );
      if (!context.mounted) return null;
      switch (choice) {
        case 'open':
          return old;
        case 'edit':
          await scope.edit(context, old);
          return null;
        case 'copy':
          final saved = <Bookmark>[];
          await scope.run(
            context,
            () async =>
                saved.addAll(await c.quickSave(text, allowDuplicates: true)),
          );
          return saved.firstOrNull;
        default:
          return null;
      }
    }
  }
  final saved = <Bookmark>[];
  final ok = await scope.run(
    context,
    () async => saved.addAll(await c.quickSave(text)),
  );
  if (ok && context.mounted) {
    showHandyMessage(
      context,
      saved.length == 1
          ? tr(
              context,
              'Saved. It waits in Not sorted.',
              'Đã lưu. Link nằm trong Chưa xếp.',
            )
          : tr(
              context,
              '${saved.length} links saved to Not sorted.',
              'Đã lưu ${saved.length} link vào Chưa xếp.',
            ),
    );
  }
  return null;
}
