import 'package:flutter/foundation.dart';
import 'package:handy_ui/kit.dart';
import '../design/clipping.dart';
import '../design/theme.dart';

/// "Save from other apps with Share": the steps on one short sheet, in
/// the onboarding's face, instead of replaying the whole guide.
Future<void> showShareHowTo(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (sheet) {
    final theme = Theme.of(sheet);
    final p = BookmarkPalette.of(sheet);
    // Collections in the share sheet's top row: Android 10 and later.
    final shortcuts = defaultTargetPlatform == TargetPlatform.android;
    final steps = [
      tr(
        sheet,
        'In TikTok, YouTube, Facebook or the browser, tap Share.',
        'Trong TikTok, YouTube, Facebook hay trình duyệt, bấm Chia sẻ.',
      ),
      tr(
        sheet,
        'Not in that list? Tap More to open your phone’s own list.',
        'Không thấy trong danh sách? Bấm Khác để mở danh sách của máy.',
      ),
      tr(
        sheet,
        'Swipe the row of apps to find Handy Bookmark, and tap it. It is saved at once and you stay where you were; it waits in Not sorted.',
        'Vuốt hàng app để tìm Handy Bookmark rồi bấm. Mục được lưu ngay, bạn vẫn ở lại app đang xem; nó chờ ở Chưa xếp.',
      ),
      if (shortcuts)
        tr(
          sheet,
          'Next time, your recent collections sit in the top row: one tap saves straight into one.',
          'Lần sau, các bộ sưu tập vừa dùng nằm ở hàng đầu: một chạm là vào thẳng.',
        ),
    ];
    return SingleChildScrollView(
      key: const Key('share-how-to'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(
            before: tr(sheet, 'Save from ', 'Lưu từ '),
            words: tr(sheet, 'any app', 'mọi app'),
          ),
          const SizedBox(height: HandySpace.l),
          for (final (i, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: HandySpace.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.tint,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: p.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: HandySpace.m),
                  Expanded(
                    child: Text(
                      step,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: p.ink,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: HandySpace.s),
          FilledButton(
            key: const Key('share-how-done'),
            style: sheetButtonStyle(sheet),
            onPressed: () => Navigator.pop(sheet),
            child: Text(tr(sheet, 'Got it', 'Đã hiểu')),
          ),
        ],
      ),
    );
  },
);
