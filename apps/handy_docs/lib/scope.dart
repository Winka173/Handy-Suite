import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/handy_storage.dart';
import 'pdf/pdf_desk.dart';
import 'read/reader_actions.dart';
import 'read/reader_store.dart';
import 'scan/scan_store.dart';
import 'write/draft.dart';

/// Everything Docs holds while it runs: the scan, the draft, the open PDFs
/// and the reading library. Each keeps its own data; none share any.
class DocsScope {
  final HandyFiles files;
  final PreferencesRepository preferences;
  final ScanStore scan;
  final DraftController draft;
  final PdfDesk pdf;
  final ReaderActions reader;
  DocsScope({
    required this.files,
    required this.preferences,
    required this.scan,
    required this.draft,
    required this.pdf,
    required ReaderStore reader,
  }) : reader = ReaderActions(reader, files);

  void load() {
    scan.load();
    draft.load();
    reader.store.load();
  }

  void dispose() {
    scan.dispose();
    draft.dispose();
    pdf.dispose();
    reader.store.dispose();
    reader.busy.dispose();
  }
}
