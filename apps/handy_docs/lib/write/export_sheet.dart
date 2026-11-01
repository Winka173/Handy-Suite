import 'package:handy_ui/kit.dart';

/// Picks the format to export the draft in, and on phones whether to hand it
/// to the share sheet instead of saving it. Null when dismissed.
Future<({String kind, bool share})?> pickExport(BuildContext context) {
  var share = false;
  return showModalBottomSheet<({String kind, bool share})>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: HandySpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HandySpace.l,
                0,
                HandySpace.l,
                HandySpace.s,
              ),
              child: Text(
                tr(context, 'Export the draft', 'Xuất bản nháp'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (localShareSupported)
              SwitchListTile(
                key: const Key('markdown-share-destination'),
                title: Text(
                  tr(context, 'Share instead of saving', 'Chia sẻ thay vì lưu'),
                ),
                value: share,
                onChanged: (v) => setState(() => share = v),
              ),
            for (final (kind, icon, en, vi, hintEn, hintVi) in _formats)
              HandyTile(
                key: Key('markdown-export-$kind'),
                icon: icon,
                title: tr(context, en, vi),
                subtitle: tr(context, hintEn, hintVi),
                onTap: () => Navigator.pop(context, (kind: kind, share: share)),
              ),
          ],
        ),
      ),
    ),
  );
}

const _formats = [
  (
    'pdf',
    Icons.picture_as_pdf_outlined,
    'PDF',
    'PDF',
    'Selectable text, local fonts, up to 100 pages',
    'Chọn được chữ, phông trên máy, tối đa 100 trang',
  ),
  (
    'md',
    Icons.notes,
    'Markdown',
    'Markdown',
    'The source exactly as written',
    'Nguyên văn mã nguồn',
  ),
  (
    'html',
    Icons.code,
    'Web page',
    'Trang web',
    'HTML with raw HTML escaped',
    'HTML, mã HTML thô được escape',
  ),
  (
    'txt',
    Icons.text_snippet_outlined,
    'Plain text',
    'Văn bản thường',
    'The words without formatting',
    'Chỉ chữ, bỏ định dạng',
  ),
  (
    'zip',
    Icons.folder_zip_outlined,
    'Document pack',
    'Gói tài liệu',
    'ZIP with the source, HTML, text and PDF',
    'ZIP gồm mã nguồn, HTML, văn bản và PDF',
  ),
];

/// What an export came to, in one sentence.
String exportMessage(
  BuildContext context,
  String? result,
  bool historyUnavailable,
) => switch (result) {
  null => tr(context, 'Export canceled', 'Đã hủy xuất'),
  'share-selected' => tr(context, 'Shared', 'Đã chia sẻ'),
  'share-unknown' => tr(
    context,
    'The share sheet closed; export a copy if it did not arrive.',
    'Bảng chia sẻ đã đóng; hãy xuất một bản nếu chưa tới nơi.',
  ),
  _ when historyUnavailable => tr(
    context,
    'Exported. The export history could not be updated.',
    'Đã xuất. Chưa cập nhật được lịch sử xuất.',
  ),
  _ => tr(context, 'Exported', 'Đã xuất'),
};
