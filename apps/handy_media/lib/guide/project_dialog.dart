import 'dart:typed_data';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';

const _kinds = [
  ('guide', 'How-to guide', 'Hướng dẫn'),
  ('bug', 'Bug report', 'Báo lỗi'),
  ('comparison', 'Comparison', 'So sánh'),
];

const _bugFields = [
  ('environment', 'Device and version', 'Thiết bị và phiên bản', 4000),
  ('expected', 'What should happen', 'Lẽ ra phải thế nào', 4000),
  ('actual', 'What happened', 'Thực tế thế nào', 4000),
  ('reproduction', 'Steps to make it happen', 'Các bước làm lại lỗi', 8000),
];

/// What kind of guide this is, its tags and, for a bug report, the
/// details a developer asks for. Null if canceled; a value that breaks a
/// limit keeps the dialog open and says which.
Future<CaptureProject?> editProjectDetails(
  BuildContext context,
  CaptureProject project,
) async {
  final tags = TextEditingController(text: project.tags.join('\n'));
  final initialTags = tags.text;
  final fields = {
    for (final e in project.bug.entries)
      e.key: TextEditingController(text: e.value),
  };
  var kind = project.kind, problem = '';
  try {
    final route = DialogRoute<CaptureProject>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(tr(context, 'About this guide', 'Thông tin hướng dẫn')),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    key: const Key('capture-project-kind'),
                    showSelectedIcon: false,
                    segments: [
                      for (final (id, en, vi) in _kinds)
                        ButtonSegment(
                          value: id,
                          label: Text(tr(context, en, vi)),
                        ),
                    ],
                    selected: {kind},
                    onSelectionChanged: (v) => update(() => kind = v.single),
                  ),
                  const SizedBox(height: HandySpace.l),
                  TextField(
                    key: const Key('capture-project-tags'),
                    controller: tags,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 1312,
                    decoration: InputDecoration(
                      labelText: tr(context, 'Tags', 'Thẻ'),
                      helperText: tr(
                        context,
                        'One per line, up to 32, each up to 40 letters',
                        'Mỗi dòng một thẻ, tối đa 32, mỗi thẻ tối đa 40 ký tự',
                      ),
                    ),
                  ),
                  if (kind == 'bug')
                    for (final (key, en, vi, max) in _bugFields)
                      Padding(
                        padding: const EdgeInsets.only(top: HandySpace.m),
                        child: TextField(
                          key: Key('capture-bug-$key'),
                          controller: fields[key],
                          minLines: 2,
                          maxLines: 5,
                          maxLength: max,
                          decoration: InputDecoration(
                            labelText: tr(context, en, vi),
                          ),
                        ),
                      ),
                  if (problem.isNotEmpty)
                    HandyNotice(problem, tone: HandyTone.error),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'Cancel', 'Hủy')),
            ),
            FilledButton(
              key: const Key('capture-project-details-apply'),
              onPressed: () {
                try {
                  Navigator.pop(
                    context,
                    project.copyWith(
                      kind: kind,
                      tags: tags.text == initialTags
                          ? project.tags
                          : tags.text
                                .split('\n')
                                .where((s) => s.isNotEmpty)
                                .toList(),
                      bug: {
                        for (final e in fields.entries) e.key: e.value.text,
                      },
                    ),
                  );
                } catch (_) {
                  update(
                    () => problem = tr(
                      context,
                      'Check tag limits (32 tags, 40 characters each) and field lengths.',
                      'Kiểm tra giới hạn thẻ (32 thẻ, mỗi thẻ 40 ký tự) và độ dài các trường.',
                    ),
                  );
                }
              },
              child: Text(tr(context, 'Apply', 'Áp dụng')),
            ),
          ],
        ),
      ),
    );
    final next = await Navigator.of(context).push(route);
    await route.completed;
    return next;
  } finally {
    tags.dispose();
    for (final f in fields.values) {
      f.dispose();
    }
  }
}

/// Shows the flattened picture before it is shared: what the other person
/// will see, masks painted in. True to share.
Future<bool> reviewPicture(BuildContext context, Uint8List png) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tr(context, 'Review flattened image', 'Kiểm tra ảnh đã gộp'),
        ),
        content: SizedBox(
          width: 420,
          height: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(
                  context,
                  'This is exactly what will be shared. Check that nothing private shows.',
                  'Đây đúng là ảnh sẽ được chia sẻ. Kiểm tra không có gì riêng tư lộ ra.',
                ),
              ),
              const SizedBox(height: HandySpace.m),
              Expanded(
                child: Image.memory(png, fit: BoxFit.contain, cacheWidth: 800),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Cancel', 'Hủy')),
          ),
          FilledButton(
            key: const Key('capture-share-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'Share', 'Chia sẻ')),
          ),
        ],
      ),
    ) ==
    true;
