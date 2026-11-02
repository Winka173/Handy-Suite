import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import '../ui/words.dart';
import 'asset_editor.dart';

/// What was paid and in which currency. Empty means no price; totals then
/// count the item as "without a price" instead of as zero.
class PriceField extends StatelessWidget {
  final AssetEditorState editor;
  const PriceField({super.key, required this.editor});
  @override
  Widget build(BuildContext context) {
    final e = editor;
    final codes = {...keepCurrencies, e.currency}.toList();
    return HandyField(
      label: tr(context, 'Price paid', 'Giá mua'),
      help: tr(
        context,
        'For insurance and moving totals. Leave empty if unknown.',
        'Dùng để cộng giá trị khi khai bảo hiểm hay chuyển nhà. Không nhớ thì để trống.',
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              key: const Key('item-price'),
              controller: e.price,
              enabled: !e.locked,
              maxLength: 20,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
              ],
              textInputAction: TextInputAction.next,
              onChanged: (_) => e.touch(() {}),
              style: const TextStyle(fontFeatures: tabular),
              decoration: InputDecoration(
                hintText: e.currency == 'VND' ? '4.500.000' : '129.90',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: HandySpace.s),
          SizedBox(
            width: 112,
            child: DropdownButtonFormField<String>(
              key: const Key('item-currency'),
              initialValue: e.currency,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: tr(context, 'Currency', 'Tiền tệ'),
              ),
              items: [
                for (final c in codes)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: e.locked
                  ? null
                  : (v) => e.touch(() => e.currency = v ?? e.currency),
            ),
          ),
        ],
      ),
    );
  }
}
