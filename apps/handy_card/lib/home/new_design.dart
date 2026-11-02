import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:handy_ui/kit.dart';
import '../editor/controls.dart';
import '../scope.dart';

/// What the person is making and at what size; returns a blank design.
Future<CardDocument?> showNewDesign(BuildContext context, CardScope scope) =>
    showDialog<CardDocument>(
      context: context,
      builder: (_) => _NewDesign(scope: scope),
    );

class _NewDesign extends StatefulWidget {
  final CardScope scope;
  const _NewDesign({required this.scope});
  @override
  State<_NewDesign> createState() => _NewDesignState();
}

class _NewDesignState extends State<_NewDesign> {
  String kind = 'business', size = 'vn', unit = 'mm';
  bool portrait = false;
  int sides = 2;
  double width = 90, height = 54;

  static const kinds = {
    'business': ('Business card', 'Danh thiếp'),
    'portfolio': ('Portfolio', 'Portfolio'),
    'social': ('Social card', 'Thẻ mạng xã hội'),
    'event': ('Event badge', 'Thẻ sự kiện'),
    'brand': ('Shop or brand', 'Cửa hàng, thương hiệu'),
    'invitation': ('Invitation', 'Thiệp mời'),
    'document': ('CV or one page', 'CV, một trang'),
    'custom': ('Anything else', 'Bất cứ gì khác'),
  };

  @override
  Widget build(BuildContext context) {
    final preset = cardSizes.where((s) => s.id == size).firstOrNull;
    return AlertDialog(
      title: Text(tr(context, 'New design', 'Thiết kế mới')),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(context, 'What is it?', 'Bạn làm gì?'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: HandySpace.s),
            Wrap(
              spacing: HandySpace.s,
              runSpacing: HandySpace.s,
              children: [
                for (final e in kinds.entries)
                  ChoiceChip(
                    key: Key('new-kind-${e.key}'),
                    label: Text(tr(context, e.value.$1, e.value.$2)),
                    selected: kind == e.key,
                    onSelected: (_) => setState(() {
                      kind = e.key;
                      size = switch (e.key) {
                        'social' => 'square',
                        'event' => 'badge',
                        'invitation' => 'a5',
                        'document' => 'a4',
                        _ =>
                          const {'square', 'badge', 'a5', 'a4'}.contains(size)
                              ? 'vn'
                              : size,
                      };
                      portrait = const {
                        'event',
                        'invitation',
                        'document',
                      }.contains(e.key);
                      sides = e.key == 'social' || e.key == 'document' ? 1 : 2;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: HandySpace.l),
            ChoiceField(
              label: tr(context, 'Size', 'Kích thước'),
              value: size,
              options: {
                for (final s in cardSizes) s.id: tr(context, s.en, s.vi),
                'custom': tr(context, 'Custom size', 'Kích thước riêng'),
              },
              onChanged: (v) => setState(() => size = v),
            ),
            if (size == 'custom') ...[
              ChoiceField(
                label: tr(context, 'Unit', 'Đơn vị'),
                value: unit,
                options: const {'mm': 'mm', 'in': 'in', 'px': 'px'},
                onChanged: (v) => setState(() => unit = v),
              ),
              FieldRow([
                NumberField(
                  label: 'W',
                  value: width,
                  unit: unit,
                  min: 1,
                  max: unit == 'px'
                      ? 8000
                      : unit == 'in'
                      ? 40
                      : 1000,
                  decimals: 2,
                  onChanged: (v) => setState(() => width = v),
                ),
                NumberField(
                  label: 'H',
                  value: height,
                  unit: unit,
                  min: 1,
                  max: unit == 'px'
                      ? 8000
                      : unit == 'in'
                      ? 40
                      : 1000,
                  decimals: 2,
                  onChanged: (v) => setState(() => height = v),
                ),
              ]),
            ],
            if (size != 'custom' && preset?.width != preset?.height)
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(tr(context, 'Landscape', 'Ngang')),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(tr(context, 'Portrait', 'Dọc')),
                  ),
                ],
                selected: {portrait},
                onSelectionChanged: (v) => setState(() => portrait = v.first),
              ),
            const SizedBox(height: HandySpace.s),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: 1,
                  label: Text(tr(context, 'One side', 'Một mặt')),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text(tr(context, 'Front and back', 'Hai mặt')),
                ),
              ],
              selected: {sides},
              onSelectionChanged: (v) => setState(() => sides = v.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Cancel', 'Hủy')),
        ),
        FilledButton(
          key: const Key('new-create'),
          onPressed: () {
            final s = size == 'custom'
                ? CardSize(
                    'custom',
                    'Custom',
                    'Riêng',
                    unit,
                    width,
                    height,
                    bleedMm: unit == 'px' ? 0 : 3,
                    safeMm: unit == 'px' ? 0 : 3,
                    print: unit != 'px',
                  )
                : preset!;
            final doc = blankDocument(
              size: s,
              portrait: portrait,
              sides: sides,
              kind: kind,
              at: widget.scope.library.clock(),
            );
            Navigator.pop(context, doc);
          },
          child: Text(tr(context, 'Create', 'Tạo')),
        ),
      ],
    );
  }
}
