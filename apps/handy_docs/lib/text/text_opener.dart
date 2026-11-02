import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import '../read/reader_actions.dart';
import '../read/reader_store.dart';
import '../write/draft.dart';

/// Where an opened text file went.
enum Opened { writer, reader }

/// The one way in for text files. Markdown opens in the writer; text, code
/// and web pages open read-only with find, and can become an editable
/// Markdown copy. Nothing is written until the person saves.
class TextOpener {
  final DraftController draft;
  final ReaderActions reader;
  TextOpener(this.draft, this.reader);

  HandyFiles get files => reader.files;

  /// Asks before an opened file replaces words in the writer: unsaved
  /// words would be lost; a saved draft stays saved until saved over.
  Future<bool> mayReplaceDraft(BuildContext context, String next) async {
    final now = draft.source.text;
    if (now.trim().isEmpty || now == next) return true;
    return confirmHandy(
      context,
      title: draft.dirty
          ? tr(context, 'Replace unsaved draft?', 'Thay bản nháp chưa lưu?')
          : tr(context, 'Replace the draft?', 'Thay bản nháp?'),
      message: draft.dirty
          ? tr(
              context,
              'Export or save a copy before replacing it.',
              'Xuất hoặc lưu một bản trước khi thay thế.',
            )
          : tr(
              context,
              'The writer shows the opened file instead. Your saved draft stays saved until you save over it.',
              'Trình viết sẽ hiện tệp vừa mở. Bản nháp đã lưu vẫn còn cho tới khi bạn lưu đè.',
            ),
      confirmLabel: tr(context, 'Replace', 'Thay thế'),
    );
  }

  /// Puts [text] in the writer, after asking. False when declined.
  Future<bool> toWriter(BuildContext context, String text) async {
    serializeMarkdownDraft(text);
    if (!await mayReplaceDraft(context, text)) return false;
    draft.replace(text);
    return true;
  }

  /// Opens [file] where it belongs, or null when the person declined.
  Future<Opened?> open(BuildContext context, ImportedBytes file) async {
    final doc = ReaderStore.read(file);
    if (isMarkdownName(file.name)) {
      return await toWriter(context, doc.source) ? Opened.writer : null;
    }
    if (!context.mounted || !await reader.mayClose(context)) return null;
    reader.store.show(doc);
    return Opened.reader;
  }

  /// Picks one text file and opens it. A file that is not UTF-8 text is
  /// refused with a message and changes nothing.
  Future<Opened?> pick(BuildContext context) async {
    Opened? where;
    await reader.guard(context, () async {
      final file = await files.importBytes(
        extensions: readerExtensions,
        maxBytes: 1000000,
      );
      if (file == null || !context.mounted) return null;
      where = await open(context, file);
      return null;
    });
    return where;
  }

  /// Picks a file and shows it: the writer or the reading view.
  Future<void> pickAndShow(
    BuildContext context, {
    bool inWriter = false,
  }) async {
    final where = await pick(context);
    if (!context.mounted || where == null) return;
    if (where == Opened.writer && !inWriter) {
      await Navigator.pushNamed(context, '/write');
    } else if (where == Opened.reader) {
      await Navigator.pushNamed(context, '/read');
    }
  }

  /// A read-only document as an editable Markdown draft, in the writer.
  Future<void> editCopy(BuildContext context, ReaderDocument d) =>
      reader.guard(context, () async {
        if (!await toWriter(context, markdownCopyOf(d)) || !context.mounted) {
          return null;
        }
        // Not awaited: the writer stays open long after this action ends.
        Navigator.pushNamed(context, '/write');
        return null;
      });
}
