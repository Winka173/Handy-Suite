import 'package:handy_ui/kit.dart' show HandyAutoBackup;
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/handy_storage.dart';
import 'pdf/pdf_desk.dart';
import 'read/reader_actions.dart';
import 'read/reader_store.dart';
import 'scan/scan_store.dart';
import 'sign/signature_store.dart';
import 'text/text_opener.dart';
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
  final SignatureStore signatures;
  late final TextOpener opener = TextOpener(draft, reader);

  /// Automatic backups of the kept files; null in tests that do not need
  /// them.
  HandyAutoBackup? autoBackup;
  DocsScope({
    required this.files,
    required this.preferences,
    required this.scan,
    required this.draft,
    required this.pdf,
    required ReaderStore reader,
    required this.signatures,
  }) : reader = ReaderActions(reader, files) {
    this.reader.opener = opener;
  }

  void load() {
    scan.load();
    draft.load();
    reader.store.load();
    signatures.load();
  }

  void dispose() {
    autoBackup?.dispose();
    scan.dispose();
    draft.dispose();
    pdf.dispose();
    signatures.dispose();
    reader.store.dispose();
    reader.busy.dispose();
  }
}
