import 'package:flutter/services.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import '../pdf/make_panel.dart' show fileSize;

/// Builds the live camera view that reports each code it reads.
typedef TransferScanner = Widget Function(ValueChanged<String> onCode);

const _mime = {
  'pdf': 'application/pdf',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'csv': 'text/csv',
  'json': 'application/json',
  'html': 'text/html',
  'vcf': 'text/vcard',
  'ics': 'text/calendar',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'zip': 'application/zip',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

String transferMime(String name) {
  final dot = name.lastIndexOf('.');
  return _mime[dot < 0 ? '' : name.substring(dot + 1).toLowerCase()] ??
      'application/octet-stream';
}

/// Receive: the camera reads the sender's codes in any order; a bar shows
/// how many frames are in. The checksum decides: a damaged file is never
/// offered to save.
class ReceiveSide extends StatefulWidget {
  final HandyFiles files;
  final TransferScanner scanner;
  const ReceiveSide({super.key, required this.files, required this.scanner});
  @override
  State<ReceiveSide> createState() => _ReceiveSideState();
}

class _ReceiveSideState extends State<ReceiveSide> {
  var receiver = QrTransferReceiver();
  ({String name, Uint8List bytes})? file;
  String? error, saved;

  void read(String code) {
    if (file != null || !receiver.accept(code)) return;
    if (!receiver.complete) {
      setState(() => error = null);
      return;
    }
    try {
      final got = receiver.result();
      HapticFeedback.mediumImpact();
      setState(() => file = got);
    } on FormatException {
      setState(() {
        receiver = QrTransferReceiver();
        error = tr(
          context,
          'The file did not arrive intact. Keep the camera on the code; it starts over.',
          'Tệp nhận bị lỗi. Giữ camera hướng vào mã; việc nhận bắt đầu lại.',
        );
      });
    }
  }

  Future<void> save() async {
    final f = file!;
    try {
      final where = await widget.files.exportBytes(
        f.name,
        f.bytes,
        mimeType: transferMime(f.name),
      );
      if (where != null && mounted) setState(() => saved = f.name);
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    }
  }

  void again() => setState(() {
    receiver = QrTransferReceiver();
    file = null;
    saved = null;
    error = null;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final f = file;
    final count = receiver.count;
    final status = f != null
        ? tr(context, 'Arrived whole', 'Đã nhận đủ')
        : count == null
        ? (receiver.waiting > 0
              ? tr(
                  context,
                  'Reading… waiting for the name',
                  'Đang đọc… chờ tên tệp',
                )
              : tr(
                  context,
                  'Point the camera at the code on the other screen',
                  'Hướng camera vào mã trên màn hình kia',
                ))
        : tr(
            context,
            '${formatFigure(context, '${receiver.received}')} of ${formatFigure(context, '$count')} frames',
            '${formatFigure(context, '${receiver.received}')}/${formatFigure(context, '$count')} khung',
          );
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.maxWidth.clamp(200.0, 420.0);
        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              // Once the file is in, the camera gives way to a short band so
              // Save sits near the top.
              child: SizedBox(
                width: size,
                height: f == null ? size : 96,
                child: f == null
                    ? widget.scanner(read)
                    : ColoredBox(
                        color: c.raised,
                        child: Icon(
                          Icons.task_alt,
                          size: 40,
                          color: theme.colorScheme.primary,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: HandySpace.m),
            if (receiver.name case final name?)
              Text(
                name,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: HandySpace.s),
            SizedBox(
              width: size,
              child: LinearProgressIndicator(
                value: count == null ? 0 : receiver.received / count,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: HandySpace.s),
            Semantics(
              liveRegion: true,
              child: Text(
                [
                  if (receiver.size case final size?) fileSize(context, size),
                  status,
                ].join(' · '),
                key: const Key('transfer-progress'),
                style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                textAlign: TextAlign.center,
              ),
            ),
            if (f != null) ...[
              const SizedBox(height: HandySpace.l),
              Wrap(
                spacing: HandySpace.s,
                runSpacing: HandySpace.s,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    key: const Key('transfer-save'),
                    onPressed: save,
                    child: Text(tr(context, 'Save file', 'Lưu tệp')),
                  ),
                  TextButton(
                    key: const Key('transfer-again'),
                    onPressed: again,
                    child: Text(
                      tr(context, 'Receive another', 'Nhận tệp khác'),
                    ),
                  ),
                ],
              ),
            ],
            if (saved != null)
              Padding(
                padding: const EdgeInsets.only(top: HandySpace.m),
                child: HandyNotice(
                  tr(context, 'Saved: $saved', 'Đã lưu: $saved'),
                  tone: HandyTone.success,
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: HandySpace.m),
                child: HandyNotice(error!, tone: HandyTone.warning),
              ),
          ],
        );
      },
    );
  }
}
