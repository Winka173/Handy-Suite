import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_storage/recovery.dart';
import 'package:handy_ui/kit.dart';
import '../capture_draft.dart';
import '../guide/editor_page.dart';
import '../guide/text_reader.dart';
import 'media_store.dart';

/// Opens [guide] in the editor, offering its draft copy back first.
///
/// A new guide is put in the library at once so a draft written before a
/// crash can be found again; if it is never saved it is taken out again
/// when the editor closes.
Future<void> openGuide(
  BuildContext context, {
  required MediaStore store,
  required HandyFiles files,
  required PortableCapture guide,
  ScanCamera? camera,
  TextReader? reader,
}) async {
  final id = guide.project.id;
  final fresh = !store.holds(id);
  if (fresh) await store.save(guide);
  final draft = CaptureDraft(store.drafts(id), id);
  var initial = guide;
  try {
    final saved = await draft.load();
    if (saved != null && context.mounted) {
      final restore = await showAdaptiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: Text(
            tr(context, 'Pick up where you left off?', 'Làm tiếp chỗ đang dở?'),
          ),
          content: Text(
            tr(
              context,
              'There are edits from last time that were not saved. The saved guide stays as it is until you press Save.',
              'Có các chỉnh sửa lần trước chưa được lưu. Hướng dẫn đã lưu giữ nguyên tới khi bạn bấm Lưu.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'Not now', 'Để sau')),
            ),
            TextButton(
              key: const Key('draft-discard'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'Throw them away', 'Bỏ chúng')),
            ),
            FilledButton(
              key: const Key('draft-restore'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, 'Pick up', 'Làm tiếp')),
            ),
          ],
        ),
      );
      if (restore == null) {
        draft.dispose();
        return;
      }
      if (restore) {
        initial = saved;
      } else {
        await draft.clear();
      }
    }
  } catch (_) {
    draft.dispose();
    if (context.mounted) {
      await showAdaptiveDialog<void>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: Text(
            tr(context, 'The draft cannot be read', 'Không đọc được bản nháp'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(
                  context,
                  'The saved guide and the draft file are unchanged. An earlier copy may bring the draft back.',
                  'Hướng dẫn đã lưu và tệp nháp vẫn giữ nguyên. Một bản trước đó có thể khôi phục bản nháp.',
                ),
              ),
              const SizedBox(height: HandySpace.m),
              DocumentRecoveryButton(
                documents: draft.documents,
                files: files,
                reload: () async {},
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'Close', 'Đóng')),
            ),
          ],
        ),
      );
    }
    return;
  }
  if (!context.mounted) {
    draft.dispose();
    return;
  }
  var committed = false;
  await Navigator.push(
    context,
    MaterialPageRoute<void>(
      settings: RouteSettings(name: '/guide/$id'),
      builder: (_) => CaptureEditor(
        initial: initial,
        draft: draft,
        restoredDraft: !identical(initial, guide),
        pickFirst: fresh,
        files: files,
        camera: camera,
        reader: reader,
        onCommit: (next) async {
          await store.save(next);
          committed = true;
        },
      ),
    ),
  );
  if (fresh && !committed && store.holds(id)) {
    try {
      await store.remove(id);
    } catch (_) {
      // A guide left behind is harmless; it can be deleted by hand.
    }
  }
}
