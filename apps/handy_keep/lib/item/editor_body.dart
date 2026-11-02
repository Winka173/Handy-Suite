import 'package:handy_ui/kit.dart';
import 'asset_editor.dart';
import 'fields.dart';
import 'media_section.dart';
import 'price_field.dart';

/// The editor's layout: what it is and where it lives first, then the
/// photo and receipts, the dates, and the details nobody needs every day.
class EditorBody extends StatelessWidget {
  final AssetEditorState editor;
  const EditorBody({super.key, required this.editor});

  @override
  Widget build(BuildContext context) {
    final e = editor;
    final w = e.widget;
    final boxes = w.boxes;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('item-close'),
          tooltip: tr(context, 'Close', 'Đóng'),
          icon: const Icon(Icons.close),
          onPressed: e.locked ? null : e.askToLeave,
        ),
        title: Text(
          w.asset == null
              ? tr(context, 'New item', 'Thêm đồ')
              : tr(context, 'Edit item', 'Sửa đồ'),
        ),
      ),
      bottomNavigationBar: HandyBottomBar(
        child: FilledButton(
          key: const Key('item-save'),
          onPressed: e.locked ? null : e.save,
          child: Text(tr(context, 'Save item', 'Lưu đồ dùng')),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(HandySpace.l),
        children: [
          HandyContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (e.saving) const LinearProgressIndicator(),
                HandyField(
                  label: tr(context, 'What is it?', 'Món gì?'),
                  child: TextField(
                    key: const Key('item-name'),
                    controller: e.name,
                    enabled: !e.locked,
                    autofocus: w.asset == null,
                    maxLength: 200,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => e.touch(() {}),
                    decoration: const InputDecoration(counterText: ''),
                  ),
                ),
                const SizedBox(height: HandySpace.l),
                HandyField(
                  label: tr(context, 'Where is it kept?', 'Cất ở đâu?'),
                  child: LocationField(
                    controller: e.location,
                    known: w.locations,
                    enabled: !e.locked,
                    onChanged: () => e.touch(() {}),
                  ),
                ),
                if (boxes.isNotEmpty) ...[
                  const SizedBox(height: HandySpace.l),
                  HandyField(
                    label: tr(context, 'Packed in a box', 'Đóng trong thùng'),
                    child: DropdownButtonFormField<String>(
                      key: const Key('item-box'),
                      initialValue: e.boxId,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(
                            tr(context, 'No box', 'Không trong thùng'),
                          ),
                        ),
                        for (final b in boxes)
                          DropdownMenuItem(value: b.id, child: Text(b.name)),
                      ],
                      onChanged: e.locked
                          ? null
                          : (v) => e.touch(() => e.boxId = v ?? ''),
                    ),
                  ),
                ],
                MediaSection(editor: e),
                HandyLabel(tr(context, 'Dates', 'Ngày')),
                HandyGroup(
                  children: [
                    for (final (id, en, vi) in const [
                      ('purchasedOn', 'Bought on', 'Ngày mua'),
                      ('warrantyUntil', 'Warranty until', 'Bảo hành đến'),
                      ('maintenanceDue', 'Next service', 'Bảo dưỡng lần tới'),
                    ])
                      DateRow(
                        id: id,
                        label: tr(context, en, vi),
                        value: e.dates[id]!,
                        enabled: !e.locked,
                        onChanged: (v) => e.touch(() => e.dates[id] = v),
                      ),
                  ],
                ),
                const SizedBox(height: HandySpace.xl),
                PriceField(editor: e),
                HandyField(
                  label: tr(context, 'Serial number', 'Số serial'),
                  child: TextField(
                    key: const Key('item-serial'),
                    controller: e.serial,
                    enabled: !e.locked,
                    maxLength: 200,
                    onChanged: (_) => e.touch(() {}),
                    decoration: const InputDecoration(counterText: ''),
                  ),
                ),
                const SizedBox(height: HandySpace.l),
                HandyField(
                  label: tr(context, 'Notes', 'Ghi chú'),
                  child: TextField(
                    key: const Key('item-notes'),
                    controller: e.notes,
                    enabled: !e.locked,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: 10000,
                    onChanged: (_) => e.touch(() {}),
                    decoration: const InputDecoration(counterText: ''),
                  ),
                ),
                HandyReveal(
                  child: e.error.isEmpty
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: HandySpace.l),
                          child: HandyNotice(e.error, tone: HandyTone.error),
                        ),
                ),
                const SizedBox(height: HandySpace.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
