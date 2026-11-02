library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;
import 'package:qr/qr.dart' as qr;
import 'package:image/image.dart' as image;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

part 'src/numbers.dart';
part 'src/notebook.dart';
part 'src/tools.dart';
part 'src/security_qr.dart';
part 'src/qr_render.dart';
part 'src/qr_history.dart';
part 'src/salary.dart';
part 'src/number_words.dart';
part 'src/lunar.dart';
part 'src/vietqr.dart';
part 'src/vietqr_banks.dart';

typedef ToolRunner = String Function(String input, String options);

class ToolDefinition {
  const ToolDefinition({
    required this.id,
    required this.titleEn,
    required this.titleVi,
    required this.description,
    required this.inputLabel,
    this.optionsLabel = '',
    required ToolRunner run,
  }) : _run = run;
  final String id, titleEn, titleVi, description, inputLabel, optionsLabel;
  final ToolRunner _run;
  String run(String input, [String options = '']) =>
      _run(_bounded(input), _bounded(options, 30000));
}

String _bounded(String source, [int maximum = 1000000]) {
  if (source.length > maximum)
    throw const FormatException('Input exceeds the supported size');
  return source;
}

String _json(Object value) => const JsonEncoder.withIndent('  ').convert(value);
