import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs/pdf/pdf_desk.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

/// A five-page PDF on the desk, without PDFium: each job records what it
/// was asked and returns bytes that name the pages it would hold.
class PrintDesk extends PdfDesk {
  ({int start, bool skipFirst, bool right})? numbered;
  PrintDesk() {
    inputs.add(
      ImportedBytes('report.pdf', Uint8List.fromList('%PDF-1.7'.codeUnits)),
    );
  }
  @override
  int get pages => 5;

  Uint8List _pages(List<int> p) =>
      Uint8List.fromList(p.map((i) => '${i + 1}').join(',').codeUnits);

  @override
  Future<void> duplex(CancellationToken token) async {
    final p = duplexPlan(pages);
    output = _pages(p.fronts);
    backs = _pages(p.backs);
    plan = p;
    outputNote = 'duplex';
    notifyListeners();
  }

  @override
  Future<void> number({
    required int start,
    required bool skipFirst,
    required bool right,
    required CancellationToken token,
  }) async {
    numbered = (start: start, skipFirst: skipFirst, right: right);
    backs = null;
    output = Uint8List(1000);
    outputNote = 'numbered';
    notifyListeners();
  }
}

void main() {
  testWidgets('both sides: two files and the steps between them', (
    tester,
  ) async {
    final docs = Docs();
    final desk = PrintDesk();
    await start(tester, docs: docs, desk: desk, size: const Size(1280, 900));
    await go(tester, '/pdf');
    await tapKey(tester, 'pdf-duplex');
    expect(find.text('Two PDFs for both sides'), findsOneWidget);
    expect(find.textContaining('pages 1, 3, 5'), findsOneWidget);
    expect(find.textContaining('page 5 has no back'), findsOneWidget);
    expect(find.textContaining('pages 4, 2'), findsOneWidget);
    await tapKey(tester, 'pdf-export');
    expect(docs.files.name, 'report - 1 fronts.pdf');
    expect(String.fromCharCodes(docs.files.exported!), '1,3,5');
    await tapKey(tester, 'pdf-export-backs');
    expect(docs.files.name, 'report - 2 backs.pdf');
    expect(String.fromCharCodes(docs.files.exported!), '4,2');
  });

  testWidgets('page numbers take the start, the cover and the corner', (
    tester,
  ) async {
    final docs = Docs();
    final desk = PrintDesk();
    await start(tester, docs: docs, desk: desk, size: const Size(1280, 900));
    await go(tester, '/pdf');
    await tester.ensureVisible(find.byKey(const Key('pdf-number-start')));
    await tester.enterText(find.byKey(const Key('pdf-number-start')), 'x');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('pdf-number')))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byKey(const Key('pdf-number-start')), '3');
    await tapKey(tester, 'pdf-number-right');
    await tapKey(tester, 'pdf-number-skip');
    await tapKey(tester, 'pdf-number');
    expect(desk.numbered, (start: 3, skipFirst: true, right: true));
    expect(find.text('Page numbers added'), findsOneWidget);
    await tapKey(tester, 'pdf-export');
    expect(docs.files.name, 'report-numbered.pdf');
  });
}
