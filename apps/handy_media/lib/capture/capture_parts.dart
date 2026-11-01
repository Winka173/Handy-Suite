import 'package:handy_ui/kit.dart';
import '../native_capture_page.dart';
import '../video_preview.dart';

export 'video_tools.dart';

/// Taking a screenshot or a recording. On iPhone only this app can be
/// recorded, for up to 60 seconds.
class TakePanel extends StatelessWidget {
  final NativeCapturePageState page;
  const TakePanel({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    final p = page, theme = Theme.of(context);
    final idle = !p.busy && !p.pending;
    return HandyGroup(
      children: [
        Padding(
          padding: const EdgeInsets.all(HandySpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                p.appOnlyRecording
                    ? tr(
                        context,
                        'Record what happens in this app, up to 60 seconds, saved at 720p. For other apps, use the iPhone screenshot buttons or Control Center, then add the picture to a guide.',
                        'Quay những gì diễn ra trong app này, tối đa 60 giây, lưu ở 720p. Với app khác, dùng nút chụp màn hình của iPhone hoặc Trung tâm điều khiển rồi thêm ảnh vào hướng dẫn.',
                      )
                    : tr(
                        context,
                        'Android asks each time before the screen is captured. Recordings have no sound.',
                        'Android hỏi mỗi lần trước khi chụp màn hình. Video quay không có tiếng.',
                      ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: HandySpace.l),
              if (!p.appOnlyRecording) ...[
                Text(
                  tr(
                    context,
                    'Wait before the screenshot',
                    'Chờ trước khi chụp',
                  ),
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: HandySpace.xs),
                Wrap(
                  spacing: HandySpace.s,
                  children: [
                    for (final ms in [0, 3000, 5000, 10000])
                      ChoiceChip(
                        key: Key('native-delay-$ms'),
                        label: Text(
                          ms == 0
                              ? tr(context, 'None', 'Không')
                              : '${ms ~/ 1000} s',
                        ),
                        selected: p.delay == ms,
                        onSelected: idle
                            ? (_) => p.update(() => p.delay = ms)
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: HandySpace.l),
              ],
              Wrap(
                spacing: HandySpace.s,
                runSpacing: HandySpace.s,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (!p.appOnlyRecording)
                    FilledButton.icon(
                      key: const Key('native-screenshot'),
                      onPressed: !idle || p.recording
                          ? null
                          : () => p.run(
                              () => p.result(
                                p.native.screenshot(delayMs: p.delay),
                              ),
                            ),
                      icon: const Icon(Icons.screenshot_outlined),
                      label: Text(tr(context, 'Screenshot', 'Chụp ảnh')),
                    ),
                  if (p.recording) ...[
                    FilledButton.icon(
                      key: const Key('native-stop'),
                      onPressed: p.busy
                          ? null
                          : () =>
                                p.run(() => p.result(p.native.stopRecording())),
                      icon: const Icon(Icons.stop),
                      label: Text(tr(context, 'Stop and keep', 'Dừng và giữ')),
                    ),
                    TextButton(
                      key: const Key('native-cancel'),
                      onPressed: () async {
                        p.operation?.cancel();
                        await p.native.cancel();
                        await p.refresh();
                      },
                      child: Text(tr(context, 'Cancel', 'Hủy')),
                    ),
                  ] else
                    OutlinedButton.icon(
                      key: const Key('native-record'),
                      onPressed: idle
                          ? () => p.run(p.native.startRecording)
                          : null,
                      icon: const Icon(Icons.fiber_manual_record_outlined),
                      label: Text(
                        p.appOnlyRecording
                            ? tr(context, 'Record this app', 'Quay app này')
                            : tr(context, 'Record screen', 'Quay màn hình'),
                      ),
                    ),
                  if (p.recording || p.pending)
                    Text(
                      key: const Key('native-status'),
                      p.pending
                          ? tr(
                              context,
                              'Waiting for the system…',
                              'Đang chờ hệ thống…',
                            )
                          : p.appOnlyRecording
                          ? tr(
                              context,
                              'Recording this app · app sound on, microphone off',
                              'Đang quay app này · có tiếng app, tắt micrô',
                            )
                          : tr(
                              context,
                              'Recording · no sound',
                              'Đang quay · không có tiếng',
                            ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
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

/// The capture just made: what it is, and marking it up, playing it or
/// saving a copy.
class LastCapture extends StatelessWidget {
  final NativeCapturePageState page;
  const LastCapture({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    final p = page, last = p.last!, c = HandyColors.of(context);
    final image = last.mime == 'image/png';
    final idle = !p.busy && !p.pending;
    final seconds = ((last.durationMs ?? 0) / 1000).toStringAsFixed(1);
    return HandyGroup(
      color: c.select,
      children: [
        Padding(
          padding: const EdgeInsets.all(HandySpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                [
                  image
                      ? tr(context, 'Screenshot', 'Ảnh chụp')
                      : tr(context, 'Video', 'Video'),
                  '${last.width} × ${last.height}',
                  if (!image) '$seconds s',
                  if (last.actualStartMs != null)
                    tr(
                      context,
                      'starts at ${last.actualStartMs} ms',
                      'bắt đầu ở ${last.actualStartMs} ms',
                    ),
                ].join(' · '),
                key: const Key('native-result'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: c.selectInk),
              ),
              const SizedBox(height: HandySpace.m),
              Wrap(
                spacing: HandySpace.s,
                runSpacing: HandySpace.s,
                children: [
                  if (image)
                    FilledButton.icon(
                      key: const Key('native-annotate'),
                      onPressed: idle ? p.annotate : null,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(tr(context, 'Mark it up', 'Chú thích ảnh')),
                    )
                  else
                    FilledButton.icon(
                      key: const Key('native-video-preview'),
                      onPressed: idle && !p.recording
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    CaptureVideoPreview(capture: last),
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(tr(context, 'Play', 'Phát')),
                    ),
                  OutlinedButton.icon(
                    key: const Key('native-export'),
                    onPressed: idle ? p.export : null,
                    icon: const Icon(Icons.save_alt),
                    label: Text(tr(context, 'Save a copy', 'Lưu một bản')),
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
