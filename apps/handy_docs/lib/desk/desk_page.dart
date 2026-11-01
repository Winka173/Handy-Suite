import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/paper.dart';
import 'start_grid.dart';
import 'work_card.dart';

/// The desk: what is half done, as papers on it, and the four ways to start
/// something new. The question it answers: "what was I doing, and how do I
/// begin?"
class DeskPage extends StatelessWidget {
  final DocsScope scope;
  const DeskPage({super.key, required this.scope});

  void go(BuildContext context, String place) =>
      Navigator.pushNamed(context, '/$place');

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('docs-desk'),
    appBar: const HandyTopBar(
      mark: Icons.description_outlined,
      name: 'Handy Docs',
    ),
    body: ListenableBuilder(
      listenable: Listenable.merge([
        scope.scan,
        scope.draft,
        scope.draft.source,
        scope.pdf,
        scope.reader.store,
      ]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final work = _work(context);
        final recent = scope.reader.store.recent.take(3).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            HandySpace.l,
            HandySpace.l,
            HandySpace.xxl,
          ),
          children: [
            HandyContent(
              maxWidth: HandySpace.contentWide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      work.isEmpty
                          ? tr(context, 'Nothing on the desk', 'Bàn đang trống')
                          : tr(context, 'On the desk', 'Đang làm dở'),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: HandySpace.s),
                  HandySwap(
                    child: work.isEmpty
                        ? Text(
                            key: const ValueKey('empty'),
                            tr(
                              context,
                              'Scans, drafts and open PDFs wait here until you finish them.',
                              'Bản quét, bản nháp và PDF đang mở sẽ nằm đây tới khi bạn làm xong.',
                            ),
                            style: theme.textTheme.bodyMedium,
                          )
                        : Wrap(
                            key: ValueKey(work.length),
                            spacing: HandySpace.s,
                            runSpacing: HandySpace.s,
                            children: work,
                          ),
                  ),
                  const SizedBox(height: HandySpace.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      tr(context, 'Start something', 'Bắt đầu việc mới'),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: HandySpace.m),
                  StartGrid(
                    camera: scope.scan.camera.supported,
                    onStart: (id) => go(context, id),
                  ),
                  if (recent.isNotEmpty) ...[
                    const SizedBox(height: HandySpace.xl),
                    HandySection(
                      title: tr(context, 'Read lately', 'Đọc gần đây'),
                      children: [
                        for (final d in recent)
                          HandyTile(
                            key: Key('desk-recent-${d.id}'),
                            icon: Icons.description_outlined,
                            title: d.name,
                            subtitle: d.folder.isEmpty ? null : d.folder,
                            navigates: true,
                            onTap: () async {
                              final ok = await scope.reader.open(context, d);
                              if (ok && context.mounted) go(context, 'read');
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  List<Widget> _work(BuildContext context) {
    const sheet = 120.0;
    final scan = scope.scan, draft = scope.draft, pdf = scope.pdf;
    final reading = scope.reader.store;
    return [
      if (scan.pages.isNotEmpty)
        WorkCard(
          key: const Key('desk-work-scan'),
          papers: PaperStack(
            width: sheet,
            count: scan.pages.length,
            top: Paper(width: sheet, image: scan.pages.first.png),
          ),
          title: tr(context, 'Scan', 'Bản quét'),
          detail: tr(
            context,
            '${scan.pages.length} pages · make the PDF',
            '${scan.pages.length} trang · xuất PDF',
          ),
          onOpen: () => go(context, 'scan'),
        ),
      if (draft.loaded && draft.source.text.trim().isNotEmpty)
        WorkCard(
          key: const Key('desk-work-write'),
          papers: Paper(width: sheet, text: draft.opening),
          title: tr(context, 'Markdown draft', 'Bản nháp Markdown'),
          detail: tr(
            context,
            '${formatFigure(context, '${draft.words}')} words · ${draft.dirty ? 'not saved' : 'saved'}',
            '${formatFigure(context, '${draft.words}')} chữ · ${draft.dirty ? 'chưa lưu' : 'đã lưu'}',
          ),
          onOpen: () => go(context, 'write'),
        ),
      if (pdf.inputs.isNotEmpty)
        WorkCard(
          key: const Key('desk-work-pdf'),
          papers: PaperStack(
            width: sheet,
            count: pdf.inputs.length,
            top: Paper(width: sheet, image: pdf.preview, fit: BoxFit.contain),
          ),
          title: tr(
            context,
            '${pdf.inputs.length} PDF open',
            '${pdf.inputs.length} PDF đang mở',
          ),
          detail: pdf.inputs.first.name,
          onOpen: () => go(context, 'pdf'),
        ),
      if (reading.current != null && !reading.saved)
        WorkCard(
          key: const Key('desk-work-read'),
          papers: Paper(
            width: sheet,
            text: reading.current!.source.length > 400
                ? reading.current!.source.substring(0, 400)
                : reading.current!.source,
          ),
          title: reading.current!.name,
          detail: tr(context, 'Open, not saved', 'Đang mở, chưa lưu'),
          onOpen: () => go(context, 'read'),
        ),
    ];
  }
}
