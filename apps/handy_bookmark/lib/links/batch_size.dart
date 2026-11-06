import 'package:handy_ui/kit.dart';

const quickLinkBatch = 25;

Future<int?> chooseLinkBatch(
  BuildContext context, {
  required int count,
  required int maximum,
  required bool reading,
}) async {
  if (count <= quickLinkBatch) return count;
  final larger = count < maximum ? count : maximum;
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        tr(
          ctx,
          reading ? 'Save readable pages' : 'Check selected links',
          reading ? 'Lưu trang để đọc' : 'Kiểm tra link đã chọn',
        ),
      ),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(
              ctx,
              '$count links selected. Start with up to 25; the rest stay in your library. You can stop the job at any time.',
              'Đã chọn $count link. Bắt đầu tối đa 25; phần còn lại vẫn trong thư viện. Bạn có thể dừng bất cứ lúc nào.',
            ),
          ),
          const SizedBox(height: 16),
          if (reading)
            Text(
              tr(
                ctx,
                'Only readable page text is kept. Videos, signed-in pages and app screens may have nothing to extract.',
                'Chỉ lưu chữ đọc được của trang. Video, trang cần đăng nhập hoặc màn app có thể không lấy được nội dung.',
              ),
            ),
          ExpansionTile(
            key: const Key('link-batch-advanced'),
            tilePadding: EdgeInsets.zero,
            title: Text(
              tr(ctx, 'Advanced · larger batch', 'Nâng cao · lượt lớn hơn'),
            ),
            children: [
              OutlinedButton(
                key: const Key('link-batch-large'),
                onPressed: () => Navigator.pop(ctx, larger),
                child: Text(
                  tr(ctx, 'Run up to $larger', 'Chạy tối đa $larger'),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('link-batch-cancel'),
          onPressed: () => Navigator.pop(ctx),
          child: Text(tr(ctx, 'Cancel', 'Hủy')),
        ),
        FilledButton(
          key: const Key('link-batch-quick'),
          onPressed: () => Navigator.pop(ctx, quickLinkBatch),
          child: Text(tr(ctx, 'Start up to 25', 'Bắt đầu tối đa 25')),
        ),
      ],
    ),
  );
}
