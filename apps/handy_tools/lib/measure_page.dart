import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';

/// Lengths read off a photo against a bank card or an A4 sheet. The photo
/// stays in memory while the panel is open; nothing is stored.
class MeasurePage extends StatelessWidget {
  final HandyFiles files;
  final ScanCamera? camera;
  final Widget Function(BuildContext, List<Widget>)? header;
  const MeasurePage({super.key, required this.files, this.camera, this.header});

  @override
  Widget build(BuildContext context) {
    final cam = camera ?? SystemScanCamera();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) header!(context, const []),
        HandyMeasurePanel(
          pickImage: () async => (await files.importBytes(
            extensions: const ['png', 'jpg', 'jpeg', 'webp'],
            maxBytes: 20000000,
          ))?.bytes,
          capture: cam.supported
              ? () async => (await cam.capture())?.bytes
              : null,
          actions: (context, lengths) => [
            OutlinedButton.icon(
              key: const Key('measure-copy'),
              onPressed: () => copyToClipboard(
                context,
                lengths.map(handyMeasureLabel).join('\n'),
              ),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(tr(context, 'Copy lengths', 'Sao chép số đo')),
            ),
          ],
        ),
      ],
    );
  }
}
