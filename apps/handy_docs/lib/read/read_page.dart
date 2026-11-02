import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/recovery.dart';
import 'package:handy_ui/kit.dart';
import 'document_page.dart';
import 'document_view.dart';
import 'library_list.dart';
import 'reader_actions.dart';
import '../text/text_opener.dart';

/// Reading: the library on the left and the document on the right on wide
/// screens; on a phone the library, and a document opens over it.
class ReadPage extends StatefulWidget {
  final ReaderActions actions;
  const ReadPage({super.key, required this.actions});
  @override
  State<ReadPage> createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  bool source = false, wide = false;
  ReaderActions get actions => widget.actions;

  @override
  void initState() {
    super.initState();
    // Coming back to reading resumes the open document.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && actions.store.current != null) shown(true);
    });
  }

  /// The one way in: Markdown goes to the writer, the rest shows here.
  Future<void> openFile(BuildContext context) async {
    final where = await actions.opener.pick(context);
    if (!context.mounted) return;
    if (where == Opened.writer) {
      await Navigator.pushNamed(context, '/write');
    } else if (where == Opened.reader) {
      await shown(true);
    }
  }

  Future<void> shown(bool ok) async {
    if (!ok || !mounted) return;
    setState(() => source = false);
    if (wide) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => DocumentPage(actions: actions)),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([actions.store, actions.busy]),
    builder: (context, _) {
      final store = actions.store;
      if (store.error != null) {
        return HandyLoadError(
          title: tr(
            context,
            'Your reading library could not be read',
            'Chưa đọc được thư viện tài liệu',
          ),
          error: store.error!,
          onRetry: store.load,
          recovery: DocumentRecoveryButton(
            documents: store.documents,
            files: actions.files,
            reload: store.load,
          ),
        );
      }
      if (store.library == null) return const HandyLoading();
      final empty = store.library!.documents.isEmpty && store.current == null;
      final busy = actions.busy.value;
      return Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'Kept files', 'Tệp đã giữ')),
          actions: [
            if (!empty)
              TextButton.icon(
                key: const Key('reader-import'),
                onPressed: busy ? null : () => openFile(context),
                icon: const Icon(Icons.file_open_outlined),
                label: Text(tr(context, 'Open file', 'Mở tệp')),
              ),
            HandyMenuButton(
              items: [
                if (actions.files is BatchHandyFiles)
                  HandyMenuItem(
                    Icons.library_add_outlined,
                    tr(context, 'Add several files', 'Thêm nhiều tệp'),
                    busy ? null : () => actions.addMany(context),
                    key: const Key('reader-import-many'),
                  ),
                HandyMenuItem(
                  Icons.archive_outlined,
                  tr(context, 'Save library as ZIP', 'Lưu thư viện thành ZIP'),
                  busy || store.library!.documents.isEmpty
                      ? null
                      : () => actions.backup(context),
                  key: const Key('reader-backup'),
                ),
                HandyMenuItem(
                  Icons.unarchive_outlined,
                  tr(context, 'Restore from ZIP', 'Khôi phục từ ZIP'),
                  busy ? null : () => actions.restore(context),
                  key: const Key('reader-restore'),
                ),
              ],
            ),
          ],
        ),
        body: empty
            ? HandyEmpty(
                title: tr(context, 'Open a text file', 'Mở một tệp văn bản'),
                message: tr(
                  context,
                  'Markdown opens in the writer. Text, web pages and code open here to read and search, up to 1 MB each; scripts and pictures never run or load. Save a copy to keep it here (up to 50).',
                  'Markdown mở trong trình viết. Văn bản, trang web và mã mở ở đây để đọc và tìm, mỗi tệp tối đa 1 MB; script và ảnh không bao giờ chạy hay tải. Lưu một bản để giữ ở đây (tối đa 50).',
                ),
                action: FilledButton.icon(
                  key: const Key('reader-import'),
                  onPressed: busy ? null : () => openFile(context),
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(tr(context, 'Open file', 'Mở tệp')),
                ),
              )
            : LayoutBuilder(builder: _layout),
      );
    },
  );

  Widget _layout(BuildContext context, BoxConstraints box) {
    wide = box.maxWidth >= 900;
    final store = actions.store;
    final list = ListView(
      padding: const EdgeInsets.only(top: HandySpace.s, bottom: HandySpace.xxl),
      children: [
        if (!wide && store.current != null && !store.saved)
          Padding(
            padding: const EdgeInsets.all(HandySpace.l),
            child: HandyNotice(
              tr(
                context,
                '${store.current!.name} is open but not saved.',
                '${store.current!.name} đang mở nhưng chưa lưu.',
              ),
              action: TextButton(
                onPressed: () => shown(true),
                child: Text(tr(context, 'Show', 'Xem')),
              ),
            ),
          ),
        LibraryList(
          actions: actions,
          onOpen: (d) async => shown(await actions.open(context, d)),
        ),
      ],
    );
    if (!wide) return list;
    final c = HandyColors.of(context);
    final d = store.current;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 340, child: list),
        VerticalDivider(width: 1, color: c.rule),
        Expanded(
          child: ColoredBox(
            color: c.ground,
            child: d == null
                ? HandyEmpty(
                    title: tr(
                      context,
                      'Pick a document to read',
                      'Chọn một tài liệu để đọc',
                    ),
                  )
                : HandySwap(
                    child: Column(
                      key: ValueKey(d.id),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            HandySpace.l,
                            HandySpace.m,
                            HandySpace.s,
                            HandySpace.xs,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  d.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DocumentActions(
                                actions: actions,
                                source: source,
                                onSource: (v) => setState(() => source = v),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: DocumentBody(
                            document: d,
                            source: source,
                            saved: store.saved,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
