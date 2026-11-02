import 'dart:convert';
import 'dart:math';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_files/share.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import '../annotation_image_edit.dart';
import '../annotation_painter.dart';
import 'editor_page.dart';
import 'export_sheet.dart';
import 'gif_sheet.dart';
import 'guide_output.dart';
import 'ids.dart';
import 'project_dialog.dart';
import 'sensitive_review.dart';
import 'text_reader.dart';

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

  /// Reads the words in this step's picture and proposes masks over what
  /// looks private. Nothing is hidden until the person chooses.
  Future<void> findSensitive() => run(() async {
    final step = c.step!, png = c.picture;
    if (png == null) {
      throw const FormatException('Relink the missing PNG first');
    }
    final t = track();
    showProgress(
      tr(
        context,
        'Reading the words in this picture…',
        'Đang đọc chữ trong ảnh…',
      ),
    );
    final List<OcrLine> lines;
    try {
      lines = await reader.read(png, cancellation: t);
      t.check();
    } on Cancelled {
      if (mounted) say(tr(context, 'Stopped reading', 'Đã dừng đọc'));
      return;
    } on TextReaderUnavailable catch (e) {
      if (mounted) {
        say(
          e.languageMissing
              ? tr(
                  context,
                  'Windows has no text recognition language yet. Add a language with its optical character recognition feature in Settings, then try again.',
                  'Windows chưa có ngôn ngữ nhận dạng chữ. Hãy thêm ngôn ngữ kèm tính năng nhận dạng ký tự quang học (OCR) trong Cài đặt rồi thử lại.',
                )
              : tr(
                  context,
                  'This device cannot read text in pictures. Look over the step and hide what is private by hand.',
                  'Thiết bị này không đọc được chữ trong ảnh. Hãy tự xem bước này và che chỗ riêng tư.',
                ),
        );
      }
      return;
    }
    final found = findSensitiveAreas(
      lines,
      imageWidth: step.imageWidth,
      imageHeight: step.imageHeight,
      hidden: [
        for (final l in step.annotations)
          if (l.kind == 'redact') l.geometry,
      ],
    );
    if (!mounted) return;
    final room = 100 - step.annotations.length;
    if (found.isEmpty || room <= 0) {
      say(
        found.isEmpty
            ? tr(
                context,
                'No email, phone, card, account number, code or key was found in this picture. Reading can miss words; look it over yourself.',
                'Không thấy email, số điện thoại, số thẻ, số tài khoản, mã hay khóa trong ảnh này. Việc đọc có thể sót chữ; hãy tự xem lại.',
              )
            : tr(
                context,
                'This step already has 100 notes; remove some to add masks.',
                'Bước này đã có 100 chú thích; hãy xóa bớt để thêm vùng che.',
              ),
      );
      return;
    }
    c.select(null);
    c.pick(null);
    startReview(SensitiveReview(step.id, found.take(room).toList()));
  });

  /// Hides the chosen places, as one change Undo takes back.
  void applyReview() {
    final r = review;
    if (r == null) return;
    final masks = redactionLayers(r.accepted, newId: () => captureId('mask'));
    try {
      c.addMasks(r.stepId, masks);
    } on FormatException catch (e) {
      say(e.message);
      return;
    }
    endReview();
    say(
      tr(
        context,
        masks.length == 1
            ? '1 place hidden. Undo brings it back.'
            : '${masks.length} places hidden. Undo brings them back.',
        'Đã che ${masks.length} chỗ. Hoàn tác để lấy lại.',
      ),
    );
  }

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
    var gif = defaultGifOptions;
    if (choice.format == 'gif' && format == null) {
      final picked = await pickGifOptions(context, guide, c.assets);
      if (picked == null || !mounted) return;
      gif = picked;
    }
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
        gif: gif,
        frames: (done, of) => mounted
            ? showProgress(
                done == of
                    ? tr(context, 'Writing the GIF…', 'Đang ghi GIF…')
                    : tr(
                        context,
                        'Making frame ${done + 1} of $of',
                        'Đang tạo khung ${done + 1}/$of',
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
