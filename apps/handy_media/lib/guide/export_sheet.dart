import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';

const guideFormats = [
  (
    'pdf',
    Icons.picture_as_pdf_outlined,
    'PDF',
    'PDF',
    'Numbered steps with their pictures, ready to print or send',
    'Các bước đánh số kèm ảnh, sẵn để in hay gửi',
  ),
  (
    'html',
    Icons.public,
    'Web page',
    'Trang web',
    'One file that opens in any browser',
    'Một tệp mở được trong mọi trình duyệt',
  ),
  (
    'long',
    Icons.view_day_outlined,
    'Long image',
    'Ảnh dài',
    'Every step in one picture, 1000 px wide',
    'Mọi bước trong một ảnh, rộng 1000 px',
  ),
  (
    'md',
    Icons.notes,
    'Markdown',
    'Markdown',
    'The words only; check the captions',
    'Chỉ phần chữ; hãy soát chú thích',
  ),
  (
    'zip',
    Icons.folder_zip_outlined,
    'Pictures and page (ZIP)',
    'Ảnh và trang (ZIP)',
    'Each step as a PNG, with the page',
    'Mỗi bước một PNG, kèm trang hướng dẫn',
  ),
  (
    'diff',
    Icons.compare_outlined,
    'Change map',
    'Bản đồ thay đổi',
    'What differs between the first two steps',
    'Chỗ khác nhau giữa hai bước đầu',
  ),
];

/// Picks the format, and on devices that can whether to share instead of
/// saving. Null when dismissed.
Future<({String format, bool share})?> pickGuideFormat(
  BuildContext context,
  CaptureProject guide,
) {
  var share = false;
  return showModalBottomSheet<({String format, bool share})>(
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
                tr(
                  context,
                  'Export ${guide.steps.length} steps',
                  'Xuất ${guide.steps.length} bước',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (localShareSupported)
              SwitchListTile(
                key: const Key('guide-share-destination'),
                title: Text(
                  tr(context, 'Share instead of saving', 'Chia sẻ thay vì lưu'),
                ),
                value: share,
                onChanged: (v) => setState(() => share = v),
              ),
            for (final (id, icon, en, vi, hintEn, hintVi) in guideFormats)
              HandyTile(
                key: Key('guide-export-$id'),
                icon: icon,
                title: tr(context, en, vi),
                subtitle: tr(context, hintEn, hintVi),
                onTap: () => Navigator.pop(context, (format: id, share: share)),
              ),
          ],
        ),
      ),
    ),
  );
}

/// The last look before anything leaves: what was found in the words, and
/// that masks are painted in. False unless the person goes on.
Future<bool> reviewGuide(
  BuildContext context,
  CaptureProject guide,
  String format,
) async {
  final found = findSensitiveGuideText(guide).length;
  final diff = format == 'diff';
  return await showAdaptiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: Text(
            tr(context, 'Review before sharing', 'Kiểm tra trước khi chia sẻ'),
          ),
          content: Text(
            tr(
              context,
              '${found == 0 ? 'No email, phone number or key was found in the words.' : '$found possible emails, phone numbers or keys are in the words.'} Text inside pictures is not read, so look at each step. Hidden areas are painted over in the export.${diff ? ' Hide the same areas on both steps: a change map can show the shape of text.' : ''}',
              '${found == 0 ? 'Không thấy email, số điện thoại hay mã khóa trong phần chữ.' : 'Có $found chỗ có thể là email, số điện thoại hoặc mã khóa trong phần chữ.'} Chữ trong ảnh không được đọc, hãy xem từng bước. Vùng che được tô kín trong bản xuất.${diff ? ' Che cùng vùng ở cả hai bước: bản đồ thay đổi có thể lộ hình dạng chữ.' : ''}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'Cancel', 'Hủy')),
            ),
            FilledButton(
              key: const Key('guide-review-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, 'Export', 'Xuất')),
            ),
          ],
        ),
      ) ==
      true;
}
