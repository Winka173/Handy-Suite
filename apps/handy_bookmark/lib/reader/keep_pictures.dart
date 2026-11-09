import 'dart:typed_data';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_core/handy_core.dart';
import '../services/metadata_client.dart';

/// How long keeping a copy may spend on its pictures before it keeps what
/// it has.
const keepPicturesBudget = Duration(seconds: 45);

/// [copy] with its article pictures fetched and cleaned, for keeping it
/// offline. Asked only when the person keeps a copy. One at a time, through
/// the same guarded client as the page; a picture that fails, or would pass
/// [ReadingCopy.maxPictureBytes], is left out and the text is kept anyway.
Future<ReadingCopy> withArticlePictures(
  MetadataClient client,
  ReadingCopy copy,
  CancellationToken token, {
  Duration budget = keepPicturesBudget,
}) async {
  if (!client.available) return copy;
  final clock = Stopwatch()..start();
  final got = <int, Uint8List?>{};
  var total = copy.pictureBytes;
  for (final i in copy.pictureSlots) {
    final b = copy.blocks[i];
    if (b.picture != null) continue;
    if (clock.elapsed > budget) break;
    token.check();
    final r = await client.fetchArticlePicture(b.url, cancellation: token);
    final bytes = r.bytes;
    if (bytes == null) continue;
    if (total + bytes.length > ReadingCopy.maxPictureBytes) break;
    total += bytes.length;
    got[i] = bytes;
  }
  return got.isEmpty ? copy : copy.withPictures(got);
}
