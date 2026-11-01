import 'package:handy_pdf/handy_pdf.dart';
import 'package:handy_ui/kit.dart';
import 'pdf_desk.dart';

/// "Make a new PDF": which pages, in what order, turned and stamped; or all
/// files merged. The result waits here until it is saved.
class MakePanel extends StatelessWidget {
  final PdfDesk desk;
  final bool busy;
  final TextEditingController range, watermark;
  final int rotation;
  final ValueChanged<int> onRotation;
  final VoidCallback onMake, onMerge, onSave;
  const MakePanel({
    super.key,
    required this.desk,
    required this.busy,
    required this.range,
    required this.watermark,
    required this.rotation,
    required this.onRotation,
    required this.onMake,
    required this.onMerge,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, 'Make a new PDF', 'Tạo PDF mới'),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: HandySpace.xs),
        Text(
          tr(
            context,
            'From ${desk.inputs[desk.selected].name}. The original stays as it is.',
            'Từ ${desk.inputs[desk.selected].name}. Tệp gốc giữ nguyên.',
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: HandySpace.l),
        TextField(
          key: const Key('pdf-range'),
          controller: range,
          enabled: !busy,
          onChanged: (_) => desk.dropOutput(),
          decoration: InputDecoration(
            labelText: tr(context, 'Pages, in order', 'Các trang, theo thứ tự'),
            hintText: '3, 1-2, 1',
            helperText: tr(
              context,
              'Blank takes every page. Repeat a number to copy a page.',
              'Để trống để lấy mọi trang. Lặp số để nhân đôi trang.',
            ),
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: HandySpace.l),
        Text(
          tr(context, 'Turn clockwise', 'Xoay theo chiều kim đồng hồ'),
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: HandySpace.s),
        SegmentedButton<int>(
          key: const Key('pdf-rotation'),
          showSelectedIcon: false,
          segments: [
            for (final a in [0, 90, 180, 270])
              ButtonSegment(value: a, label: Text('$a°')),
          ],
          selected: {rotation},
          onSelectionChanged: busy ? null : (v) => onRotation(v.single),
        ),
        const SizedBox(height: HandySpace.l),
        if (supportsPdfWatermark)
          TextField(
            key: const Key('pdf-watermark'),
            controller: watermark,
            enabled: !busy,
            maxLength: 100,
            onChanged: (_) => desk.dropOutput(),
            decoration: InputDecoration(
              labelText: tr(
                context,
                'Stamp text (optional)',
                'Chữ đóng dấu (tùy chọn)',
              ),
              helperText: tr(
                context,
                'Latin letters and digits, in grey at the foot of each page.',
                'Chữ Latin và số không dấu, màu xám ở chân mỗi trang.',
              ),
              helperMaxLines: 2,
            ),
          )
        else
          HandyNotice(
            tr(
              context,
              'Stamping text needs the Android, iOS or Windows app.',
              'Đóng dấu chữ cần ứng dụng Android, iOS hoặc Windows.',
            ),
          ),
        const SizedBox(height: HandySpace.l),
        FilledButton(
          key: const Key('pdf-transform'),
          onPressed: busy ? null : onMake,
          child: Text(tr(context, 'Make PDF', 'Tạo PDF')),
        ),
        if (desk.inputs.length > 1) ...[
          const SizedBox(height: HandySpace.s),
          OutlinedButton(
            key: const Key('pdf-merge'),
            onPressed: busy ? null : onMerge,
            child: Text(
              tr(
                context,
                'Merge all ${desk.inputs.length} files',
                'Ghép cả ${desk.inputs.length} tệp',
              ),
            ),
          ),
        ],
        HandyReveal(
          child: desk.output == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: HandySpace.l),
                  child: _Result(desk: desk, busy: busy, onSave: onSave),
                ),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  final PdfDesk desk;
  final bool busy;
  final VoidCallback onSave;
  const _Result({required this.desk, required this.busy, required this.onSave});
  @override
  Widget build(BuildContext context) {
    final merged = desk.outputNote == 'merge';
    final size = (desk.output!.length / 1024).ceil();
    return HandyGroup(
      color: HandyColors.of(context).select,
      children: [
        Padding(
          padding: const EdgeInsets.all(HandySpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                merged
                    ? tr(context, 'Merged PDF ready', 'PDF ghép đã sẵn sàng')
                    : tr(
                        context,
                        'New PDF ready · ${desk.outputNote} pages',
                        'PDF mới đã sẵn sàng · ${desk.outputNote} trang',
                      ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: HandyColors.of(context).selectInk,
                ),
              ),
              Text(
                tr(
                  context,
                  '$size KB, checked. Save it to keep it.',
                  '$size KB, đã kiểm tra. Lưu lại để giữ.',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HandyColors.of(context).selectInk,
                ),
              ),
              const SizedBox(height: HandySpace.m),
              Row(
                children: [
                  FilledButton.icon(
                    key: const Key('pdf-export'),
                    onPressed: busy ? null : onSave,
                    icon: const Icon(Icons.save_alt),
                    label: Text(tr(context, 'Save PDF', 'Lưu PDF')),
                  ),
                  const SizedBox(width: HandySpace.s),
                  HandyShareButton(
                    name: 'handy-document.pdf',
                    mimeType: 'application/pdf',
                    bytes: busy ? null : () => desk.output!,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
