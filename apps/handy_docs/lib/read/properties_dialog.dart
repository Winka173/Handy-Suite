import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_ui/kit.dart';

/// Renames a document and files it under a folder label. Null if canceled.
Future<ReaderDocument?> editProperties(
  BuildContext context,
  ReaderDocument entry,
) async {
  final name = TextEditingController(text: entry.name),
      folder = TextEditingController(text: entry.folder);
  final form = GlobalKey<FormState>();
  try {
    final route = DialogRoute<ReaderDocument>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'Name and folder', 'Tên và thư mục')),
        content: SizedBox(
          width: 360,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('reader-name'),
                  controller: name,
                  maxLength: 200,
                  autofocus: true,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? tr(context, 'Enter a name', 'Nhập tên')
                      : null,
                  decoration: InputDecoration(
                    labelText: tr(context, 'Name', 'Tên'),
                  ),
                ),
                const SizedBox(height: HandySpace.l),
                TextFormField(
                  key: const Key('reader-folder'),
                  controller: folder,
                  maxLength: 100,
                  validator: (v) => RegExp(r'[\x00-\x1f\x7f]').hasMatch(v ?? '')
                      ? tr(
                          context,
                          'Remove control characters',
                          'Bỏ ký tự điều khiển',
                        )
                      : null,
                  decoration: InputDecoration(
                    labelText: tr(context, 'Folder', 'Thư mục'),
                    hintText: tr(context, 'Work, School…', 'Công việc, Học…'),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Cancel', 'Hủy')),
          ),
          FilledButton(
            key: const Key('reader-properties-apply'),
            onPressed: () {
              if (form.currentState?.validate() != true) return;
              Navigator.pop(
                context,
                entry.copyWith(
                  name: safeFilename(name.text),
                  folder: folder.text.trim(),
                ),
              );
            },
            child: Text(tr(context, 'Save', 'Lưu')),
          ),
        ],
      ),
    );
    final next = await Navigator.of(context).push(route);
    await route.completed;
    return next;
  } finally {
    name.dispose();
    folder.dispose();
  }
}
