import 'package:flutter/foundation.dart';
import 'package:handy_files/handy_files.dart';
import 'data/library.dart';

/// What every Handy Card screen shares.
class CardScope {
  final CardLibrary library;
  final CardImages images;
  final HandyFiles files;

  /// Off while the studio or an export is open: no ads there.
  final ValueNotifier<bool> adsVisible = ValueNotifier(true);
  CardScope({required this.library, required this.images, required this.files});
}
