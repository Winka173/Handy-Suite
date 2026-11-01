import 'package:handy_capture/handy_capture.dart';
import 'package:handy_ui/kit.dart';
import 'package:video_player/video_player.dart';
import 'video_controller_stub.dart'
    if (dart.library.io) 'video_controller_native.dart';

/// Preview only bridge-owned local captures. No URL or arbitrary file opener.
class CaptureVideoPreview extends StatefulWidget {
  final CaptureResult capture;
  const CaptureVideoPreview({super.key, required this.capture});
  @override
  State<CaptureVideoPreview> createState() => _CaptureVideoPreviewState();
}

class _CaptureVideoPreviewState extends State<CaptureVideoPreview>
    with WidgetsBindingObserver {
  VideoPlayerController? controller;
  bool ready = false, failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  Future<void> initialize() async {
    try {
      if (widget.capture.mime != 'video/mp4')
        throw const FormatException('MP4 required');
      // The bridge checks canonical ownership, existence and size. Passing a
      // crafted CaptureResult never opens an arbitrary filesystem location.
      await const NativeCapture().read(widget.capture);
      if (!mounted) return;
      final player = ownedVideoController(Uri.parse(widget.capture.uri));
      controller = player;
      await player.initialize();
      if (!mounted) return;
      await player.setLooping(false);
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) controller?.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  Future<void> action(Future<void> Function() run) async {
    try {
      await run();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr(context, 'Video preview', 'Xem trước video')),
    ),
    body: failed
        ? Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              tr(
                context,
                'Could not play this local video. The source was preserved.',
                'Không phát được video cục bộ. Giữ nguyên file nguồn.',
              ),
              key: const Key('video-preview-error'),
            ),
          )
        : !ready
        ? const Center(child: CircularProgressIndicator())
        : ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller!,
            builder: (context, value, _) {
              if (value.hasError) {
                return Center(
                  child: Text(
                    tr(
                      context,
                      'Video playback failed. The source was preserved.',
                      'Phát video thất bại. Giữ nguyên file nguồn.',
                    ),
                  ),
                );
              }
              final duration = value.duration.inMilliseconds;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  SizedBox(
                    height: (MediaQuery.sizeOf(context).height * .55).clamp(
                      180.0,
                      420.0,
                    ),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: value.aspectRatio > 0
                            ? value.aspectRatio
                            : 16 / 9,
                        child: VideoPlayer(
                          controller!,
                          key: const Key('video-preview-player'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${value.position.inMilliseconds} / $duration ms',
                    key: const Key('video-preview-position'),
                  ),
                  Slider(
                    key: const Key('video-preview-seek'),
                    min: 0,
                    max: duration > 0 ? duration.toDouble() : 1,
                    value: value.position.inMilliseconds
                        .clamp(0, duration)
                        .toDouble(),
                    onChanged: duration > 0
                        ? (v) => action(
                            () => controller!.seekTo(
                              Duration(milliseconds: v.round()),
                            ),
                          )
                        : null,
                  ),
                  FilledButton.icon(
                    key: const Key('video-preview-play'),
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    label: Text(
                      value.isPlaying
                          ? tr(context, 'Pause', 'Tạm dừng')
                          : tr(context, 'Play', 'Phát'),
                    ),
                    onPressed: () => action(() async {
                      if (value.isPlaying) {
                        await controller!.pause();
                      } else {
                        if (value.position >= value.duration)
                          await controller!.seekTo(Duration.zero);
                        await controller!.play();
                      }
                    }),
                  ),
                ],
              );
            },
          ),
  );
}
