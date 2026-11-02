import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../study/anki_import.dart';
import 'anki_preview.dart';

/// Bringing an Anki deck in: choose the file, see everything that will come
/// in and what will not, choose about the schedule, then one Import. Opened
/// with [pickNow] from the deck list, it goes straight to the file picker
/// and closes again if the picker is cancelled.
class AnkiImportPage extends StatefulWidget {
  final RecallScope scope;
  final bool pickNow;
  const AnkiImportPage({super.key, required this.scope, this.pickNow = false});
  @override
  State<AnkiImportPage> createState() => _AnkiImportPageState();
}

class _AnkiImportPageState extends State<AnkiImportPage> {
  late final c = AnkiImportController(
    store: widget.scope.store,
    files: widget.scope.files,
  );

  @override
  void initState() {
    super.initState();
    if (widget.pickNow) {
      WidgetsBinding.instance.addPostFrameCallback((_) => choose(close: true));
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> choose({bool close = false}) async {
    final picked = await c.pick();
    if (!picked && close && mounted) Navigator.maybePop(context);
  }

  Future<void> commit() async {
    final decks = c.preview!.decks.length;
    try {
      final n = await c.commit();
      if (!mounted || n == 0) return;
      showHandyMessage(
        context,
        tr(
          context,
          'Added $n cards in $decks new decks.',
          'Đã thêm $n thẻ vào $decks bộ thẻ mới.',
        ),
      );
      Navigator.maybePop(context);
    } catch (e) {
      if (mounted) {
        showHandyMessage(
          context,
          tr(
            context,
            '${errorText(context, e)}. Nothing changed.',
            '${errorText(context, e)}. Không có gì thay đổi.',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final ready =
          c.stage == ImportStage.ready || c.stage == ImportStage.saving;
      final saving = c.stage == ImportStage.saving;
      final p = c.preview;
      return PopScope(
        canPop: !saving,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'Import from Anki', 'Nhập từ Anki')),
          ),
          bottomNavigationBar: !ready || p == null
              ? null
              : HandyBottomBar(
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('anki-other'),
                          onPressed: saving ? null : choose,
                          child: Text(
                            tr(context, 'Other file', 'File khác'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: HandySpace.m),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          key: const Key('anki-import'),
                          onPressed: saving || c.blocked != null
                              ? null
                              : commit,
                          child: Text(
                            tr(
                              context,
                              'Add ${p.cards.length} cards',
                              'Thêm ${p.cards.length} thẻ',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              HandySpace.l,
              HandySpace.l,
              HandySpace.l,
              HandySpace.xxl,
            ),
            children: [
              HandyContent(
                // The preview spreads to two columns on wide screens.
                maxWidth: p != null && ready
                    ? HandySpace.contentWide
                    : HandySpace.content,
                child: HandySwap(
                  child: switch (c.stage) {
                    ImportStage.reading => _Reading(
                      key: const ValueKey('reading'),
                      file: c.fileName,
                    ),
                    ImportStage.failed => HandyEmpty(
                      key: const ValueKey('failed'),
                      title: tr(context, 'Nothing was added', 'Chưa thêm gì'),
                      message: errorText(context, c.error!),
                      action: FilledButton(
                        key: const Key('anki-choose'),
                        onPressed: choose,
                        child: Text(
                          tr(context, 'Choose another file', 'Chọn file khác'),
                        ),
                      ),
                    ),
                    _ when p != null => AnkiPreview(
                      key: const ValueKey('preview'),
                      controller: c,
                      busy: saving,
                    ),
                    _ => HandyEmpty(
                      key: const ValueKey('choose'),
                      title: tr(
                        context,
                        'Bring in an Anki deck',
                        'Đưa bộ thẻ Anki vào',
                      ),
                      message: tr(
                        context,
                        'Choose an .apkg or .colpkg file. You see what comes in before anything is added.',
                        'Chọn file .apkg hoặc .colpkg. Bạn xem trước những gì sẽ được thêm.',
                      ),
                      action: FilledButton(
                        key: const Key('anki-choose'),
                        onPressed: choose,
                        child: Text(tr(context, 'Choose a file', 'Chọn file')),
                      ),
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The preview's frame while the file is read, so nothing jumps after.
class _Reading extends StatelessWidget {
  final String file;
  const _Reading({super.key, required this.file});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, 'Reading $file…', 'Đang đọc $file…'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: HandySpace.m),
        const LinearProgressIndicator(),
        const SizedBox(height: HandySpace.m),
        Text(
          tr(
            context,
            'Checking every card and picture. Nothing is added yet.',
            'Đang kiểm tra từng thẻ và ảnh. Chưa thêm gì.',
          ),
          style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
        ),
      ],
    );
  }
}
