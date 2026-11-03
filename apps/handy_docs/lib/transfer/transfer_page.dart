import 'package:handy_files/handy_files.dart';
import 'package:handy_scan/handy_scan.dart';
import 'package:handy_ui/kit.dart';
import 'receive_side.dart';
import 'send_side.dart';

/// Send to another device: one small file as moving QR codes, no cable,
/// network or account. Send works everywhere; Receive needs the camera of
/// an Android or iOS device, so a phone opens on Receive.
class TransferPage extends StatefulWidget {
  final HandyFiles files;

  /// Whether this device can read codes with its camera.
  final bool camera;
  final TransferScanner scanner;
  TransferPage({
    super.key,
    required this.files,
    bool? camera,
    TransferScanner? scanner,
  }) : camera = camera ?? nativeQrScanningSupported,
       scanner = scanner ?? ((onCode) => QrStreamScanner(onCode: onCode));
  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  late bool receiving = widget.camera;

  @override
  Widget build(BuildContext context) => HandyPage(
    title: tr(context, 'Send to another device', 'Gửi sang máy khác'),
    children: [
      Center(
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: false,
              label: Text(
                tr(context, 'Send', 'Gửi'),
                key: const Key('transfer-send'),
              ),
            ),
            ButtonSegment(
              value: true,
              label: Text(
                tr(context, 'Receive', 'Nhận'),
                key: const Key('transfer-receive'),
              ),
            ),
          ],
          selected: {receiving},
          onSelectionChanged: (s) => setState(() => receiving = s.first),
        ),
      ),
      const SizedBox(height: HandySpace.l),
      // Each side keeps its own state; switching away stops its timer or
      // camera.
      if (!receiving)
        SendSide(key: const Key('transfer-send-side'), files: widget.files)
      else if (widget.camera)
        ReceiveSide(
          key: const Key('transfer-receive-side'),
          files: widget.files,
          scanner: widget.scanner,
        )
      else
        HandyEmpty(
          title: tr(
            context,
            'Receiving needs a phone camera',
            'Cần camera điện thoại để nhận',
          ),
          message: tr(
            context,
            'Open Docs on an Android phone or iPhone to receive. From here you can send.',
            'Mở Docs trên điện thoại Android hoặc iPhone để nhận. Ở đây bạn có thể gửi.',
          ),
          action: OutlinedButton(
            key: const Key('transfer-use-send'),
            onPressed: () => setState(() => receiving = false),
            child: Text(tr(context, 'Send from here', 'Gửi từ máy này')),
          ),
        ),
    ],
  );
}
