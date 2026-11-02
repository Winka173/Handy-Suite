import 'dart:typed_data';
import 'package:handy_files/handy_files.dart';
import 'package:handy_pdf/handy_pdf.dart';
import 'package:handy_ui/kit.dart';
import '../pdf/pdf_desk.dart';
import 'fill_controller.dart';
import 'fill_page.dart';
import 'signature_store.dart';

/// `#/pdf/fill`: signs the PDF chosen on the PDF screen, from its own copy
/// in memory. Explains itself where it cannot work.
class FillRoute extends StatefulWidget {
  final PdfDesk desk;
  final SignatureStore signatures;
  final HandyFiles files;

  /// Opens the pages; tests pass pages that need no PDFium.
  final Future<FillSource> Function(Uint8List bytes) openSource;
  const FillRoute({
    super.key,
    required this.desk,
    required this.signatures,
    required this.files,
    this.openSource = PdfFillSource.open,
  });
  @override
  State<FillRoute> createState() => _FillRouteState();
}

class _FillRouteState extends State<FillRoute> {
  FillController? fill;
  Object? error;

  @override
  void initState() {
    super.initState();
    final desk = widget.desk;
    if (supportsPdfEditing && desk.inputs.isNotEmpty) open();
  }

  Future<void> open() async {
    final file = widget.desk.inputs[widget.desk.selected];
    try {
      final source = await widget.openSource(Uint8List.fromList(file.bytes));
      if (!mounted) {
        await source.close();
        return;
      }
      setState(() => fill = FillController(source, file.name));
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  void dispose() {
    fill?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = fill;
    if (f != null) {
      return FillPage(
        fill: f,
        signatures: widget.signatures,
        files: widget.files,
      );
    }
    Widget body;
    if (!supportsPdfEditing) {
      body = HandyEmpty(
        title: tr(context, 'Sign in the app', 'Ký trong ứng dụng'),
        message: tr(
          context,
          'Signing and filling PDFs needs the Android, iOS or Windows app. The browser can still merge, turn and pick pages.',
          'Ký và điền PDF cần ứng dụng Android, iOS hoặc Windows. Trên trình duyệt vẫn ghép, xoay và chọn trang được.',
        ),
      );
    } else if (widget.desk.inputs.isEmpty) {
      body = HandyEmpty(
        title: tr(context, 'Open a PDF first', 'Mở một PDF trước'),
        message: tr(
          context,
          'Add the PDF on the PDF screen, then choose Sign and fill.',
          'Thêm PDF ở màn PDF, rồi chọn Ký và điền.',
        ),
      );
    } else if (error != null) {
      body = HandyEmpty(
        title: tr(
          context,
          'This PDF could not be opened',
          'Chưa mở được PDF này',
        ),
        message: error is FormatException
            ? (error as FormatException).message
            : errorText(context, error!),
      );
    } else {
      body = const HandyLoading();
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Sign and fill', 'Ký và điền'))),
      body: body,
    );
  }
}
