import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import '../capture_draft.dart';
import 'ids.dart';

/// One guide being edited: its steps, their pictures and layers, and the
/// history. Every change goes through here; the draft copy follows each
/// change after 500 ms, and nothing reaches the library until [bundle] is
/// committed by the page.
class EditorController extends ChangeNotifier {
  final CaptureDraft? draft;
  EditorController(PortableCapture initial, {this.draft, bool restored = false})
    : project = initial.project,
      assets = Map.of(initial.assets),
      dirty = restored {
    title.text = project.title;
    title.addListener(_titled);
  }

  CaptureProject project;
  final Map<String, Uint8List> assets;
  final title = TextEditingController();
  final zoom = TransformationController();
  final _undo = <String>[], _redo = <String>[];
  int stepIndex = 0;
  String? selected;

  /// The drawing tool in hand, or null to pick and move layers.
  String? tool;
  bool panMode = false, dirty;

  /// Set when the draft copy could not be written.
  Object? draftError;

  static const maxSteps = 100, imageBudget = 20000000;

  ProjectStep? get step =>
      project.steps.isEmpty ? null : project.steps[stepIndex];
  ProjectLayer? get layer =>
      step?.annotations.where((l) => l.id == selected).firstOrNull;
  Uint8List? get picture => step == null ? null : assets[step!.imageUri];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get imageBytes => assets.values.fold<int>(0, (n, b) => n + b.length);

  void _titled() {
    if (title.text == project.title && !dirty) return;
    dirty = true;
    backup();
    notifyListeners();
  }

  /// What the guide is now, with only the pictures its steps use.
  PortableCapture bundle() {
    final next = project.copyWith(title: title.text);
    final used = next.steps.map((s) => s.imageUri).toSet();
    return PortableCapture(next, {
      for (final e in assets.entries)
        if (used.contains(e.key)) e.key: e.value,
    });
  }

  void backup() => draft?.schedule(bundle, (e) {
    draftError = e;
    notifyListeners();
  });

  /// Remembers the guide as it is, before a change.
  void checkpoint() {
    backup();
    _undo.add(project.serialize());
    if (_undo.length > 10) _undo.removeAt(0);
    _redo.clear();
  }

  void _set(CaptureProject next) {
    project = next;
    stepIndex = min(stepIndex, max(0, next.steps.length - 1));
    dirty = true;
    backup();
    notifyListeners();
  }

  void history(bool back) {
    final from = back ? _undo : _redo, to = back ? _redo : _undo;
    if (from.isEmpty) return;
    to.add(project.serialize());
    selected = null;
    _set(CaptureProject.fromText(from.removeLast()));
  }

  void replaceStep(ProjectStep next, {bool record = true}) {
    if (record) checkpoint();
    _set(
      project.copyWith(
        steps: [for (final s in project.steps) s.id == next.id ? next : s],
      ),
    );
  }

  void editLayer(ProjectLayer next, {bool record = true}) => replaceStep(
    step!.copyWith(
      annotations: [
        for (final a in step!.annotations) a.id == next.id ? next : a,
      ],
    ),
    record: record,
  );

  void showStep(int i) {
    stepIndex = i.clamp(0, max(0, project.steps.length - 1));
    selected = null;
    zoom.value = Matrix4.identity();
    notifyListeners();
  }

  void select(String? id) {
    selected = id;
    notifyListeners();
  }

  void pick(String? kind) {
    tool = kind;
    if (kind != null) panMode = false;
    notifyListeners();
  }

  void togglePan() {
    panMode = !panMode;
    if (panMode) tool = null;
    notifyListeners();
  }

  /// 1×, 2×, 3×, then back to 1×.
  void stepZoom() {
    final scale = zoom.value.getMaxScaleOnAxis();
    final next = scale >= 2.99 ? 1.0 : (scale + 1).clamp(1.0, 3.0);
    zoom.value = Matrix4.diagonal3Values(next, next, 1);
    notifyListeners();
  }

  /// Turns pictures into steps. All are checked and converted first; one
  /// bad picture adds none of them.
  Future<void> addPictures(List<ImportedBytes> files) async {
    if (files.isEmpty) return;
    if (project.steps.length + files.length > maxSteps) {
      throw const FormatException('Step limit: 100');
    }
    final staged = <String, Uint8List>{}, steps = <ProjectStep>[];
    var total = imageBytes;
    for (final file in files) {
      final b = file.bytes;
      final png = b.length >= 8 && b[0] == 137 && b[1] == 80 && b[2] == 78;
      final bytes = png ? b : await convertImage(b, format: 'png');
      if (bytes.length > 8000000) {
        throw const FormatException('Project image exceeds 8 MB');
      }
      final size = projectPngDimensions(bytes);
      total += bytes.length;
      if (total > imageBudget) {
        throw const FormatException('Draft image budget exceeds 20 MB');
      }
      final uri = imageUri(project.id);
      staged[uri] = Uint8List.fromList(bytes);
      steps.add(
        ProjectStep.parse({
          'id': captureId('step'),
          'title': file.name.substring(0, min(200, file.name.length)),
          'body': '',
          'imageUri': uri,
          'imageWidth': size.width,
          'imageHeight': size.height,
          'annotations': <dynamic>[],
        }),
      );
    }
    checkpoint();
    assets.addAll(staged);
    selected = null;
    zoom.value = Matrix4.identity();
    _set(project.copyWith(steps: [...project.steps, ...steps]));
    stepIndex = project.steps.length - 1;
    notifyListeners();
  }

  /// Puts a picture back on a step whose picture went missing; it must be
  /// the same size so the layers still land where they were.
  void relink(Uint8List png) {
    verifyProjectImage(png, step!);
    if (imageBytes + png.length > imageBudget) {
      throw const FormatException('Draft image budget exceeds 20 MB');
    }
    final uri = imageUri(project.id);
    checkpoint();
    assets[uri] = Uint8List.fromList(png);
    replaceStep(step!.copyWith(imageUri: uri), record: false);
  }

  /// Puts an edited picture in place of the step's; its layers are now
  /// part of the picture. Undo brings both back.
  void applyEditedPicture(Uint8List png) {
    if (imageBytes + png.length > imageBudget) {
      throw const FormatException(
        'Draft image budget exceeds 20 MB; export or split the project',
      );
    }
    final size = projectPngDimensions(png), uri = imageUri(project.id);
    final next = ProjectStep.parse({
      ...step!.toJson(),
      'imageUri': uri,
      'imageWidth': size.width,
      'imageHeight': size.height,
      'annotations': <dynamic>[],
    });
    checkpoint();
    assets[uri] = png;
    selected = null;
    replaceStep(next, record: false);
  }

  void moveStep(int from, int to) {
    if (to < 0 || to >= project.steps.length || from == to) return;
    checkpoint();
    final list = [...project.steps]..insert(to, project.steps[from]);
    list.removeAt(from < to ? from : from + 1);
    stepIndex = to;
    _set(project.copyWith(steps: list));
  }

  void deleteStep() {
    checkpoint();
    selected = null;
    _set(project.copyWith(steps: [...project.steps]..removeAt(stepIndex)));
  }

  /// A new layer of the tool in hand over [area]; a tap gives the default
  /// size centred on the tap.
  void addLayer(String kind, {LayerGeometry? area, List<ProjectPoint>? line}) {
    if (step!.annotations.length >= 100) {
      throw const FormatException('Layer limit: 100 per step');
    }
    final number = step!.annotations.where((l) => l.kind == 'step').length + 1;
    var next = defaultLayer(captureId('layer'), kind, step: number);
    if (line != null) {
      next = ProjectLayer.parse({
        ...next.toJson(),
        ...layerBounds(
          ProjectLayer(
            id: next.id,
            kind: kind,
            geometry: next.geometry,
            points: line,
          ),
        ).toJson(),
        'points': [for (final p in line) p.toJson()],
      });
    } else if (area != null) {
      next = next.copyWith(geometry: area);
    }
    replaceStep(step!.copyWith(annotations: [...step!.annotations, next]));
    selected = next.id;
    if (kind != 'pen') tool = null;
    notifyListeners();
  }

  void addStroke(List<ProjectPoint> points) => addLayer('pen', line: points);

  void restack(int by) {
    final list = [...step!.annotations],
        i = list.indexWhere((a) => a.id == selected),
        j = i + by;
    if (i < 0 || j < 0 || j >= list.length) return;
    list.insert(j, list.removeAt(i));
    replaceStep(step!.copyWith(annotations: list));
  }

  void removeLayer() {
    replaceStep(
      step!.copyWith(
        annotations: [
          for (final a in step!.annotations)
            if (a.id != selected) a,
        ],
      ),
    );
    selected = null;
    notifyListeners();
  }

  void setProject(CaptureProject next) {
    checkpoint();
    _set(next);
  }

  void repeatMask() {
    final next = repeatProjectMask(
      project,
      step!.id,
      selected!,
      newLayerId: () => captureId('mask'),
    );
    checkpoint();
    _set(next);
  }

  void saved(CaptureProject next) {
    project = next;
    dirty = false;
    notifyListeners();
  }

  @override
  void dispose() {
    title.removeListener(_titled);
    title.dispose();
    zoom.dispose();
    draft?.dispose();
    super.dispose();
  }
}
