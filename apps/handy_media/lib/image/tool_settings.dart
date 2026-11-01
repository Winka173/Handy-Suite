import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import 'image_desk.dart';

/// The settings of the fix in hand, each with its limit beside it.
class ToolSettings extends StatelessWidget {
  final ImageDesk d;
  final bool busy;
  final VoidCallback onLogo;
  const ToolSettings({
    super.key,
    required this.d,
    required this.busy,
    required this.onLogo,
  });

  Widget _slider(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int? divisions,
  }) => Row(
    children: [
      SizedBox(
        width: 120,
        child: Text(
          '$label ${(value * (max > 1 ? 1 : 100)).round()}${max > 1 ? '' : '%'}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      Expanded(
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          semanticFormatterCallback: (v) =>
              '${(v * (max > 1 ? 1 : 100)).round()}${max > 1 ? '' : '%'}',
          onChanged: busy ? null : (v) => d.set(() => onChanged(v)),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final gap = const SizedBox(height: HandySpace.m);
    final widthField = TextField(
      key: const Key('media-output-width'),
      controller: d.size,
      enabled: !busy,
      keyboardType: TextInputType.number,
      onChanged: (_) => d.set(() {}),
      decoration: InputDecoration(
        labelText: tr(context, 'Width in pixels', 'Chiều rộng (pixel)'),
        helperText: d.tool == 'convert'
            ? tr(
                context,
                'Blank keeps each picture’s size; height follows',
                'Để trống để giữ cỡ từng ảnh; chiều cao tự theo',
              )
            : tr(
                context,
                'Now ${d.width} × ${d.height}; height follows',
                'Hiện ${d.width} × ${d.height}; chiều cao tự theo',
              ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (d.tool) {
        'crop' => [
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final (label, ratio) in [
                ('1:1', 1.0),
                ('4:3', 4 / 3),
                ('16:9', 16 / 9),
                ('9:16', 9 / 16),
              ])
                ActionChip(
                  key: Key('crop-preset-$label'),
                  label: Text(label),
                  onPressed: busy
                      ? null
                      : () => d.set(
                          () => d.region = cropAspectPreset(
                            d.width,
                            d.height,
                            ratio,
                          ),
                        ),
                ),
            ],
          ),
          gap,
          Text(
            tr(
              context,
              'Drag the frame on the picture, or a corner to resize it.',
              'Kéo khung trên ảnh, hoặc kéo góc để đổi cỡ.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        'resize' => [widthField],
        'convert' => [
          SegmentedButton<String>(
            key: const Key('media-convert-format'),
            showSelectedIcon: false,
            segments: [
              for (final f in ['jpeg', 'png', 'webp'])
                ButtonSegment(value: f, label: Text(f.toUpperCase())),
            ],
            selected: {d.format},
            onSelectionChanged: busy
                ? null
                : (v) => d.set(() => d.format = v.single),
          ),
          gap,
          widthField,
          gap,
          Text(
            tr(context, 'Turn', 'Xoay'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: HandySpace.xs),
          SegmentedButton<int>(
            key: const Key('media-convert-rotation'),
            showSelectedIcon: false,
            segments: [
              for (final a in [0, 90, 180, 270])
                ButtonSegment(value: a, label: Text('$a°')),
            ],
            selected: {d.rotation},
            onSelectionChanged: busy
                ? null
                : (v) => d.set(() => d.rotation = v.single),
          ),
          SwitchListTile(
            key: const Key('media-convert-flip-horizontal'),
            contentPadding: EdgeInsets.zero,
            title: Text(tr(context, 'Mirror left to right', 'Lật ngang')),
            value: d.flipX,
            onChanged: busy ? null : (v) => d.set(() => d.flipX = v),
          ),
          SwitchListTile(
            key: const Key('media-convert-flip-vertical'),
            contentPadding: EdgeInsets.zero,
            title: Text(tr(context, 'Mirror top to bottom', 'Lật dọc')),
            value: d.flipY,
            onChanged: busy ? null : (v) => d.set(() => d.flipY = v),
          ),
          if (d.format != 'png')
            _slider(
              context,
              tr(context, 'Quality', 'Chất lượng'),
              d.quality,
              1,
              100,
              (v) => d.quality = v,
            ),
          Text(
            tr(
              context,
              'JPEG puts see-through areas on white. WebP output is up to 4 million pixels.',
              'JPEG đặt vùng trong suốt lên nền trắng. WebP xuất tối đa 4 triệu pixel.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        'watermark' => [
          SegmentedButton<bool>(
            key: const Key('watermark-kind'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: false,
                label: Text(tr(context, 'Words', 'Chữ')),
              ),
              ButtonSegment(
                value: true,
                label: Text(tr(context, 'Logo', 'Logo')),
              ),
            ],
            selected: {d.useLogo},
            onSelectionChanged: busy
                ? null
                : (v) => d.set(() => d.useLogo = v.single),
          ),
          gap,
          if (!d.useLogo)
            TextField(
              key: const Key('watermark-text'),
              controller: d.words,
              enabled: !busy,
              maxLength: 100,
              onChanged: (_) => d.set(() {}),
              decoration: InputDecoration(
                labelText: tr(context, 'Words to stamp', 'Chữ đóng dấu'),
              ),
            )
          else
            OutlinedButton.icon(
              key: const Key('watermark-logo'),
              onPressed: busy ? null : onLogo,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                d.logo == null
                    ? tr(context, 'Choose a PNG logo', 'Chọn logo PNG')
                    : tr(context, 'Change the logo', 'Đổi logo'),
              ),
            ),
          gap,
          Text(
            tr(context, 'Where', 'Vị trí'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: HandySpace.xs),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final (p, en, vi) in const [
                ('top-left', 'Top left', 'Trên trái'),
                ('top-right', 'Top right', 'Trên phải'),
                ('center', 'Middle', 'Giữa'),
                ('bottom-left', 'Bottom left', 'Dưới trái'),
                ('bottom-right', 'Bottom right', 'Dưới phải'),
              ])
                ChoiceChip(
                  key: Key('watermark-$p'),
                  label: Text(tr(context, en, vi)),
                  selected: d.position == p,
                  onSelected: busy ? null : (_) => d.set(() => d.position = p),
                ),
            ],
          ),
          gap,
          _slider(
            context,
            tr(context, 'Strength', 'Độ đậm'),
            d.opacity,
            .1,
            1,
            (v) => d.opacity = v,
            divisions: 9,
          ),
          _slider(
            context,
            tr(context, 'Width', 'Độ rộng'),
            d.scale,
            .05,
            .9,
            (v) => d.scale = v,
          ),
        ],
        _ => [_Metadata(d: d)],
      },
    );
  }
}

class _Metadata extends StatelessWidget {
  final ImageDesk d;
  const _Metadata({required this.d});
  @override
  Widget build(BuildContext context) {
    final m = d.metadata, theme = Theme.of(context);
    if (m == null) {
      return HandyNotice(
        tr(
          context,
          'Location and camera details can be read and removed from PNG and JPEG. Convert a WebP picture first.',
          'Vị trí và thông tin máy ảnh đọc và xóa được ở PNG và JPEG. Hãy đổi ảnh WebP sang định dạng đó trước.',
        ),
      );
    }
    final where = m.latitude != null || m.longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyNotice(
          where
              ? tr(
                  context,
                  'This picture says where it was taken: ${m.latitude?.toStringAsFixed(5) ?? '?'}, ${m.longitude?.toStringAsFixed(5) ?? '?'}.',
                  'Ảnh này ghi nơi chụp: ${m.latitude?.toStringAsFixed(5) ?? '?'}, ${m.longitude?.toStringAsFixed(5) ?? '?'}.',
                )
              : tr(
                  context,
                  'No location found in this picture.',
                  'Không thấy vị trí trong ảnh này.',
                ),
          tone: where ? HandyTone.warning : HandyTone.info,
        ),
        const SizedBox(height: HandySpace.s),
        Text(
          '${m.format} · ${m.width} × ${m.height} · ${m.sections.isEmpty ? tr(context, 'no details stored', 'không lưu thông tin') : m.sections.join(', ')}',
          key: const Key('media-metadata-summary'),
          style: theme.textTheme.bodyMedium,
        ),
        for (final w in m.warnings)
          Text(
            tr(context, 'Unreadable part: $w', 'Phần không đọc được: $w'),
            style: theme.textTheme.bodySmall,
          ),
        for (final t in m.tags.entries.take(12))
          Text('${t.key}: ${t.value}', style: theme.textTheme.bodySmall),
        const SizedBox(height: HandySpace.s),
        Text(
          tr(
            context,
            'Removing details from a JPEG also removes its turn flag; check the result.',
            'Xóa thông tin ở JPEG cũng bỏ cờ xoay của ảnh; hãy xem lại kết quả.',
          ),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
