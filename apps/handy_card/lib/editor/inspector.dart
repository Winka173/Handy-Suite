import 'dart:math' as math;
import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:handy_ui/kit.dart';
import 'controls.dart';
import 'studio_controller.dart';

typedef InspectorSection =
    List<Widget> Function(
      BuildContext context,
      StudioController c,
      CardElement e,
    );

/// Property panels by element type. Register one for a new element type;
/// the frame, opacity and layer settings above it are shared.
final inspectorSections = <String, InspectorSection>{
  'text': _textSection,
  'contact': _contactSection,
  'rect': (ctx, c, e) => [..._paintSection(ctx, c, e), _radius(ctx, c, e)],
  'ellipse': _paintSection,
  'polygon': (ctx, c, e) => [
    ..._paintSection(ctx, c, e),
    FieldRow([
      NumberField(
        label: tr(ctx, 'Sides', 'Cạnh'),
        value: e.prop<double>('sides', 6),
        min: 3,
        max: 24,
        decimals: 0,
        onChanged: (v) => c.setProps(
          {e.id},
          {'sides': v.roundToDouble()},
          coalesce: 'sides:${e.id}',
        ),
      ),
      NumberField(
        label: tr(ctx, 'Inner', 'Trong'),
        value: e.prop<double>('inner', 0.5),
        min: 0.1,
        max: 0.95,
        step: 0.05,
        decimals: 2,
        onChanged: (v) => c.setProps({e.id}, {'inner': v}),
      ),
    ]),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(tr(ctx, 'Star', 'Ngôi sao')),
      value: e.prop<bool>('star', false),
      onChanged: (v) => c.setProps({e.id}, {'star': v}),
    ),
  ],
  'line': (ctx, c, e) => [
    ColorField(
      label: tr(ctx, 'Colour', 'Màu'),
      value: e.prop<String?>('stroke', '111111'),
      allowNone: false,
      onChanged: (v) => c.setProps({e.id}, {'stroke': v}),
    ),
    FieldRow([
      NumberField(
        label: tr(ctx, 'Width', 'Dày'),
        value: e.prop<double>('strokeWidth', 1),
        min: 0.1,
        max: 200,
        step: 0.25,
        decimals: 2,
        unit: 'pt',
        onChanged: (v) => c.setProps({e.id}, {'strokeWidth': v}),
      ),
      NumberField(
        label: tr(ctx, 'Dash', 'Nét đứt'),
        value: e.prop<double>('dash', 0),
        min: 0,
        max: 100,
        decimals: 1,
        unit: 'pt',
        onChanged: (v) => c.setProps({e.id}, {'dash': v}),
      ),
    ]),
  ],
  'image': _imageSection,
  'icon': (ctx, c, e) => [
    ChoiceField(
      label: tr(ctx, 'Icon', 'Biểu tượng'),
      value: e.prop<String>('glyph', 'phone'),
      options: {for (final k in cardIcons.keys) k: k},
      onChanged: (v) => c.setProps({e.id}, {'glyph': v}),
    ),
    ColorField(
      label: tr(ctx, 'Colour', 'Màu'),
      value: e.prop<String?>('color', '111111'),
      allowNone: false,
      onChanged: (v) => c.setProps({e.id}, {'color': v}),
    ),
  ],
  'qr': _qrSection,
  'badge': (ctx, c, e) => [
    _TextProp(
      label: tr(ctx, 'Label', 'Nhãn'),
      value: e.prop<String>('label', ''),
      maxLength: 24,
      onChanged: (v) =>
          c.setProps({e.id}, {'label': v}, coalesce: 'label:${e.id}'),
    ),
    ColorField(
      label: tr(ctx, 'Fill', 'Nền'),
      value: e.prop<String?>('fill', 'C2410C'),
      onChanged: (v) => c.setProps({e.id}, {'fill': v}),
    ),
    ColorField(
      label: tr(ctx, 'Text colour', 'Màu chữ'),
      value: e.prop<String?>('ink', 'FFFFFF'),
      allowNone: false,
      onChanged: (v) => c.setProps({e.id}, {'ink': v}),
    ),
  ],
};

/// The inspector: the card when nothing is selected, one element's
/// properties, or what several can share.
class Inspector extends StatelessWidget {
  final StudioController c;
  final Future<void> Function(String? replace) pickPicture;
  const Inspector({super.key, required this.c, required this.pickPicture});

  @override
  Widget build(BuildContext context) {
    final ids = c.session.selected;
    final children = ids.isEmpty
        ? _cardSection(context, c)
        : ids.length == 1
        ? _elementSection(
            context,
            c,
            findElement(c.session.elements, ids.first)!,
            pickPicture,
          )
        : _manySection(context, c, ids);
    return ListView(
      key: const Key('inspector'),
      padding: const EdgeInsets.fromLTRB(
        HandySpace.l,
        HandySpace.s,
        HandySpace.l,
        HandySpace.xxl,
      ),
      children: children,
    );
  }
}

String _unitLabel(String unit) => unit == 'pt' ? 'pt' : unit;
double _toUnit(StudioController c, double pt) => fromPoints(pt, c.doc.unit);
double _fromUnit(StudioController c, double v) => toPoints(v, c.doc.unit);
double _step(StudioController c) => c.doc.unit == 'in'
    ? 0.01
    : c.doc.unit == 'mm'
    ? 0.5
    : 1;
int _decimals(StudioController c) => c.doc.unit == 'in'
    ? 3
    : c.doc.unit == 'mm'
    ? 2
    : 0;

List<Widget> _cardSection(BuildContext context, StudioController c) {
  final d = c.doc;
  final page = c.session.current;
  final u = _unitLabel(d.unit);
  return [
    HandyLabel(tr(context, 'Card', 'Thẻ')),
    _TextProp(
      label: tr(context, 'Name', 'Tên'),
      value: d.name,
      maxLength: 120,
      onChanged: (v) =>
          c.editDoc('Rename', (x) => x.copyWith(name: v), coalesce: 'name'),
    ),
    ChoiceField(
      label: tr(context, 'Unit', 'Đơn vị'),
      value: d.unit,
      options: const {'mm': 'mm', 'in': 'in', 'px': 'px', 'pt': 'pt'},
      onChanged: (v) => c.editDoc('Unit', (x) => x.copyWith(unit: v)),
    ),
    FieldRow([
      NumberField(
        key: ValueKey('w-${d.unit}'),
        label: 'W',
        value: _toUnit(c, d.width),
        unit: u,
        step: _step(c),
        decimals: _decimals(c),
        min: 1,
        onChanged: (v) => c.editDoc(
          'Card size',
          (x) => x.copyWith(width: snapValue(_fromUnit(c, v))),
        ),
      ),
      NumberField(
        key: ValueKey('h-${d.unit}'),
        label: 'H',
        value: _toUnit(c, d.height),
        unit: u,
        step: _step(c),
        decimals: _decimals(c),
        min: 1,
        onChanged: (v) => c.editDoc(
          'Card size',
          (x) => x.copyWith(height: snapValue(_fromUnit(c, v))),
        ),
      ),
    ]),
    FieldRow([
      NumberField(
        label: tr(context, 'Bleed', 'Tràn lề'),
        value: d.bleed / pointsPerMm,
        unit: 'mm',
        step: 0.5,
        decimals: 1,
        min: 0,
        max: 20,
        onChanged: (v) => c.editDoc(
          'Bleed',
          (x) => x.copyWith(bleed: snapValue(v * pointsPerMm)),
        ),
      ),
      NumberField(
        label: tr(context, 'Safe', 'An toàn'),
        value: d.safe / pointsPerMm,
        unit: 'mm',
        step: 0.5,
        decimals: 1,
        min: 0,
        max: 50,
        onChanged: (v) => c.editDoc(
          'Safe margin',
          (x) => x.copyWith(safe: snapValue(v * pointsPerMm)),
        ),
      ),
    ]),
    ColorField(
      label: tr(context, 'Background of this side', 'Nền của mặt này'),
      value: page.background,
      onChanged: (v) => c.editDoc(
        'Background',
        (x) => x.copyWith(
          pages: [
            for (final p in x.pages)
              p.id == page.id
                  ? p.copyWith(background: v, clearBackground: v == null)
                  : p,
          ],
        ),
      ),
    ),
    HandyLabel(tr(context, 'Profile', 'Hồ sơ')),
    ChoiceField(
      label: tr(context, 'Contact fields read from', 'Trường liên hệ lấy từ'),
      value: d.profileId ?? '',
      options: {
        '': tr(context, 'No profile', 'Không có hồ sơ'),
        for (final p in c.library.profiles.values)
          p.id: p.displayName.isEmpty ? p.organization : p.displayName,
      },
      onChanged: (v) => c.editDoc(
        'Profile',
        (x) => v.isEmpty
            ? x.copyWith(clearProfile: true)
            : x.copyWith(profileId: v),
      ),
    ),
    Text(
      tr(
        context,
        '${boundElements(d).length} elements follow the profile live.',
        '${boundElements(d).length} phần tử đang theo hồ sơ.',
      ),
      style: Theme.of(context).textTheme.bodySmall,
    ),
  ];
}

List<Widget> _frameFields(
  BuildContext context,
  StudioController c,
  CardElement e,
) {
  final f = e.frame, u = _unitLabel(c.doc.unit);
  void set(Frame next) => c.setFrameOf(e.id, next, coalesce: 'frame:${e.id}');
  final spec = c.registry.lookup(e.type);
  return [
    FieldRow([
      NumberField(
        key: ValueKey('x${e.id}'),
        label: 'X',
        value: _toUnit(c, f.x),
        unit: u,
        step: _step(c),
        decimals: _decimals(c),
        onChanged: (v) => set(f.copyWith(x: _fromUnit(c, v))),
      ),
      NumberField(
        key: ValueKey('y${e.id}'),
        label: 'Y',
        value: _toUnit(c, f.y),
        unit: u,
        step: _step(c),
        decimals: _decimals(c),
        onChanged: (v) => set(f.copyWith(y: _fromUnit(c, v))),
      ),
    ]),
    FieldRow([
      NumberField(
        key: ValueKey('w${e.id}'),
        label: 'W',
        value: _toUnit(c, f.width),
        unit: u,
        step: _step(c),
        decimals: _decimals(c),
        min: 0.01,
        onChanged: (v) {
          final w = _fromUnit(c, v);
          set(
            spec?.keepsAspect == true && f.width > 0
                ? f.copyWith(width: w, height: f.height * w / f.width)
                : f.copyWith(width: w),
          );
        },
      ),
      NumberField(
        key: ValueKey('h${e.id}'),
        label: 'H',
        value: _toUnit(c, f.height),
        unit: u,
        step: _step(c),
        decimals: _decimals(c),
        min: 0.01,
        onChanged: (v) {
          final h = _fromUnit(c, v);
          set(
            spec?.keepsAspect == true && f.height > 0
                ? f.copyWith(height: h, width: f.width * h / f.height)
                : f.copyWith(height: h),
          );
        },
      ),
      NumberField(
        key: ValueKey('r${e.id}'),
        label: tr(context, 'Turn', 'Xoay'),
        value: f.rotation,
        unit: '°',
        step: 1,
        decimals: 1,
        min: -360,
        max: 360,
        onChanged: (v) => set(f.copyWith(rotation: v)),
      ),
    ]),
    SliderRow(
      label: tr(context, 'Opacity', 'Độ đục'),
      shown: '${(e.opacity * 100).round()}%',
      value: e.opacity,
      min: 0,
      max: 1,
      onChanged: (v) => c.update(
        e.id,
        (x) => x.copyWith(opacity: (v * 100).roundToDouble() / 100),
        label: 'Opacity',
        coalesce: 'opacity:${e.id}',
      ),
    ),
  ];
}

List<Widget> _elementSection(
  BuildContext context,
  StudioController c,
  CardElement e,
  Future<void> Function(String?) pick,
) {
  final spec = c.registry.lookup(e.type);
  final title = spec == null
      ? tr(
          context,
          'Unsupported element "${e.type}"',
          'Phần tử chưa hỗ trợ "${e.type}"',
        )
      : tr(context, spec.en, spec.vi);
  return [
    HandyLabel(title),
    if (spec == null)
      Text(
        tr(
          context,
          'Made by a newer Handy Card. It is kept exactly as it came; you can move, hide or delete it.',
          'Do Handy Card mới hơn tạo. Phần tử được giữ nguyên; bạn vẫn di chuyển, ẩn hoặc xóa được.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    _TextProp(
      label: tr(context, 'Layer name', 'Tên lớp'),
      value: e.name,
      maxLength: 120,
      onChanged: (v) => c.update(
        e.id,
        (x) => x.copyWith(name: v),
        label: 'Rename',
        coalesce: 'name:${e.id}',
      ),
    ),
    ..._frameFields(context, c, e),
    if (inspectorSections[e.type] case final section?) ...[
      const Divider(height: HandySpace.xl),
      ...section(context, c, e),
    ],
    if (e.type == 'image') ...[
      const SizedBox(height: HandySpace.s),
      OutlinedButton.icon(
        key: const Key('inspector-replace-picture'),
        onPressed: () => pick(e.id),
        icon: const Icon(Icons.image_outlined),
        label: Text(
          e.prop<String?>('asset', null) == null
              ? tr(context, 'Choose picture', 'Chọn ảnh')
              : tr(context, 'Replace picture', 'Thay ảnh'),
        ),
      ),
    ],
    if (e.isGroup)
      FilledButton.tonal(
        onPressed: c.ungroupSelection,
        child: Text(tr(context, 'Ungroup', 'Bỏ nhóm')),
      ),
  ];
}

List<Widget> _manySection(
  BuildContext context,
  StudioController c,
  Set<String> ids,
) => [
  HandyLabel(tr(context, '${ids.length} selected', 'Đã chọn ${ids.length}')),
  Wrap(
    spacing: HandySpace.xs,
    children: [
      for (final (a, icon, en, vi) in [
        (CardAlign.left, Icons.align_horizontal_left, 'Align left', 'Căn trái'),
        (
          CardAlign.centerX,
          Icons.align_horizontal_center,
          'Align centres',
          'Căn giữa dọc',
        ),
        (
          CardAlign.right,
          Icons.align_horizontal_right,
          'Align right',
          'Căn phải',
        ),
        (CardAlign.top, Icons.align_vertical_top, 'Align top', 'Căn trên'),
        (
          CardAlign.centerY,
          Icons.align_vertical_center,
          'Align middles',
          'Căn giữa ngang',
        ),
        (
          CardAlign.bottom,
          Icons.align_vertical_bottom,
          'Align bottom',
          'Căn dưới',
        ),
      ])
        IconButton(
          tooltip: tr(context, en, vi),
          icon: Icon(icon),
          onPressed: () => c.align(a),
        ),
    ],
  ),
  if (ids.length >= 3)
    Wrap(
      spacing: HandySpace.s,
      children: [
        OutlinedButton(
          onPressed: () =>
              c.edit('Distribute', (l) => distribute(l, ids, horizontal: true)),
          child: Text(tr(context, 'Space across', 'Giãn đều ngang')),
        ),
        OutlinedButton(
          onPressed: () => c.edit(
            'Distribute',
            (l) => distribute(l, ids, horizontal: false),
          ),
          child: Text(tr(context, 'Space down', 'Giãn đều dọc')),
        ),
      ],
    ),
  const SizedBox(height: HandySpace.s),
  FilledButton.tonal(
    key: const Key('inspector-group'),
    onPressed: c.group,
    child: Text(tr(context, 'Group', 'Nhóm lại')),
  ),
];

List<Widget> _textStyle(
  BuildContext context,
  StudioController c,
  CardElement e,
) => [
  ChoiceField(
    label: tr(context, 'Face', 'Kiểu chữ'),
    value: e.prop<String>('font', 'sans'),
    options: {
      'sans': 'Hanken Grotesk',
      'serif': 'Literata',
      'display': 'Bricolage Grotesque',
      'mono': 'Geist Mono',
    },
    onChanged: (v) => c.setProps({e.id}, {'font': v}),
  ),
  FieldRow([
    NumberField(
      label: tr(context, 'Size', 'Cỡ'),
      value: e.prop<double>('size', 12),
      min: 2,
      max: 400,
      step: 0.5,
      decimals: 1,
      unit: 'pt',
      onChanged: (v) =>
          c.setProps({e.id}, {'size': v}, coalesce: 'size:${e.id}'),
    ),
    ChoiceField(
      label: tr(context, 'Weight', 'Độ đậm'),
      value: '${e.prop<double>('weight', 400).round()}',
      options: const {
        '400': 'Regular',
        '500': 'Medium',
        '600': 'Semibold',
        '700': 'Bold',
      },
      onChanged: (v) => c.setProps({e.id}, {'weight': double.parse(v)}),
    ),
  ]),
  SegmentedButton<String>(
    showSelectedIcon: false,
    segments: const [
      ButtonSegment(value: 'left', icon: Icon(Icons.format_align_left)),
      ButtonSegment(value: 'center', icon: Icon(Icons.format_align_center)),
      ButtonSegment(value: 'right', icon: Icon(Icons.format_align_right)),
    ],
    selected: {e.prop<String>('align', 'left')},
    onSelectionChanged: (v) => c.setProps({e.id}, {'align': v.first}),
  ),
  const SizedBox(height: HandySpace.s),
  ColorField(
    label: tr(context, 'Colour', 'Màu'),
    value: e.prop<String?>('color', '111111'),
    allowNone: false,
    onChanged: (v) => c.setProps({e.id}, {'color': v}),
  ),
  FieldRow([
    NumberField(
      label: tr(context, 'Line', 'Dòng'),
      value: e.prop<double>('lineHeight', 1.25),
      min: 0.8,
      max: 3,
      step: 0.05,
      decimals: 2,
      onChanged: (v) => c.setProps({e.id}, {'lineHeight': v}),
    ),
    NumberField(
      label: tr(context, 'Track', 'Giãn'),
      value: e.prop<double>('letterSpacing', 0),
      min: -5,
      max: 50,
      step: 0.1,
      decimals: 1,
      onChanged: (v) => c.setProps({e.id}, {'letterSpacing': v}),
    ),
  ]),
  ChoiceField(
    label: tr(context, 'When it does not fit', 'Khi chữ không vừa'),
    value: e.prop<String>('overflow', 'shrink'),
    options: {
      'shrink': tr(context, 'Shrink to fit', 'Thu nhỏ cho vừa'),
      'clip': tr(context, 'Cut off', 'Cắt bớt'),
      'visible': tr(context, 'Let it run over', 'Để tràn ra'),
    },
    onChanged: (v) => c.setProps({e.id}, {'overflow': v}),
  ),
  SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(tr(context, 'Capitals', 'Viết hoa')),
    value: e.prop<bool>('upper', false),
    onChanged: (v) => c.setProps({e.id}, {'upper': v}),
  ),
  SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(tr(context, 'Italic', 'Nghiêng')),
    value: e.prop<bool>('italic', false),
    onChanged: (v) => c.setProps({e.id}, {'italic': v}),
  ),
  if (layoutText(e, displayText(e, c.profile), c.measurer).overflow)
    HandyNotice(
      tr(context, 'The text does not fit its box.', 'Chữ không vừa khung.'),
      tone: HandyTone.warning,
    ),
];

List<Widget> _textSection(
  BuildContext context,
  StudioController c,
  CardElement e,
) => [
  _TextProp(
    key: ValueKey('text-${e.id}'),
    label: tr(context, 'Text', 'Nội dung'),
    value: e.prop<String>('text', ''),
    maxLines: 6,
    maxLength: cardTextLimit,
    onChanged: (v) => c.setProps(
      {e.id},
      {'text': v},
      label: 'Edit text',
      coalesce: 'text:${e.id}',
    ),
  ),
  _bindingSection(context, c, e),
  ..._textStyle(context, c, e),
];

List<Widget> _contactSection(
  BuildContext context,
  StudioController c,
  CardElement e,
) => [
  _bindingSection(context, c, e),
  _TextProp(
    label: tr(context, 'Before the value', 'Trước giá trị'),
    value: e.prop<String>('prefix', ''),
    maxLength: 40,
    onChanged: (v) =>
        c.setProps({e.id}, {'prefix': v}, coalesce: 'prefix:${e.id}'),
  ),
  _TextProp(
    label: tr(
      context,
      'Shown when the profile has none',
      'Hiện khi hồ sơ trống',
    ),
    value: e.prop<String>('text', ''),
    maxLength: 500,
    onChanged: (v) => c.setProps({e.id}, {'text': v}, coalesce: 'text:${e.id}'),
  ),
  ..._textStyle(context, c, e),
];

/// Linking an element to a profile field: live (follows the profile),
/// snapshot (keeps today's text), or none.
Widget _bindingSection(
  BuildContext context,
  StudioController c,
  CardElement e,
) {
  final b = e.binding;
  final value = e.type == 'qr'
      ? qrPayload(e, c.profile)
      : displayText(e, c.profile);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ChoiceField(
        label: tr(context, 'Profile field', 'Trường hồ sơ'),
        value: b?.field.split(':').first ?? '',
        options: {
          '': tr(context, 'Not linked', 'Không liên kết'),
          for (final f in bindableFields.entries)
            if (e.type == 'qr' || !const {'vcard', 'url'}.contains(f.key))
              f.key: tr(context, f.value.$1, f.value.$2),
        },
        onChanged: (v) => c.bind(e.id, v.isEmpty ? null : ElementBinding(v)),
      ),
      if (b != null) ...[
        Text(
          b.mode == 'live'
              ? (c.profile == null
                    ? tr(
                        context,
                        'Pick a profile for this design (nothing selected → Profile).',
                        'Chọn hồ sơ cho thiết kế (bỏ chọn → Hồ sơ).',
                      )
                    : tr(context, 'Shows: $value', 'Đang hiện: $value'))
              : tr(
                  context,
                  'Unlinked: keeps "$value" when the profile changes.',
                  'Đã tách: giữ "$value" khi hồ sơ đổi.',
                ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: b.mode == 'live'
              ? TextButton(
                  key: const Key('inspector-unlink'),
                  onPressed: () => c.unlink(e.id),
                  child: Text(
                    tr(
                      context,
                      'Unlink and keep this text',
                      'Tách và giữ chữ này',
                    ),
                  ),
                )
              : TextButton(
                  onPressed: () => c.bind(e.id, ElementBinding(b.field)),
                  child: Text(
                    tr(context, 'Follow the profile again', 'Theo hồ sơ lại'),
                  ),
                ),
        ),
      ],
      const SizedBox(height: HandySpace.s),
    ],
  );
}

List<Widget> _paintSection(
  BuildContext context,
  StudioController c,
  CardElement e,
) => [
  ColorField(
    label: tr(context, 'Fill', 'Màu nền'),
    value: e.prop<String?>('fill', null),
    onChanged: (v) => c.setProps({e.id}, {'fill': v}),
  ),
  if (e.prop<String?>('fill', null) != null) ...[
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        tr(context, 'Blend into a second colour', 'Chuyển sang màu thứ hai'),
      ),
      value: e.prop<String?>('fill2', null) != null,
      onChanged: (v) => c.setProps({e.id}, {'fill2': v ? 'FFFFFF' : null}),
    ),
    if (e.prop<String?>('fill2', null) != null) ...[
      ColorField(
        label: tr(context, 'Second colour', 'Màu thứ hai'),
        value: e.prop<String?>('fill2', null),
        allowNone: false,
        onChanged: (v) => c.setProps({e.id}, {'fill2': v}),
      ),
      NumberField(
        label: tr(context, 'Angle', 'Góc'),
        value: e.prop<double>('angle', 90),
        unit: '°',
        min: -360,
        max: 360,
        decimals: 0,
        onChanged: (v) => c.setProps({e.id}, {'angle': v}),
      ),
    ],
  ],
  ColorField(
    label: tr(context, 'Outline', 'Viền'),
    value: e.prop<String?>('stroke', null),
    onChanged: (v) => c.setProps({e.id}, {'stroke': v}),
  ),
  if (e.prop<String?>('stroke', null) != null)
    NumberField(
      label: tr(context, 'Outline width', 'Độ dày viền'),
      value: e.prop<double>('strokeWidth', 1),
      unit: 'pt',
      min: 0,
      max: 200,
      step: 0.25,
      decimals: 2,
      onChanged: (v) => c.setProps({e.id}, {'strokeWidth': v}),
    ),
];

Widget _radius(BuildContext context, StudioController c, CardElement e) =>
    NumberField(
      label: tr(context, 'Corners', 'Bo góc'),
      value: e.prop<double>('radius', 0),
      unit: 'pt',
      min: 0,
      max: 1000,
      decimals: 1,
      onChanged: (v) => c.setProps({e.id}, {'radius': v}),
    );

List<Widget> _imageSection(
  BuildContext context,
  StudioController c,
  CardElement e,
) => [
  SegmentedButton<String>(
    showSelectedIcon: false,
    segments: [
      ButtonSegment(value: 'cover', label: Text(tr(context, 'Fill', 'Phủ'))),
      ButtonSegment(value: 'contain', label: Text(tr(context, 'Fit', 'Vừa'))),
      ButtonSegment(
        value: 'fill',
        label: Text(tr(context, 'Stretch', 'Kéo giãn')),
      ),
    ],
    selected: {e.prop<String>('fit', 'cover')},
    onSelectionChanged: (v) => c.setProps({e.id}, {'fit': v.first}),
  ),
  const SizedBox(height: HandySpace.s),
  SegmentedButton<String>(
    showSelectedIcon: false,
    segments: [
      ButtonSegment(value: 'none', label: Text(tr(context, 'Square', 'Vuông'))),
      ButtonSegment(
        value: 'rounded',
        label: Text(tr(context, 'Rounded', 'Bo góc')),
      ),
      ButtonSegment(
        value: 'ellipse',
        label: Text(tr(context, 'Circle', 'Tròn')),
      ),
    ],
    selected: {e.prop<String>('mask', 'none')},
    onSelectionChanged: (v) => c.setProps({e.id}, {'mask': v.first}),
  ),
  if (e.prop<String>('mask', 'none') == 'rounded') _radius(context, c, e),
  HandyLabel(tr(context, 'Crop', 'Cắt ảnh')),
  for (final (k, en, vi) in [
    ('cropX', 'Left', 'Trái'),
    ('cropY', 'Top', 'Trên'),
    ('cropW', 'Width', 'Rộng'),
    ('cropH', 'Height', 'Cao'),
  ])
    SliderRow(
      label: tr(context, en, vi),
      shown:
          '${(e.prop<double>(k, k.endsWith('W') || k.endsWith('H') ? 1 : 0) * 100).round()}%',
      value: e.prop<double>(k, k.endsWith('W') || k.endsWith('H') ? 1 : 0),
      min: k.endsWith('W') || k.endsWith('H') ? 0.05 : 0,
      max: k.endsWith('W') || k.endsWith('H') ? 1 : 0.95,
      onChanged: (v) {
        // The crop window stays inside the picture.
        final x = k == 'cropX' ? v : e.prop<double>('cropX', 0);
        final y = k == 'cropY' ? v : e.prop<double>('cropY', 0);
        final w = math.min(
          k == 'cropW' ? v : e.prop<double>('cropW', 1),
          1 - x,
        );
        final h = math.min(
          k == 'cropH' ? v : e.prop<double>('cropH', 1),
          1 - y,
        );
        c.setProps(
          {e.id},
          {
            'cropX': x,
            'cropY': y,
            'cropW': math.max(0.05, w),
            'cropH': math.max(0.05, h),
          },
          label: 'Crop',
          coalesce: 'crop:${e.id}',
        );
      },
    ),
];

List<Widget> _qrSection(
  BuildContext context,
  StudioController c,
  CardElement e,
) {
  final payload = qrPayload(e, c.profile);
  String? warning;
  try {
    final side = math.min(e.frame.width, e.frame.height);
    warning = qrPrintCheck(
      payload,
      sidePoints: side,
      ecc: e.prop<String>('ecc', 'M'),
      quiet: e.prop<double>('quiet', 4).round(),
    ).warning;
  } on FormatException catch (err) {
    warning = err.message;
  }
  return [
    _bindingSection(context, c, e),
    if (e.binding == null || e.binding!.mode == 'snapshot')
      _TextProp(
        label: tr(
          context,
          'Content (link, text, phone…)',
          'Nội dung (liên kết, chữ, số…)',
        ),
        value: e.prop<String>('payload', ''),
        maxLines: 4,
        maxLength: 2900,
        onChanged: (v) =>
            c.setProps({e.id}, {'payload': v}, coalesce: 'payload:${e.id}'),
      ),
    SegmentedButton<String>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 'L', label: Text('L')),
        ButtonSegment(value: 'M', label: Text('M')),
        ButtonSegment(value: 'Q', label: Text('Q')),
        ButtonSegment(value: 'H', label: Text('H')),
      ],
      selected: {e.prop<String>('ecc', 'M')},
      onSelectionChanged: (v) => c.setProps({e.id}, {'ecc': v.first}),
    ),
    Text(
      tr(
        context,
        'Error correction: H survives the most damage but needs a larger code.',
        'Sửa lỗi: H chịu hỏng nhiều nhất nhưng cần mã lớn hơn.',
      ),
      style: Theme.of(context).textTheme.bodySmall,
    ),
    const SizedBox(height: HandySpace.s),
    ColorField(
      label: tr(context, 'Modules', 'Điểm mã'),
      value: e.prop<String?>('color', '000000'),
      allowNone: false,
      onChanged: (v) => c.setProps({e.id}, {'color': v}),
    ),
    ColorField(
      label: tr(context, 'Background', 'Nền'),
      value: e.prop<String?>('background', 'FFFFFF'),
      onChanged: (v) => c.setProps({e.id}, {'background': v}),
    ),
    NumberField(
      label: tr(context, 'Quiet zone', 'Lề trống'),
      value: e.prop<double>('quiet', 4),
      min: 0,
      max: 8,
      decimals: 0,
      unit: tr(context, 'modules', 'ô'),
      onChanged: (v) => c.setProps({e.id}, {'quiet': v.roundToDouble()}),
    ),
    if (warning != null) HandyNotice(warning, tone: HandyTone.warning),
  ];
}

/// Free text that applies as it is typed (coalesced into one undo step).
class _TextProp extends StatefulWidget {
  final String label, value;
  final int maxLines, maxLength;
  final ValueChanged<String> onChanged;
  const _TextProp({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    this.maxLength = 200,
  });
  @override
  State<_TextProp> createState() => _TextPropState();
}

class _TextPropState extends State<_TextProp> {
  late final text = TextEditingController(text: widget.value);
  final focus = FocusNode();
  @override
  void didUpdateWidget(_TextProp old) {
    super.didUpdateWidget(old);
    if (!focus.hasFocus && widget.value != text.text) text.text = widget.value;
  }

  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: HandySpace.s),
    child: TextField(
      controller: text,
      focusNode: focus,
      maxLines: widget.maxLines,
      minLines: 1,
      maxLength: widget.maxLength,
      decoration: InputDecoration(
        labelText: widget.label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        counterText: '',
      ),
      onChanged: widget.onChanged,
    ),
  );
}
