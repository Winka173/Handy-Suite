import 'package:handy_ui/kit.dart';
import '../native_capture_page.dart';

/// Making a new copy of the video: turned or smaller, a part of it, one
/// frame as a picture, or several clips as one. The clip itself is never
/// changed. MP4 up to 5 minutes and 30 MB.
class VideoTools extends StatelessWidget {
  final NativeCapturePageState page;
  const VideoTools({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    final p = page, theme = Theme.of(context);
    final idle = !p.busy && !p.pending && !p.recording;
    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: HandySpace.l, bottom: HandySpace.s),
      child: Text(text, style: theme.textTheme.titleSmall),
    );
    Widget ms(Key key, TextEditingController c, String label) => TextField(
      key: key,
      controller: c,
      enabled: idle,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, suffixText: 'ms'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            tr(context, 'Make a new copy', 'Tạo bản mới'),
            style: theme.textTheme.titleLarge,
          ),
        ),
        Text(
          tr(
            context,
            'The clip stays as it is. Up to 5 minutes and 30 MB.',
            'Video gốc giữ nguyên. Tối đa 5 phút và 30 MB.',
          ),
          style: theme.textTheme.bodySmall,
        ),
        title(tr(context, 'Turn or shrink', 'Xoay hoặc thu nhỏ')),
        SegmentedButton<int>(
          key: const Key('video-transform-rotation'),
          showSelectedIcon: false,
          segments: [
            for (final a in [0, 90, 180, 270])
              ButtonSegment(value: a, label: Text('$a°')),
          ],
          selected: {p.videoRotation},
          onSelectionChanged: idle
              ? (v) => p.update(() => p.videoRotation = v.single)
              : null,
        ),
        const SizedBox(height: HandySpace.s),
        Wrap(
          key: const Key('video-transform-edge'),
          spacing: HandySpace.s,
          children: [
            for (final edge in [240, 480, 720, 1280])
              ChoiceChip(
                label: Text('$edge px'),
                selected: p.videoEdge == edge,
                onSelected: idle
                    ? (_) => p.update(() => p.videoEdge = edge)
                    : null,
              ),
          ],
        ),
        SwitchListTile(
          key: const Key('video-transform-mute'),
          contentPadding: EdgeInsets.zero,
          title: Text(tr(context, 'Remove the sound', 'Bỏ âm thanh')),
          value: p.videoMute,
          onChanged: idle ? (v) => p.update(() => p.videoMute = v) : null,
        ),
        OutlinedButton(
          key: const Key('video-transform-run'),
          onPressed: idle
              ? () => p.run(
                  () => p.result(
                    p.native.transform(
                      p.last!,
                      rotation: p.videoRotation,
                      maxEdge: p.videoEdge,
                      mute: p.videoMute,
                    ),
                  ),
                )
              : null,
          child: Text(tr(context, 'Make the copy', 'Tạo bản sao')),
        ),
        title(tr(context, 'Keep a part', 'Giữ một đoạn')),
        Row(
          children: [
            Expanded(
              child: ms(
                const Key('video-start'),
                p.start,
                tr(context, 'From', 'Từ'),
              ),
            ),
            const SizedBox(width: HandySpace.s),
            Expanded(
              child: ms(
                const Key('video-end'),
                p.end,
                tr(context, 'To', 'Đến'),
              ),
            ),
          ],
        ),
        const SizedBox(height: HandySpace.s),
        OutlinedButton(
          key: const Key('video-trim'),
          onPressed: idle
              ? () => p.run(
                  () => p.result(
                    p.native.trim(p.last!, p.millis(p.start), p.millis(p.end)),
                  ),
                )
              : null,
          child: Text(tr(context, 'Cut this part', 'Cắt đoạn này')),
        ),
        title(
          tr(context, 'One frame as a picture', 'Một khung hình thành ảnh'),
        ),
        ms(const Key('video-frame-time'), p.frame, tr(context, 'At', 'Tại')),
        const SizedBox(height: HandySpace.s),
        OutlinedButton(
          key: const Key('video-frame'),
          onPressed: idle
              ? () => p.run(
                  () => p.result(p.native.frame(p.last!, p.millis(p.frame))),
                )
              : null,
          child: Text(tr(context, 'Take the frame', 'Lấy khung hình')),
        ),
        if (p.clips.length > 1) ...[
          title(
            tr(
              context,
              'Join ${p.clips.length} clips in this order',
              'Ghép ${p.clips.length} video theo thứ tự này',
            ),
          ),
          for (final (i, clip) in p.clips.indexed)
            HandyTile(
              key: Key('video-clip-$i'),
              icon: Icons.movie_outlined,
              title: '${i + 1}. ${clip.width} × ${clip.height}',
              subtitle:
                  '${((clip.durationMs ?? 0) / 1000).toStringAsFixed(1)} s',
              onTap: idle ? () => p.update(() => p.accept(clip)) : null,
              trailing: IconButton(
                tooltip: tr(context, 'Leave out', 'Bỏ ra'),
                onPressed: idle
                    ? () => p.update(() => p.clips.removeAt(i))
                    : null,
                icon: const Icon(Icons.close),
              ),
            ),
          OutlinedButton(
            key: const Key('video-combine'),
            onPressed: idle
                ? () =>
                      p.run(() => p.result(p.native.combine(List.of(p.clips))))
                : null,
            child: Text(tr(context, 'Join them', 'Ghép lại')),
          ),
        ],
      ],
    );
  }
}
