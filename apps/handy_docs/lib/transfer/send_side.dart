import 'dart:async';
import 'package:flutter/services.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import '../pdf/make_panel.dart' show fileSize;
import 'qr_view.dart';

/// Types worth sending by QR: small documents, notes, cards and pictures.
const transferExtensions = [
  'pdf', 'txt', 'md', 'csv', 'json', 'html', 'vcf', 'ics', //
  'docx', 'xlsx', 'png', 'jpg', 'jpeg', 'webp', 'zip', 'hseal',
];

/// Send: choose a file, and its frames play at once on a white sheet until
/// the other device has them all. Playing is the content, so it runs with
/// reduced motion too; Pause holds one frame.
class SendSide extends StatefulWidget {
  final HandyFiles files;
  const SendSide({super.key, required this.files});
  @override
  State<SendSide> createState() => _SendSideState();
}

class _SendSideState extends State<SendSide> {
  ImportedBytes? file;
  List<String> frames = const [];
  final matrices = <int, List<List<bool>>>{};
  int index = 0;
  bool paused = false;
  Timer? timer;
  String? error;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> choose() async {
    try {
      final picked = await widget.files.importBytes(
        extensions: transferExtensions,
        maxBytes: qrTransferLimit,
      );
      if (picked == null || !mounted) return;
      if (picked.bytes.length > qrTransferLimit) {
        throw const FormatException('File exceeds the QR limit');
      }
      final next = qrTransferFrames(picked.name, picked.bytes);
      timer?.cancel();
      setState(() {
        file = picked;
        frames = next;
        matrices.clear();
        index = 0;
        paused = false;
        error = null;
      });
      play();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => error = e is FormatException && e.message.contains('limit')
            ? tr(
                context,
                'That file is over 100 KB. Send a smaller one, or shrink the PDF first.',
                'Tệp lớn hơn 100 KB. Hãy gửi tệp nhỏ hơn, hoặc làm nhỏ PDF trước.',
              )
            : errorText(context, e),
      );
    }
  }

  void play() {
    timer?.cancel();
    timer = Timer.periodic(
      const Duration(milliseconds: 1000 ~/ qrTransferFps),
      (_) => setState(() => index = (index + 1) % frames.length),
    );
  }

  void toggle() {
    if (frames.isEmpty) return;
    setState(() => paused = !paused);
    paused ? timer?.cancel() : play();
  }

  List<List<bool>> matrix(int i) =>
      matrices.putIfAbsent(i, () => qrTransferMatrix(frames[i]));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final f = file;
    final notice = error == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: HandySpace.m),
            child: HandyNotice(error!, tone: HandyTone.error),
          );
    if (f == null || frames.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HandyEmpty(
            title: tr(
              context,
              'Show a file as moving QR codes',
              'Hiện tệp thành mã QR chạy liên tục',
            ),
            message: tr(
              context,
              'On the other device, open Docs, Send to another device, Receive, and point the camera here. Up to 100 KB: a note, a page or two of PDF, a contact card. Nothing goes over a network.',
              'Trên máy kia, mở Docs, Gửi sang máy khác, Nhận, rồi hướng camera vào đây. Tối đa 100 KB: một ghi chú, một hai trang PDF, một danh thiếp. Không đi qua mạng.',
            ),
            action: FilledButton(
              key: const Key('transfer-choose'),
              onPressed: choose,
              child: Text(tr(context, 'Choose a file', 'Chọn tệp')),
            ),
          ),
          ?notice,
        ],
      );
    }
    final data = frames.length - 1;
    final reading = index == 0
        ? tr(context, 'name and size', 'tên và cỡ tệp')
        : tr(
            context,
            'frame ${formatFigure(context, '$index')} of ${formatFigure(context, '$data')}',
            'khung ${formatFigure(context, '$index')}/${formatFigure(context, '$data')}',
          );
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.space): toggle},
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.maxWidth.clamp(200.0, 420.0);
            return Column(
              children: [
                QrView(
                  key: const Key('transfer-code'),
                  modules: matrix(index),
                  size: size,
                  label: tr(
                    context,
                    'Moving QR code for ${f.name}',
                    'Mã QR chạy cho ${f.name}',
                  ),
                ),
                const SizedBox(height: HandySpace.m),
                Text(
                  f.name,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: HandySpace.xs),
                Text(
                  '${fileSize(context, f.bytes.length)} · $reading',
                  key: const Key('transfer-frame'),
                  style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                ),
                const SizedBox(height: HandySpace.l),
                Wrap(
                  spacing: HandySpace.s,
                  runSpacing: HandySpace.s,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.tonalIcon(
                      key: const Key('transfer-pause'),
                      onPressed: toggle,
                      icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                      label: Text(
                        paused
                            ? tr(context, 'Resume', 'Chạy tiếp')
                            : tr(context, 'Pause', 'Tạm dừng'),
                      ),
                    ),
                    TextButton(
                      key: const Key('transfer-another'),
                      onPressed: choose,
                      child: Text(
                        tr(context, 'Choose another file', 'Chọn tệp khác'),
                      ),
                    ),
                  ],
                ),
                ?notice,
              ],
            );
          },
        ),
      ),
    );
  }
}
