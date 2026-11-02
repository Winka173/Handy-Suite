/// Reads Anki packages (.apkg, .colpkg) into Recall cards on every platform,
/// the web included: the ZIP, the zstd-compressed newer collection, its
/// SQLite tables and protobuf note types are all read in pure Dart.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'handy_recall.dart';

part 'src/anki/sqlite.dart';
part 'src/anki/proto.dart';
part 'src/anki/html.dart';
part 'src/anki/package.dart';
