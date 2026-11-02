import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import 'stamp_design.dart';

Future<void> openStampStudio(
  BuildContext context,
  TripScope scope,
  String visitId,
) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    settings: const RouteSettings(name: '/stamp'),
    builder: (_) => StampStudio(scope: scope, visitId: visitId),
  ),
);

/// The stamp workshop for one confirmed visit: cut a photo of it into a
/// stamp, ink it, set its words, then save it as a PNG or a sheet to print.
class StampStudio extends StatefulWidget {
  final TripScope scope;
  final String visitId;
  const StampStudio({super.key, required this.scope, required this.visitId});
  @override
  State<StampStudio> createState() => _StampStudioState();
}

class _StampStudioState extends State<StampStudio> {
  late final Json data = stampData(widget.scope.state, widget.visitId);
  late StampDesign design = StampDesign(
    place: data['place'] as String,
    day: data['day'] as String,
    seed: widget.visitId.hashCode,
  );
  late final place = TextEditingController(text: design.place);
  bool withTrip = false, busy = false;
  String? photoKey, error;

  /// The visit's own photos, then the trip's cover.
  late final List<MediaAsset> photos = () {
    final s = widget.scope.state;
    final v = s.visits.firstWhere((v) => v.key == widget.visitId);
    final keys = [...v.assets, if (v.trip != null) ?s.trip(v.trip!).cover];
    return [
      for (final k in keys.toSet())
        ...s.assets.where((a) => a.key == k && a.mime.startsWith('image/')),
    ];
  }();

  Uint8List? bytesOf(MediaAsset a, {bool full = false}) {
    final files = widget.scope.state.files;
    return full
        ? files[a.path] ?? files[a.data['preview']]
        : files[a.data['preview'] ?? a.path] ?? files[a.path];
  }

  @override
  void initState() {
    super.initState();
    if (photos.isNotEmpty) usePhoto(photos.first);
  }

  @override
  void dispose() {
    place.dispose();
    design.photo?.dispose();
    super.dispose();
  }

  Future<ui.Image?> decode(Uint8List? bytes) async {
    if (bytes == null) return null;
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1400);
    return (await codec.getNextFrame()).image;
  }

  Future<void> usePhoto(MediaAsset? a) async {
    try {
      final image = a == null ? null : await decode(bytesOf(a));
      if (!mounted) return;
      final old = design.photo;
      setState(() {
        photoKey = a?.key;
        design = design.copyWith(
          photo: image,
          noPhoto: image == null,
          zoom: 1,
          offset: Offset.zero,
        );
      });
      old?.dispose();
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    }
  }

  void nudge(Offset by) => setState(
    () => design = design.copyWith(
      offset: Offset(
        (design.offset.dx + by.dx).clamp(-1, 1),
        (design.offset.dy + by.dy).clamp(-1, 1),
      ),
    ),
  );

  Future<void> export({required bool sheet}) async {
    setState(() {
      busy = true;
      error = null;
    });
    ui.Image? full;
    try {
      final a = photos.where((p) => p.key == photoKey).firstOrNull;
      full = a == null ? null : await decode(bytesOf(a, full: true));
      final png = await renderStampPng(
        full == null ? design : design.copyWith(photo: full),
      );
      final bytes = sheet
          ? await stampSheetPdf(png, data['label'] as String)
          : png;
      final saved = await widget.scope.files.exportBytes(
        sheet ? 'handy-trip-stamp-sheet.pdf' : 'handy-trip-stamp.png',
        bytes,
        mimeType: sheet ? 'application/pdf' : 'image/png',
      );
      if (saved != null && mounted)
        showHandyMessage(
          context,
          sheet
              ? tr(context, 'Stamp sheet saved.', 'Đã lưu tờ tem.')
              : tr(context, 'Stamp saved.', 'Đã lưu tem.'),
        );
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    } finally {
      full?.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final preview = Focus(
      // Arrow keys move the photo, as dragging does.
      onKeyEvent: (_, e) {
        if (e is! KeyDownEvent && e is! KeyRepeatEvent)
          return KeyEventResult.ignored;
        final step = switch (e.logicalKey) {
          LogicalKeyboardKey.arrowLeft => const Offset(-.03, 0),
          LogicalKeyboardKey.arrowRight => const Offset(.03, 0),
          LogicalKeyboardKey.arrowUp => const Offset(0, -.03),
          LogicalKeyboardKey.arrowDown => const Offset(0, .03),
          _ => null,
        };
        if (step == null || design.photo == null) return KeyEventResult.ignored;
        nudge(step);
        return KeyEventResult.handled;
      },
      child: Semantics(
        label: tr(
          context,
          'Stamp preview: ${design.place}, ${design.day}',
          'Xem trước tem: ${design.place}, ${design.day}',
        ),
        image: true,
        child: GestureDetector(
          onPanUpdate: design.photo == null
              ? null
              : (e) => nudge(Offset(e.delta.dx / 300, e.delta.dy / 300)),
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              key: const Key('stamp-preview'),
              painter: StampPainter(design),
            ),
          ),
        ),
      ),
    );
    Widget label(String text) => HandyLabel(text);
    final controls = <Widget>[
      label(tr(context, 'Photo', 'Ảnh')),
      Wrap(
        spacing: HandySpace.s,
        runSpacing: HandySpace.s,
        children: [
          ChoiceChip(
            key: const Key('stamp-photo-none'),
            label: Text(tr(context, 'No photo', 'Không ảnh')),
            selected: photoKey == null,
            onSelected: (_) => usePhoto(null),
          ),
          for (final (i, a) in photos.indexed)
            ChoiceChip(
              key: Key('stamp-photo-${a.key}'),
              avatar: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(
                  bytesOf(a)!,
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  cacheWidth: 64,
                ),
              ),
              label: Text(tr(context, 'Photo ${i + 1}', 'Ảnh ${i + 1}')),
              selected: photoKey == a.key,
              onSelected: (_) => usePhoto(a),
            ),
        ],
      ),
      if (design.photo != null) ...[
        _Slider(
          label: tr(context, 'Zoom', 'Phóng to'),
          value: design.zoom,
          min: 1,
          max: 3,
          shown: '${design.zoom.toStringAsFixed(1)}×',
          onChanged: (v) => setState(() => design = design.copyWith(zoom: v)),
        ),
        Text(
          tr(
            context,
            'Drag the stamp, or use the arrow keys, to move the photo.',
            'Kéo trên tem, hoặc dùng phím mũi tên, để chỉnh vị trí ảnh.',
          ),
          style: theme.textTheme.bodySmall,
        ),
      ],
      label(tr(context, 'Shape', 'Hình tem')),
      SegmentedButton<String>(
        key: const Key('stamp-shape'),
        showSelectedIcon: false,
        segments: [
          for (final (id, en, vi) in [
            ('circle', 'Round', 'Tròn'),
            ('oval', 'Oval', 'Bầu dục'),
            ('postage', 'Postage', 'Răng cưa'),
            ('label', 'Label', 'Nhãn'),
          ])
            ButtonSegment(
              value: id,
              label: Text(tr(context, en, vi), maxLines: 1),
            ),
        ],
        selected: {design.shape},
        onSelectionChanged: (s) =>
            setState(() => design = design.copyWith(shape: s.first)),
      ),
      label(tr(context, 'Ink', 'Màu mực')),
      Wrap(
        spacing: HandySpace.s,
        children: [
          for (final (i, ink) in stampInks.indexed)
            Semantics(
              selected: design.ink == ink,
              button: true,
              label: [
                tr(context, 'Trip blue', 'Xanh Trip'),
                tr(context, 'Black', 'Đen'),
                tr(context, 'Red', 'Đỏ'),
                tr(context, 'Green', 'Xanh lá'),
                tr(context, 'Brown', 'Nâu'),
              ][i],
              child: InkWell(
                key: Key('stamp-ink-$i'),
                customBorder: const CircleBorder(),
                onTap: () => setState(() => design = design.copyWith(ink: ink)),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: design.ink == ink
                          ? theme.colorScheme.onSurface
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(radius: 14, backgroundColor: Color(ink)),
                ),
              ),
            ),
        ],
      ),
      label(tr(context, 'Words', 'Chữ trên tem')),
      TextField(
        key: const Key('stamp-place'),
        controller: place,
        maxLength: 60,
        decoration: InputDecoration(hintText: tr(context, 'Place', 'Địa điểm')),
        onChanged: (v) =>
            setState(() => design = design.copyWith(place: v.trim())),
      ),
      if ((data['trip'] as String).isNotEmpty)
        SwitchListTile(
          key: const Key('stamp-trip'),
          contentPadding: EdgeInsets.zero,
          title: Text(tr(context, 'Add the trip name', 'Kèm tên chuyến đi')),
          subtitle: Text(data['trip'] as String),
          value: withTrip,
          onChanged: (v) => setState(() {
            withTrip = v;
            design = design.copyWith(trip: v ? data['trip'] as String : '');
          }),
        ),
      _Slider(
        label: tr(context, 'Tilt', 'Độ nghiêng'),
        value: design.rotation,
        min: -12,
        max: 12,
        shown: '${design.rotation.round()}°',
        onChanged: (v) => setState(() => design = design.copyWith(rotation: v)),
      ),
      _Slider(
        label: tr(context, 'Worn ink', 'Độ mòn mực'),
        value: design.wear,
        min: 0,
        max: 1,
        shown: '${(design.wear * 100).round()}%',
        onChanged: (v) => setState(() => design = design.copyWith(wear: v)),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: HandySpace.m),
          child: HandyNotice(error!, tone: HandyTone.error),
        ),
      Padding(
        padding: const EdgeInsets.only(top: HandySpace.l),
        child: Text(
          tr(
            context,
            'A personal design, not an official stamp or proof of GPS. No exact position or photo metadata goes into it.',
            'Thiết kế cá nhân, không phải dấu chính thức hay bằng chứng GPS. Không chứa vị trí chính xác hay metadata ảnh.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
        ),
      ),
    ];
    return HandyPage(
      title: tr(context, 'Stamp workshop', 'Xưởng làm tem'),
      bottom: Wrap(
        spacing: HandySpace.s,
        runSpacing: HandySpace.s,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton(
            key: const Key('stamp-sheet'),
            onPressed: busy ? null : () => export(sheet: true),
            child: Text(tr(context, 'Print sheet (PDF)', 'Tờ in A4 (PDF)')),
          ),
          FilledButton(
            key: const Key('stamp-save'),
            onPressed: busy ? null : () => export(sheet: false),
            child: Text(tr(context, 'Save stamp (PNG)', 'Lưu tem (PNG)')),
          ),
        ],
      ),
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: preview),
              const SizedBox(width: HandySpace.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: controls,
                ),
              ),
            ],
          )
        else ...[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: preview,
            ),
          ),
          ...controls,
        ],
      ],
    );
  }
}

class _Slider extends StatelessWidget {
  final String label, shown;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.shown,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 112, child: Text(label)),
      Expanded(
        child: Slider(
          value: value,
          min: min,
          max: max,
          label: shown,
          semanticFormatterCallback: (_) => shown,
          onChanged: onChanged,
        ),
      ),
      SizedBox(
        width: 48,
        child: Text(
          shown,
          textAlign: TextAlign.end,
          style: const TextStyle(fontFeatures: tabular),
        ),
      ),
    ],
  );
}
