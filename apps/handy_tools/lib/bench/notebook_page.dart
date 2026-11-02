import 'dart:async';
import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:handy_ui/kit.dart';
import 'bench_page.dart';

Future<void> openNotebook(BuildContext context, BenchScope scope) =>
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/notebook'),
        builder: (_) => NotebookPage(scope: scope),
      ),
    );

const _line = 28.0, _pad = 12.0;
const _strut = StrutStyle(
  fontSize: 16,
  height: _line / 16,
  forceStrutHeight: true,
);

/// The calc notebook: a sum on each line with its answer beside it, lines
/// that name a figure and use it further down, totals of the lines above.
/// Kept as a draft, like a tool's typed input.
class NotebookPage extends StatefulWidget {
  final BenchScope scope;
  const NotebookPage({super.key, required this.scope});
  @override
  State<NotebookPage> createState() => _NotebookPageState();
}

class _NotebookPageState extends State<NotebookPage> {
  late final text = TextEditingController(
    text: widget.scope.read().drafts['notebook'] ?? '',
  );
  Timer? saving;

  @override
  void dispose() {
    saving?.cancel();
    save();
    text.dispose();
    super.dispose();
  }

  Future<void> save() {
    final p = widget.scope.read();
    if ((p.drafts['notebook'] ?? '') == text.text) return Future.value();
    return widget.scope.save(
      p.copyWith(drafts: {...p.drafts, 'notebook': text.text}),
    );
  }

  void changed(String _) {
    setState(() {});
    saving?.cancel();
    saving = Timer(const Duration(milliseconds: 500), save);
  }

  List<NotebookLine> results() {
    try {
      return evaluateNotebook(text.text);
    } on FormatException catch (e) {
      return [NotebookLine(error: e.message)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final lines = results();
    final narrow = MediaQuery.sizeOf(context).width < 480;
    final answers = Container(
      width: narrow ? 128 : 168,
      padding: const EdgeInsets.symmetric(vertical: _pad),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: c.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, l) in lines.indexed)
            SizedBox(
              height: _line,
              child: l.value == null
                  ? (l.error == null
                        ? null
                        : Tooltip(
                            message: errorText(
                              context,
                              FormatException(l.error!),
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: _pad),
                                child: Text(
                                  '?',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: c.muted,
                                  ),
                                ),
                              ),
                            ),
                          ))
                  : InkWell(
                      key: Key('notebook-answer-$i'),
                      onTap: () => copyToClipboard(context, l.value!),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: _pad),
                          child: Text(
                            formatFigure(context, l.shown!),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            strutStyle: _strut,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontFeatures: tabular,
                              fontWeight: l.total ? FontWeight.w600 : null,
                              // The total is the sheet's answer: the hue
                              // marks it, nothing else.
                              color: l.total ? c.accent : null,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
    return HandyPage(
      title: tr(context, 'Calc notebook', 'Sổ tính'),
      actions: [
        IconButton(
          key: const Key('notebook-copy'),
          tooltip: tr(context, 'Copy with answers', 'Sao chép kèm kết quả'),
          icon: const Icon(Icons.copy_outlined),
          onPressed: text.text.trim().isEmpty
              ? null
              : () => copyToClipboard(
                  context,
                  [
                    for (final (i, line) in text.text.split('\n').indexed)
                      i < lines.length && lines[i].value != null
                          ? '$line = ${lines[i].value}'
                          : line,
                  ].join('\n'),
                ),
        ),
        IconButton(
          key: const Key('notebook-clear'),
          tooltip: tr(context, 'Clear the sheet', 'Xóa trang'),
          icon: const Icon(Icons.delete_outline),
          onPressed: text.text.isEmpty
              ? null
              : () async {
                  if (await confirmHandy(
                        context,
                        title: tr(
                          context,
                          'Clear the sheet?',
                          'Xóa trang tính?',
                        ),
                        message: tr(
                          context,
                          'Every line on it goes.',
                          'Mọi dòng trên trang sẽ bị xóa.',
                        ),
                        confirmLabel: tr(context, 'Clear', 'Xóa'),
                        destructive: true,
                      ) &&
                      mounted) {
                    text.clear();
                    changed('');
                  }
                },
        ),
      ],
      children: [
        Card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('notebook-text'),
                  controller: text,
                  autofocus: text.text.isEmpty,
                  minLines: 12,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  onChanged: changed,
                  strutStyle: _strut,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.all(_pad),
                    hintMaxLines: 6,
                    hintText: tr(
                      context,
                      'Rent: 5m\nPower 1,200,000\nLunch 22 x 35k\ntotal\nsaving = ans * 10%',
                      'Tiền nhà: 5tr\nĐiện 1.200.000\nĂn trưa 22 x 35k\ntổng\ntiết kiệm = ans * 10%',
                    ),
                  ),
                ),
              ),
              ExcludeSemantics(child: answers),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: HandySpace.s),
          child: Text(
            tr(
              context,
              'Words are labels. "Name: figure" names a line to use below; "ans" is the line above; "total" adds the lines above it, up to a blank line. Tap an answer to copy it.',
              'Chữ là nhãn. "Tên: số" đặt tên để dùng ở dòng dưới; "ans" là dòng ngay trên; "tổng" cộng các dòng phía trên tới dòng trống. Chạm vào kết quả để sao chép.',
            ),
            style: theme.textTheme.bodySmall,
          ),
        ),
        // Screen readers get every answer in order, beside its line.
        Semantics(
          label: [
            for (final (i, line) in text.text.split('\n').indexed)
              if (i < lines.length && lines[i].value != null)
                '$line: ${lines[i].value}',
          ].join('; '),
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }
}
