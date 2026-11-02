import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_inventory/handy_inventory.dart';
import '../inventory/keep_store.dart';
import '../item/attachments.dart';

/// One photo waiting for its name.
class DraftPhoto {
  final String uri, file;
  final Uint8List bytes;
  final TextEditingController name = TextEditingController();
  DraftPhoto(this.uri, this.file, this.bytes);
}

/// A photo that was refused, and why.
typedef RejectedPhoto = ({String file, Object error});

/// Several photos becoming several items. Nothing here is saved: the drafts
/// live only in memory until [build] hands them to the store in one write,
/// so cancelling keeps nothing.
class BatchDraft extends ChangeNotifier {
  /// Photos in one batch. Each item keeps its photo inside Keep's 16 MB
  /// library, so a batch stays small enough to land in one write.
  static const limit = 20;

  final List<DraftPhoto> drafts = [];
  final List<RejectedPhoto> rejected = [];
  final TextEditingController location = TextEditingController();
  String box;

  /// Rows whose name was left empty at the last [build].
  Set<DraftPhoto> unnamed = {};
  BatchDraft({this.box = ''});

  bool get full => drafts.length >= limit;
  bool get isEmpty => drafts.isEmpty;
  int get room => limit - drafts.length;

  /// Checks each file the way the item editor does (PNG or JPEG by its first
  /// bytes, 4 MB at most). Good photos become drafts; the rest are listed.
  void add(Iterable<ImportedBytes> files) {
    for (final f in files) {
      if (full) {
        rejected.add((
          file: f.name,
          error: const FormatException(
            'Up to 20 photos at a time / Tối đa 20 ảnh mỗi lần',
          ),
        ));
        continue;
      }
      try {
        drafts.add(DraftPhoto(acceptAttachment(f.bytes), f.name, f.bytes));
      } catch (e) {
        rejected.add((file: f.name, error: e));
      }
    }
    notifyListeners();
  }

  void remove(DraftPhoto d) {
    drafts.remove(d);
    unnamed.remove(d);
    d.name.dispose();
    notifyListeners();
  }

  void setBox(String id) {
    box = id;
    notifyListeners();
  }

  void dismissRejected() {
    rejected.clear();
    notifyListeners();
  }

  /// The items to save, all stamped [now]. Throws, and marks the rows, when
  /// a photo has no name; nothing is half-built.
  List<AssetEdit> build({String? now, String Function() id = newId}) {
    unnamed = {
      for (final d in drafts)
        if (d.name.text.trim().isEmpty) d,
    };
    notifyListeners();
    if (drafts.isEmpty) {
      throw const FormatException('Add a photo first / Thêm ảnh trước');
    }
    if (unnamed.isNotEmpty) {
      throw const FormatException(
        'Name every photo, or remove it / Đặt tên cho từng ảnh, hoặc bỏ ảnh đó',
      );
    }
    final at = now ?? timestamp();
    return [
      for (final d in drafts)
        AssetEdit(
          createAsset(
            id: id(),
            name: d.name.text,
            now: at,
            fields: {
              'location': location.text,
              'boxId': box,
              'photoUri': d.uri,
            },
          ),
          {d.uri: d.bytes},
        ),
    ];
  }

  @override
  void dispose() {
    for (final d in drafts) {
      d.name.dispose();
    }
    location.dispose();
    super.dispose();
  }
}
