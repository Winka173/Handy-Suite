import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_capture/handy_capture.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'capture/capture_parts.dart';

class NativeCapturePage extends StatefulWidget {
  final HandyFiles files;
  final Future<void> Function(CaptureResult result, Uint8List bytes) annotate;
  const NativeCapturePage({
    super.key,
    required this.files,
    required this.annotate,
  });
  @override
  State<NativeCapturePage> createState() => NativeCapturePageState();
}

class NativeCapturePageState extends State<NativeCapturePage>
    with WidgetsBindingObserver {
  final native = const NativeCapture();
  final start = TextEditingController(text: '0'),
      end = TextEditingController(),
      frame = TextEditingController(text: '0');
  final clips = <CaptureResult>[];
  CaptureResult? last;
  Timer? polling;
  CancellationToken? operation;
  bool busy = false, recording = false, pending = false, refreshing = false;
  String error = '', notice = '';
  String? seenNativeUri, seenNativeError;
  int delay = 3000;
  int videoRotation = 0, videoEdge = 720;
  bool videoMute = false;
  bool get appOnlyRecording => defaultTargetPlatform == TargetPlatform.iOS;

  /// Lets the page's parts change its settings.
  void update(VoidCallback change) => setState(change);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (nativeCaptureAvailable) {
      refresh();
      polling = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && nativeCaptureAvailable) refresh();
  }

  @override
  void dispose() {
    operation?.cancel();
    polling?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    start.dispose();
    end.dispose();
    frame.dispose();
    super.dispose();
  }

  void accept(CaptureResult next) {
    last = next;
    if (next.mime == 'video/mp4') {
      if (!clips.any((c) => c.uri == next.uri)) {
        if (clips.length == 20) clips.removeAt(0);
        clips.add(next);
      }
      end.text = '${next.durationMs}';
    }
  }

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final status = await native.status();
      if (mounted)
        setState(() {
          recording = status.recording;
          pending = status.pending;
          // Observe each completed capture once; do not replace processed output
          // with an unchanged older native status on every poll.
          if (operation?.isCancelled != true &&
              status.lastResult != null &&
              status.lastResult!.uri != seenNativeUri) {
            seenNativeUri = status.lastResult!.uri;
            accept(status.lastResult!);
          }
          if (!busy && status.error != null && status.error != seenNativeError)
            error = tr(
              context,
              'Capture stopped or canceled. Existing files were kept.',
              'Đã dừng hoặc hủy capture. Giữ nguyên file cũ.',
            );
          seenNativeError = status.error;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => error = tr(
            context,
            'Could not read native capture status.',
            'Không đọc được trạng thái capture.',
          ),
        );
    } finally {
      refreshing = false;
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    final token = CancellationToken();
    operation = token;
    setState(() {
      busy = true;
      error = notice = '';
    });
    try {
      await action();
      token.check();
    } on Cancelled {
      if (mounted)
        setState(
          () => notice = tr(context, 'Operation canceled', 'Đã hủy thao tác'),
        );
    } on PlatformException catch (e) {
      if (mounted)
        setState(
          () => error = e.code == 'E_CANCELED'
              ? tr(
                  context,
                  'System capture canceled.',
                  'Đã hủy capture hệ thống.',
                )
              : tr(
                  context,
                  'Capture/video action failed. Source files were preserved; check format, duration, permission and storage limits.',
                  'Thao tác capture/video thất bại. Giữ nguyên file nguồn; kiểm tra định dạng, thời lượng, quyền và dung lượng.',
                ),
        );
    } catch (e) {
      if (mounted)
        setState(
          () => error = e is FormatException
              ? e.message
              : tr(
                  context,
                  'Action failed; source files were preserved.',
                  'Thao tác thất bại; giữ nguyên file nguồn.',
                ),
        );
    } finally {
      operation = null;
      if (mounted) setState(() => busy = false);
      if (nativeCaptureAvailable) await refresh();
    }
  }

  int millis(TextEditingController field) {
    final value = int.tryParse(field.text.trim());
    if (value == null || value < 0 || value > 300000)
      throw const FormatException('Use integer milliseconds: 0-300000');
    return value;
  }

  Future<void> result(Future<CaptureResult> work) async {
    final next = await work;
    operation?.check();
    if (mounted) setState(() => accept(next));
  }

  Future<void> export() => run(() async {
    final current = last!, bytes = await native.read(current);
    operation?.check();
    final uri = await widget.files.exportBytes(
      current.mime == 'image/png' ? 'capture.png' : 'capture.mp4',
      bytes,
      mimeType: current.mime,
      cancellation: operation,
    );
    if (mounted) {
      setState(
        () => notice = uri == null
            ? tr(context, 'Export canceled', 'Đã hủy xuất')
            : tr(context, 'Saved a copy', 'Đã lưu một bản'),
      );
    }
  });

  Future<void> annotate() => run(() async {
    final current = last!, bytes = await native.read(current);
    operation?.check();
    await widget.annotate(current, bytes);
  });

  Future<void> importVideo() => run(() async {
    final input = await widget.files.importBytes(
      extensions: ['mp4'],
      maxBytes: 30000000,
    );
    if (input != null) await result(native.importVideo(input.bytes));
  });

  Future<void> clear() async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Clear temporary captures?', 'Xóa các bản chụp tạm?'),
      message: tr(
        context,
        'Screenshots and clips kept here are removed. Save the ones you want first. Guides keep their own pictures.',
        'Ảnh và video tạm ở đây sẽ bị xóa. Hãy lưu những cái cần giữ trước. Hướng dẫn vẫn giữ ảnh của chúng.',
      ),
      confirmLabel: tr(context, 'Clear', 'Xóa'),
      destructive: true,
    );
    if (!ok) return;
    await run(() async {
      await native.clear();
      if (mounted) {
        setState(() {
          clips.clear();
          last = null;
          seenNativeUri = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Capture the screen', 'Chụp màn hình')),
        actions: [
          if (nativeCaptureAvailable)
            HandyMenuButton(
              items: [
                HandyMenuItem(
                  Icons.video_file_outlined,
                  tr(context, 'Open an MP4', 'Mở một MP4'),
                  busy || pending ? null : importVideo,
                  key: const Key('native-import-video'),
                ),
                HandyMenuItem(
                  Icons.delete_sweep_outlined,
                  tr(
                    context,
                    'Clear temporary captures',
                    'Xóa các bản chụp tạm',
                  ),
                  busy || recording ? null : clear,
                  destructive: true,
                  key: const Key('native-clear'),
                ),
              ],
            ),
        ],
      ),
      body: !nativeCaptureAvailable
          ? HandyEmpty(
              title: tr(
                context,
                'Screen capture is in the Android and iOS apps',
                'Chụp màn hình có trong ứng dụng Android và iOS',
              ),
              message: tr(
                context,
                'Here, add screenshots to a guide from your files.',
                'Ở đây, hãy thêm ảnh chụp vào hướng dẫn từ tệp của bạn.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(HandySpace.l),
              children: [
                HandyContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TakePanel(page: this),
                      if (error.isNotEmpty) ...[
                        const SizedBox(height: HandySpace.m),
                        HandyNotice(
                          error,
                          key: const Key('native-capture-error'),
                          tone: HandyTone.error,
                        ),
                      ],
                      if (notice.isNotEmpty) ...[
                        const SizedBox(height: HandySpace.m),
                        HandyNotice(notice),
                      ],
                      if (last != null) ...[
                        const SizedBox(height: HandySpace.l),
                        LastCapture(page: this),
                      ],
                      if (last?.mime == 'video/mp4') ...[
                        const SizedBox(height: HandySpace.l),
                        VideoTools(page: this),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
}
