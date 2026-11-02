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
  final VoidCallback onMake, onMerge, onSave, onFill, onDuplex, onSaveBacks;
  final ValueChanged<bool> onCompress;

  /// Page numbers: the first number, whether the cover is left blank, and
  /// bottom right (else bottom centre).
  final void Function(int start, bool skipFirst, bool right) onNumber;
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
    required this.onDuplex,
    required this.onSaveBacks,
    required this.onNumber,
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
        const SizedBox(height: HandySpace.xl),
        _Section(
          title: tr(context, 'Print', 'In'),
          detail: tr(
            context,
            'Both sides on a printer that prints one, and page numbers at the foot.',
            'In hai mặt trên máy in một mặt, và đánh số trang ở chân trang.',
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('pdf-duplex'),
                onPressed: busy || desk.pages < 2 ? null : onDuplex,
                icon: const Icon(Icons.flip_outlined),
                label: Text(
                  tr(
                    context,
                    'Print both sides by hand',
                    'In hai mặt thủ công',
                  ),
                ),
              ),
            ),
            const SizedBox(height: HandySpace.m),
            if (!supportsPdfEditing)
              HandyNotice(
                tr(
                  context,
                  'Page numbers need the Android, iOS or Windows app.',
                  'Đánh số trang cần ứng dụng Android, iOS hoặc Windows.',
                ),
              )
            else
              _NumberControls(busy: busy, onNumber: onNumber),
          ],
        ),
        HandyReveal(
          child: desk.output == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: HandySpace.l),
                  child: _Result(
                    desk: desk,
                    busy: busy,
                    onSave: onSave,
                    onSaveBacks: onSaveBacks,
                  ),
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

class _NumberControls extends StatefulWidget {
  final bool busy;
  final void Function(int start, bool skipFirst, bool right) onNumber;
  const _NumberControls({required this.busy, required this.onNumber});
  @override
  State<_NumberControls> createState() => _NumberControlsState();
}

class _NumberControlsState extends State<_NumberControls> {
  final start = TextEditingController(text: '1');
  bool skipFirst = false, right = false;

  @override
  void dispose() {
    start.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = int.tryParse(start.text.trim());
    final valid = first != null && first >= 0 && first <= 9999;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              key: const Key('pdf-number-centre'),
              label: Text(tr(context, 'Bottom centre', 'Giữa chân trang')),
              selected: !right,
              onSelected: (_) => setState(() => right = false),
            ),
            ChoiceChip(
              key: const Key('pdf-number-right'),
              label: Text(tr(context, 'Bottom right', 'Góc phải dưới')),
              selected: right,
              onSelected: (_) => setState(() => right = true),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr(context, 'Starts at', 'Bắt đầu từ')),
                const SizedBox(width: HandySpace.s),
                SizedBox(
                  width: 88,
                  // Named for screen readers by the label beside it.
                  child: Semantics(
                    label: tr(context, 'Starts at', 'Bắt đầu từ'),
                    child: TextField(
                      key: const Key('pdf-number-start'),
                      controller: start,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        errorText: valid ? null : '0–9999',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        SwitchListTile.adaptive(
          key: const Key('pdf-number-skip'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            tr(
              context,
              'Leave the first page blank',
              'Không đánh số trang đầu',
            ),
          ),
          value: skipFirst,
          onChanged: (v) => setState(() => skipFirst = v),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('pdf-number'),
            onPressed: widget.busy || !valid
                ? null
                : () => widget.onNumber(first, skipFirst, right),
            icon: const Icon(Icons.format_list_numbered),
            label: Text(tr(context, 'Number the pages', 'Đánh số trang')),
          ),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  final PdfDesk desk;
  final bool busy;
  final VoidCallback onSave, onSaveBacks;
  const _Result({
    required this.desk,
    required this.busy,
    required this.onSave,
    required this.onSaveBacks,
  });

  Widget _duplex(BuildContext context) {
    final c = HandyColors.of(context), theme = Theme.of(context);
    final plan = desk.plan!;
    String list(List<int> pages) => pages.length <= 6
        ? pages.map((i) => '${i + 1}').join(', ')
        : '${pages.take(3).map((i) => '${i + 1}').join(', ')} … ${pages.last + 1}';
    final ink = theme.textTheme.bodyLarge?.copyWith(color: c.selectInk);
    final steps = [
      tr(
        context,
        'Print ${desk.duplexName(1, vi: false)}: pages ${list(plan.fronts)}.',
        'In ${desk.duplexName(1, vi: true)}: trang ${list(plan.fronts)}.',
      ),
      plan.lastFrontAlone
          ? tr(
              context,
              'Take out the last sheet (page ${plan.fronts.last + 1} has no back). Turn the rest over and put them back in the tray.',
              'Lấy tờ cuối ra (trang ${plan.fronts.last + 1} không có mặt sau). Lật xấp còn lại và đặt lại vào khay.',
            )
          : tr(
              context,
              'Turn the printed stack over and put it back in the tray.',
              'Lật xấp giấy vừa in và đặt lại vào khay.',
            ),
      tr(
        context,
        'Print ${desk.duplexName(2, vi: false)}: pages ${list(plan.backs)}. If the backs come out upside down, turn the stack the other way next time.',
        'In ${desk.duplexName(2, vi: true)}: trang ${list(plan.backs)}. Nếu mặt sau bị ngược, lần sau lật xấp theo chiều kia.',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.all(HandySpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'Two PDFs for both sides', 'Hai tệp PDF để in hai mặt'),
            key: const Key('pdf-result-title'),
            style: theme.textTheme.titleMedium?.copyWith(color: c.selectInk),
          ),
          const SizedBox(height: HandySpace.s),
          for (final (i, s) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: HandySpace.s),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}.',
                      style: ink?.copyWith(fontFeatures: tabular),
                    ),
                  ),
                  Expanded(child: Text(s, style: ink)),
                ],
              ),
            ),
          const SizedBox(height: HandySpace.s),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              FilledButton.icon(
                key: const Key('pdf-export'),
                onPressed: busy ? null : onSave,
                icon: const Icon(Icons.save_alt),
                label: Text(tr(context, 'Save fronts', 'Lưu mặt trước')),
              ),
              FilledButton.icon(
                key: const Key('pdf-export-backs'),
                onPressed: busy ? null : onSaveBacks,
                icon: const Icon(Icons.save_alt),
                label: Text(tr(context, 'Save backs', 'Lưu mặt sau')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (desk.outputNote == 'duplex' && desk.backs != null) {
      return HandyGroup(
        color: HandyColors.of(context).select,
        children: [_duplex(context)],
      );
    }
    final numbered = desk.outputNote == 'numbered';
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
                    : numbered
                    ? tr(context, 'Page numbers added', 'Đã đánh số trang')
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
