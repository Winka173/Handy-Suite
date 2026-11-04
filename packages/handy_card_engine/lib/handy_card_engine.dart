/// Handy Card's editor core: a versioned scene graph of card sides and
/// layers, pure geometry and hit testing, an undoable editing session, and
/// the exporters (SVG, PDF, vCard, QR, HTML profile, portable project ZIP).
/// Nothing here depends on Flutter, so every rule is testable on the host.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:handy_core/portable_zip.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:qr/qr.dart' as qr;
import 'package:vector_math/vector_math_64.dart' show Matrix4;

part 'src/geometry.dart';
part 'src/model.dart';
part 'src/palettes.dart';
part 'src/registry.dart';
part 'src/tree.dart';
part 'src/session.dart';
part 'src/edits.dart';
part 'src/snap.dart';
part 'src/paths.dart';
part 'src/profile.dart';
part 'src/vcard.dart';
part 'src/qr_code.dart';
part 'src/text_layout.dart';
part 'src/svg_export.dart';
part 'src/pdf_export.dart';
part 'src/html_profile.dart';
part 'src/project_zip.dart';
part 'src/presets.dart';
part 'src/templates.dart';
part 'src/template_library.dart';
part 'src/batch.dart';
part 'src/badge_extension.dart';
