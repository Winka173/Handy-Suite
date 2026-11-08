import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../pro/pro.dart';
import '../scope.dart';

bool isVi(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'vi';

/// Starts a new board: a blank one in two taps, or the template gallery.
Future<void> newBoard(BuildContext context, BoardsScope scope) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheet) {
        final theme = Theme.of(sheet);
        final p = BoardsPalette.of(sheet);
        Widget option(
          Key key,
          IconData icon,
          String title,
          String line,
          VoidCallback onTap,
        ) => Material(
          color: p.raised,
          borderRadius: BorderRadius.circular(BoardsRadii.tile),
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(BoardsRadii.tile),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: p.ink),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          line,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: p.muted),
                ],
              ),
            ),
          ),
        );
        // Scrolls on a short screen (a phone on its side, large text).
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    tr(sheet, 'New board', 'Bảng mới'),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                option(
                  const Key('new-template'),
                  Icons.dashboard_customize_outlined,
                  tr(sheet, 'From a template', 'Từ mẫu có sẵn'),
                  tr(
                    sheet,
                    '30 ready boards for study, work, home and plans. A few '
                        'questions and it is yours.',
                    '30 bảng dựng sẵn cho học tập, công việc, nhà cửa, kế '
                        'hoạch. Trả lời vài câu là xong.',
                  ),
                  () {
                    Navigator.pop(sheet);
                    Navigator.pushNamed(context, '/templates');
                  },
                ),
                const SizedBox(height: 10),
                option(
                  const Key('new-blank'),
                  Icons.view_week_outlined,
                  tr(sheet, 'Blank board', 'Bảng trống'),
                  tr(
                    sheet,
                    'To Do, Doing, Done. Change anything later.',
                    'Cần làm, Đang làm, Xong. Đổi được mọi thứ sau.',
                  ),
                  () {
                    Navigator.pop(sheet);
                    createBlank(context, scope);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

/// The fastest path: a name, the three column names if the person wants
/// others, Create.
Future<void> createBlank(BuildContext context, BoardsScope scope) async {
  final vi = isVi(context);
  final plan = await showModalBottomSheet<BoardPlan>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _BlankSheet(vi: vi),
  );
  if (plan == null || !context.mounted) return;
  await createPlan(context, scope, plan);
}

class _BlankSheet extends StatefulWidget {
  final bool vi;
  const _BlankSheet({required this.vi});
  @override
  State<_BlankSheet> createState() => _BlankSheetState();
}

class _BlankSheetState extends State<_BlankSheet> {
  late final title = TextEditingController(
    text: widget.vi ? 'Bảng của tôi' : 'My board',
  );
  late final columns = [
    for (final c
        in widget.vi
            ? const ['Cần làm', 'Đang làm', 'Xong']
            : const ['To Do', 'Doing', 'Done'])
      TextEditingController(text: c),
  ];
  bool showColumns = false;

  @override
  void dispose() {
    title.dispose();
    for (final c in columns) c.dispose();
    super.dispose();
  }

  void _create() {
    final name = title.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      blankPlan(
        title: name,
        vi: widget.vi,
        columns: [for (final c in columns) c.text],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, 'Blank board', 'Bảng trống'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('blank-title'),
            controller: title,
            autofocus: true,
            maxLength: 80,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _create(),
            decoration: InputDecoration(
              labelText: tr(context, 'Board name', 'Tên bảng'),
            ),
          ),
          if (!showColumns)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('blank-columns'),
                onPressed: () => setState(() => showColumns = true),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(tr(context, 'Rename the columns', 'Đổi tên cột')),
              ),
            )
          else ...[
            Text(
              tr(
                context,
                'The last column is where finished cards go.',
                'Cột cuối là nơi thẻ đã xong nằm.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
            ),
            for (final (i, c) in columns.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  key: Key('blank-column-$i'),
                  controller: c,
                  maxLength: 40,
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: tr(context, 'Column ${i + 1}', 'Cột ${i + 1}'),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('blank-create'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _create,
            child: Text(tr(context, 'Create board', 'Tạo bảng')),
          ),
        ],
      ),
    );
  }
}

bool _creating = false;

/// Makes the board of [plan] in one guarded edit and opens it. A second
/// tap while it is being made does nothing; a failure leaves no half board.
/// Pro templates ask for Pro here, never before.
Future<void> createPlan(
  BuildContext context,
  BoardsScope scope,
  BoardPlan plan, {
  bool pro = false,
}) async {
  if (_creating) return;
  if (pro && !await requirePro(context, ProFeature.templates)) return;
  if (!context.mounted) return;
  _creating = true;
  final id = newId();
  try {
    await scope.run(
      context,
      () => scope.controller.change(
        (s) => buildBoard(s, plan, now: scope.clock(), boardId: id),
      ),
    );
  } finally {
    _creating = false;
  }
  if (!context.mounted || scope.controller.state?.maybe('boards', id) == null)
    return;
  Navigator.of(context).popUntil((r) => r.isFirst);
  await Navigator.pushNamed(context, '/board/$id');
}
