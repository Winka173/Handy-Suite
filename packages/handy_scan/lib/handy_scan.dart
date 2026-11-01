import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:handy_ui/handy_ui.dart';

bool get nativeQrScanningSupported =>
    !kIsWeb &&
    {
      TargetPlatform.android,
      TargetPlatform.iOS,
    }.contains(defaultTargetPlatform);

String validateScannedQr(String value) {
  if (value.isEmpty ||
      value.length > 2000 ||
      utf8.encode(value).length > 2000 ||
      value.contains('\u0000')) {
    throw const FormatException(
      'QR text must contain 1–2000 UTF-8 bytes without NUL',
    );
  }
  return value;
}

/// Native camera only. No URL launch, logs, uploads or storage.
/// The owned MobileScanner manages lifecycle and releases the camera on removal.
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});
  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  String? value;
  String error = '';
  int cameraGeneration = 0;
  void detected(BarcodeCapture capture) {
    if (!mounted || value != null) return;
    for (final code in capture.barcodes) {
      if (code.format != BarcodeFormat.qrCode || code.rawValue == null)
        continue;
      try {
        final text = validateScannedQr(code.rawValue!);
        setState(() {
          value = text;
          error = '';
        });
      } on FormatException catch (e) {
        setState(() => error = e.message);
      }
      break;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'Scan QR', 'Quét QR'))),
    body: !nativeQrScanningSupported
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                tr(
                  context,
                  'Camera scanning supports Android and iOS. Paste QR text on this platform.',
                  'Quét camera hỗ trợ Android và iOS. Hãy dán nội dung QR trên nền tảng này.',
                ),
              ),
            ),
          )
        : Column(
            children: [
              if (value == null)
                Expanded(
                  child: MobileScanner(
                    key: ValueKey(cameraGeneration),
                    onDetect: detected,
                    onDetectError: (_, _) {
                      if (mounted)
                        setState(
                          () => error = tr(
                            context,
                            'QR could not be read. Try again.',
                            'Không đọc được QR. Hãy thử lại.',
                          ),
                        );
                    },
                    errorBuilder: (context, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tr(
                                context,
                                'Camera is unavailable or permission was denied. Enable camera access in system settings, then retry.',
                                'Camera không khả dụng hoặc bị từ chối quyền. Bật quyền camera trong cài đặt hệ thống rồi thử lại.',
                              ),
                            ),
                            TextButton(
                              key: const Key('qr-camera-retry'),
                              onPressed: () => setState(() {
                                cameraGeneration++;
                                error = '';
                              }),
                              child: Text(tr(context, 'Retry', 'Thử lại')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(
                      value!,
                      key: const Key('qr-scan-result'),
                    ),
                  ),
                ),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      tr(
                        context,
                        'Processed on this device. Review before using. Links and Wi-Fi settings never open automatically.',
                        'Xử lý trên thiết bị. Kiểm tra trước khi dùng. Không tự mở liên kết hoặc cài đặt Wi-Fi.',
                      ),
                    ),
                    if (value != null)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => value = null),
                              child: Text(
                                tr(context, 'Scan again', 'Quét lại'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              key: const Key('qr-scan-use'),
                              onPressed: () => Navigator.pop(context, value),
                              child: Text(
                                tr(context, 'Use text', 'Dùng nội dung'),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
  );
}
