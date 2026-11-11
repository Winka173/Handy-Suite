import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_files/handy_files.dart' show ImportedBytes;
import 'package:handy_files/share.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/words.dart';

/// Sends [r] to someone as one HTML page (as Handy Bookmark sends its
/// collections): any browser reads its steps, Handy Habit imports it. The
/// share sheet where the phone has one, Save as elsewhere.
Future<void> shareRoutine(
  BuildContext context,
  HabitScope scope,
  Routine r,
) async {
  final page = sharedRoutinePage(r, vietnamese: isVi(context));
  final bytes = Uint8List.fromList(utf8.encode(page));
  final clean = r.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  final name = '${clean.isEmpty ? 'routine' : clean}.html';
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null || !box.hasSize
      ? const Rect.fromLTWH(0, 0, 1, 1)
      : box.localToGlobal(Offset.zero) & box.size;
  try {
    if (localShareSupported) {
      await const LocalShare().bytes(
        name,
        bytes,
        mimeType: 'text/html',
        origin: origin,
      );
    } else {
      final saved = await scope.files.exportBytes(
        name,
        bytes,
        mimeType: 'text/html',
      );
      if (saved != null && context.mounted)
        showHandyMessage(context, tr(context, 'Saved $name.', 'Đã lưu $name.'));
    }
  } catch (e) {
    if (context.mounted)
      showHandyMessage(
        context,
        tr(
          context,
          'Not shared: ${errorText(context, e)}',
          'Chưa chia sẻ được: ${errorText(context, e)}',
        ),
      );
  }
}

/// Picks a shared routine page and opens it in the editor, filled in, to
/// look over before saving; nothing is saved until Save. A file that is
/// not a shared routine is refused with a word why.
Future<bool> importSharedRoutine(BuildContext context, HabitScope scope) async {
  final ImportedBytes? file;
  try {
    file = await scope.files.importBytes(
      extensions: ['html', 'htm'],
      maxBytes: sharedRoutineMaxBytes,
    );
  } catch (e) {
    if (context.mounted)
      showHandyMessage(
        context,
        tr(
          context,
          'Could not open the file: ${errorText(context, e)}',
          'Chưa mở được tệp: ${errorText(context, e)}',
        ),
      );
    return false;
  }
  if (file == null || !context.mounted) return false;
  final Routine routine;
  try {
    routine = readSharedRoutine(file.bytes);
  } on FormatException {
    showHandyMessage(
      context,
      tr(
        context,
        'This file is not a routine shared from Handy Habit.',
        'Tệp này không phải quy trình chia sẻ từ Handy Habit.',
      ),
    );
    return false;
  }
  return await Navigator.pushNamed<String>(
        context,
        '/routine/new',
        arguments: routine,
      ) !=
      null;
}
