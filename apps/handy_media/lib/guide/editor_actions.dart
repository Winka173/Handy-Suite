import 'dart:convert';
import 'dart:math';
import 'package:handy_files/handy_files.dart';
import 'package:handy_files/share.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import '../annotation_image_edit.dart';
import '../annotation_painter.dart';
import 'editor_page.dart';
import 'export_sheet.dart';
import 'guide_output.dart';
import 'project_dialog.dart';

/// What the editor does on request, each with its message. Failures leave
/// the guide as it was and say so; the draft copy keeps every edit.
extension EditorActions on CaptureEditorState {
  /// The library first, then the draft; a draft that will not clear is a
  /// note, not a failed save.
  Future<void> save() => run(() async {
    final bundle = c.bundle();
    await widget.onCommit(bundle);
    c.saved(bundle.project);
    try {
      await widget.draft?.clear();
    } catch (_) {
      if (mounted) {
        say(
          tr(
            context,
            'Saved. The draft copy could not be cleared; it is kept apart.',
            'Đã lưu. Chưa xóa được bản nháp; bản nháp được giữ riêng.',
          ),
        );
      }
      return;
    }
    if (mounted) close();
  });

  /// Back with unsaved edits: ask, then drop the draft copy.
  Future<void> leave() async {
    if (busy) return;
    if (c.dirty) {
      final ok = await confirmHandy(
        context,
        title: tr(
          context,
          'Discard unsaved edits?',
          'Bỏ các chỉnh sửa chưa lưu?',
        ),
        message: tr(
          context,
          'The guide goes back to how it was last saved.',
          'Hướng dẫn trở về lần lưu gần nhất.',
        ),
        confirmLabel: tr(context, 'Discard', 'Bỏ'),
        destructive: true,
      );
      if (!ok || !mounted) return;
      try {
        await widget.draft?.clear();
      } catch (_) {
        if (mounted) {
          say(
            tr(
              context,
              'The draft could not be cleared. Your edits and saved guides are unchanged.',
              'Chưa xóa được bản nháp. Chỉnh sửa và các hướng dẫn đã lưu vẫn giữ nguyên.',
            ),
          );
        }
        return;
      }
    }
    if (mounted) close();
  }

  Future<void> addFiles() => run(() async {
    if (c.project.steps.length >= 100) {
      throw const FormatException('Step limit: 100');
    }
    final files = widget.files;
    if (files is BatchHandyFiles) {
      await c.addPictures(
        await (files as BatchHandyFiles).importManyBytes(
          extensions: ['png', 'jpg', 'jpeg', 'webp'],
          maxFiles: min(50, 100 - c.project.steps.length),
        ),
      );
    } else {
      final file = await files.importBytes(
        extensions: ['png', 'jpg', 'jpeg', 'webp'],
        maxBytes: 20000000,
      );
      if (file != null) await c.addPictures([file]);
    }
  });

  Future<void> addPhoto() => run(() async {
    final file = await camera.capture();
    if (file != null) await c.addPictures([file]);
  });

  Future<void> relink() => run(() async {
    final file = await widget.files.importBytes(
      extensions: ['png'],
      maxBytes: 8000000,
    );
    if (file != null) c.relink(file.bytes);
  });

  Future<void> editPicture(String op) => run(() async {
    final source = c.picture;
    if (source == null) {
      throw const FormatException('Relink the missing PNG before editing');
    }
    final ok = await confirmHandy(
      context,
      title: tr(
        context,
        'Paint the notes into the picture?',
        'Gộp chú thích vào ảnh?',
      ),
      message: tr(
        context,
        'The notes become part of a new picture. Undo brings back the picture and its notes.',
        'Chú thích thành một phần của ảnh mới. Hoàn tác để lấy lại ảnh và chú thích.',
      ),
      confirmLabel: tr(context, 'Go on', 'Tiếp tục'),
    );
    if (!ok || !mounted) return;
    final t = track();
    final png = await editAnnotatedImage(
      c.step!,
      source,
      op,
      cropLayer: c.layer,
      cancellation: t,
    );
    t.check();
    c.applyEditedPicture(png);
  });

  Future<void> deleteStep() => run(() async {
    final ok = await confirmHandy(
      context,
      title: tr(
        context,
        'Delete step ${c.stepIndex + 1}?',
        'Xóa bước ${c.stepIndex + 1}?',
      ),
      message: tr(context, 'Undo brings it back.', 'Hoàn tác để lấy lại.'),
      confirmLabel: tr(context, 'Delete', 'Xóa'),
      destructive: true,
    );
    if (ok) c.deleteStep();
  });

  Future<void> details() => run(() async {
    final next = await editProjectDetails(context, c.project);
    if (next != null && mounted) c.setProject(next);
  });

  Future<void> repeatMask() => run(() async {
    final ok = await confirmHandy(
      context,
      title: tr(
        context,
        'Hide this place on every step?',
        'Che chỗ này ở mọi bước?',
      ),
      message: tr(
        context,
        'The same area is hidden on the other steps. Check each one: their layouts may differ.',
        'Cùng vùng đó được che ở các bước khác. Hãy xem từng bước vì bố cục có thể khác.',
      ),
      confirmLabel: tr(context, 'Hide', 'Che'),
    );
    if (ok) c.repeatMask();
  });

  /// Shares the step's picture with its notes painted in, after a look.
  Future<void> sharePicture() => run(() async {
    final png = await flattenAnnotation(c.step!, c.picture!);
    if (!mounted || !await reviewPicture(context, png) || !mounted) return;
    final box = context.findRenderObject() as RenderBox;
    final result = await const LocalShare().bytes(
      'handy-media-annotated.png',
      png,
      mimeType: 'image/png',
      origin: box.localToGlobal(Offset.zero) & box.size,
    );
    if (mounted) say(outcome(_shared(result)));
  });

  Future<void> savePicture() => run(() async {
    final png = await flattenAnnotation(c.step!, c.picture!);
    final uri = await widget.files.exportBytes(
      'handy-media-annotated.png',
      png,
      mimeType: 'image/png',
    );
    if (mounted) say(outcome(uri));
  });

  Future<void> backup(bool zip) => run(() async {
    final b = c.bundle();
    final uri = zip
        ? await widget.files.exportBytes(
            'handy-media-project.zip',
            buildPortableProject(b.project, b.assets),
            mimeType: 'application/zip',
          )
        : await widget.files.exportText(
            'handy-media-project.json',
            b.project.serialize(),
          );
    if (mounted) say(outcome(uri));
  });

  Future<void> exportGuide([String? format]) async {
    final guide = c.bundle().project;
    final choice = format == null
        ? await pickGuideFormat(context, guide)
        : (format: format, share: false);
    if (choice == null || !mounted) return;
    await run(() async {
      final blocked = guideBlocker(guide, choice.format);
      if (blocked != null) throw FormatException(blocked);
      if (!await reviewGuide(context, guide, choice.format) || !mounted) {
        return;
      }
      final t = track();
      final locale = Localizations.localeOf(context).languageCode;
      final file = await renderGuide(
        guide,
        c.assets,
        choice.format,
        locale: locale,
        token: t,
        progress: (done, of) => mounted
            ? showProgress(
                done == of
                    ? tr(context, 'Putting it together…', 'Đang ghép…')
                    : tr(
                        context,
                        'Drawing step ${done + 1} of $of',
                        'Đang dựng bước ${done + 1}/$of',
                      ),
              )
            : null,
      );
      t.check();
      if (!mounted) return;
      String? result;
      if (choice.share) {
        final box = context.findRenderObject() as RenderBox;
        result = _shared(
          await const LocalShare().bytes(
            file.name,
            file.bytes,
            mimeType: file.mime,
            origin: box.localToGlobal(Offset.zero) & box.size,
            cancellation: t,
          ),
        );
      } else if (choice.format == 'md') {
        result = await widget.files.exportText(
          file.name,
          utf8.decode(file.bytes),
          cancellation: t,
        );
      } else {
        result = await widget.files.exportBytes(
          file.name,
          file.bytes,
          mimeType: file.mime,
          cancellation: t,
        );
      }
      if (mounted) {
        say(
          [
            if (file.note.isNotEmpty) file.note,
            outcome(
              result,
              done: tr(context, 'Guide exported', 'Đã xuất hướng dẫn'),
            ),
          ].join('. '),
        );
      }
    });
  }

  String? _shared(LocalShareResult r) => switch (r) {
    LocalShareResult.dismissed => null,
    LocalShareResult.selected => 'share-selected',
    LocalShareResult.unknown => 'share-unknown',
  };

  String outcome(String? result, {String? done}) => switch (result) {
    null => tr(context, 'Export canceled', 'Đã hủy xuất'),
    'share-selected' => tr(context, 'Shared', 'Đã chia sẻ'),
    'share-unknown' => tr(
      context,
      'The share sheet closed; save a copy if it did not arrive.',
      'Bảng chia sẻ đã đóng; hãy lưu một bản nếu chưa tới nơi.',
    ),
    _ => done ?? tr(context, 'Saved', 'Đã lưu'),
  };
}
