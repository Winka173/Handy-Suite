import 'package:handy_capture/handy_capture.dart';
import 'package:handy_ui/kit.dart';
import '../native_capture_page.dart';

/// Taking a screenshot on Windows: an area dragged out on a frozen copy of
/// the screen, or the whole screen under the pointer. No recording here.
class WindowsTakePanel extends StatelessWidget {
  final NativeCapturePageState page;
  const WindowsTakePanel({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    final p = page, theme = Theme.of(context);
    final idle = !p.busy && !p.pending;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.xs),
      child: Text(text, style: theme.textTheme.labelLarge),
    );
    final hint = p.area == CaptureArea.region
        ? tr(
            context,
            'Drag over what to capture · click for the whole screen · Esc cancels',
            'Kéo chọn vùng cần chụp · bấm để chụp cả màn hình · Esc để hủy',
          )
        : '';
    return HandyGroup(
      children: [
        Padding(
          padding: const EdgeInsets.all(HandySpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(
                  context,
                  'Handy Media steps aside, the screen holds still, and you drag over the part you want. Each screenshot becomes a step to mark up. Screen recording is not available on Windows.',
                  'Handy Media tạm ẩn, màn hình đứng yên và bạn kéo chọn phần cần lấy. Mỗi ảnh chụp thành một bước để chú thích. Windows chưa có quay màn hình.',
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: HandySpace.l),
              label(tr(context, 'What to take', 'Chụp phần nào')),
              SegmentedButton<CaptureArea>(
                key: const Key('native-area'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: CaptureArea.region,
                    icon: const Icon(Icons.crop_free),
                    label: Text(tr(context, 'An area', 'Một vùng')),
                  ),
                  ButtonSegment(
                    value: CaptureArea.screen,
                    icon: const Icon(Icons.desktop_windows_outlined),
                    label: Text(tr(context, 'Whole screen', 'Cả màn hình')),
                  ),
                ],
                selected: {p.area},
                onSelectionChanged: idle
                    ? (v) => p.update(() => p.area = v.single)
                    : null,
              ),
              const SizedBox(height: HandySpace.l),
              label(
                tr(
                  context,
                  'Wait first, to open a menu',
                  'Chờ trước, để kịp mở menu',
                ),
              ),
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
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const Key('native-screenshot'),
                  onPressed: idle
                      ? () => p.run(
                          () => p.result(
                            p.native.screenshot(
                              delayMs: p.delay,
                              area: p.area,
                              hint: hint,
                            ),
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.screenshot_monitor_outlined),
                  label: Text(
                    p.busy
                        ? tr(context, 'Capturing…', 'Đang chụp…')
                        : tr(context, 'Capture', 'Chụp'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
