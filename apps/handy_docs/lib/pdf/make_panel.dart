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
  final VoidCallback onMake, onMerge, onSave, onFill;
  final ValueChanged<bool> onCompress;
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
    required this.onFill,
    required this.onCompress,
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
                'In grey at the foot of each page. Vietnamese works.',
                'Màu xám ở chân mỗi trang. Gõ có dấu được.',
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
        const SizedBox(height: HandySpace.xl),
        _Section(
          title: tr(context, 'Sign and fill', 'Ký và điền'),
          detail: tr(
            context,
            'Place a signature, text or a date on the pages, then save a new copy.',
            'Đặt chữ ký, chữ hoặc ngày lên trang rồi lưu thành bản mới.',
          ),
          children: [
            if (!supportsPdfEditing)
              HandyNotice(
                tr(
                  context,
                  'Signing needs the Android, iOS or Windows app.',
                  'Ký và điền cần ứng dụng Android, iOS hoặc Windows.',
                ),
              )
            else
              OutlinedButton.icon(
                key: const Key('pdf-fill'),
                onPressed: busy ? null : onFill,
                icon: const Icon(Icons.draw_outlined),
                label: Text(tr(context, 'Sign and fill', 'Ký và điền')),
              ),
          ],
        ),
        const SizedBox(height: HandySpace.xl),
        _Section(
          title: tr(context, 'Make it smaller', 'Làm nhỏ tệp'),
          detail: tr(
            context,
            'Now ${fileSize(context, desk.inputs[desk.selected].bytes.length)}. A smaller copy is made; this file stays as it is.',
            'Hiện ${fileSize(context, desk.inputs[desk.selected].bytes.length)}. Bản nhỏ hơn là bản mới; tệp này giữ nguyên.',
          ),
          children: [
            if (!supportsPdfEditing)
              HandyNotice(
                tr(
                  context,
                  'Making PDFs smaller needs the Android, iOS or Windows app.',
                  'Làm nhỏ PDF cần ứng dụng Android, iOS hoặc Windows.',
                ),
              )
            else ...[
              Wrap(
                spacing: HandySpace.s,
                runSpacing: HandySpace.s,
                children: [
                  OutlinedButton(
                    key: const Key('pdf-compress'),
                    onPressed: busy ? null : () => onCompress(false),
                    child: Text(tr(context, 'Shrink pictures', 'Nén ảnh')),
                  ),
                  OutlinedButton(
                    key: const Key('pdf-compress-strong'),
                    onPressed: busy ? null : () => onCompress(true),
                    child: Text(tr(context, 'Strong', 'Nén mạnh')),
                  ),
                ],
              ),
              const SizedBox(height: HandySpace.s),
              Text(
                tr(
                  context,
                  'Shrink pictures keeps text and links. Strong turns every page into a picture: text can no longer be selected or searched.',
                  'Nén ảnh giữ chữ và liên kết. Nén mạnh biến mỗi trang thành ảnh: chữ không còn chọn hay tìm được.',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: HandyColors.of(context).muted,
                ),
              ),
            ],
          ],
        ),
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

/// "2,4 MB", "610 KB", in the reader's number style.
String fileSize(BuildContext context, int bytes) {
  if (bytes >= 1000000) {
    final mb = (bytes / 1000000).toStringAsFixed(1);
    return '${formatFigure(context, mb)} MB';
  }
  return '${formatFigure(context, '${(bytes / 1000).ceil()}')} KB';
}

class _Section extends StatelessWidget {
  final String title, detail;
  final List<Widget> children;
  const _Section({
    required this.title,
    required this.detail,
    required this.children,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: HandySpace.xs),
        Text(detail, style: theme.textTheme.bodyMedium),
        const SizedBox(height: HandySpace.m),
        ...children,
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
    final smaller = desk.outputNote == 'smaller' || desk.outputNote == 'strong';
    final size = fileSize(context, desk.output!.length);
    final saved = desk.before == 0
        ? 0
        : (100 - desk.output!.length * 100 / desk.before).floor();
    return HandyGroup(
      color: HandyColors.of(context).select,
      children: [
        Padding(
          padding: const EdgeInsets.all(HandySpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                smaller
                    ? '${fileSize(context, desk.before)} → $size'
                    : merged
                    ? tr(context, 'Merged PDF ready', 'PDF ghép đã sẵn sàng')
                    : tr(
                        context,
                        'New PDF ready · ${desk.outputNote} pages',
                        'PDF mới đã sẵn sàng · ${desk.outputNote} trang',
                      ),
                key: const Key('pdf-result-title'),
                style:
                    (smaller
                            ? Theme.of(context).textTheme.headlineSmall
                            : Theme.of(context).textTheme.titleMedium)
                        ?.copyWith(color: HandyColors.of(context).selectInk),
              ),
              Text(
                smaller
                    ? tr(
                        context,
                        '$saved% smaller${desk.outputNote == 'strong' ? ', pages are pictures now' : ''}. Checked; save it to keep it.',
                        'Nhỏ hơn $saved%${desk.outputNote == 'strong' ? ', các trang giờ là ảnh' : ''}. Đã kiểm tra; lưu lại để giữ.',
                      )
                    : tr(
                        context,
                        '$size, checked. Save it to keep it.',
                        '$size, đã kiểm tra. Lưu lại để giữ.',
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
                    name: desk.outputName,
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
