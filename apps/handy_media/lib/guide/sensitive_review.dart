import 'package:flutter/foundation.dart';
import 'package:handy_media_engine/handy_media_engine.dart';

/// The places on one step that may need hiding, while the person looks
/// them over. Nothing reaches the guide until [accepted] is applied; each
/// place starts chosen and can be turned off one by one or all together.
class SensitiveReview extends ChangeNotifier {
  final String stepId;
  final List<SensitiveFinding> findings;
  final List<bool> _chosen;

  /// The place last tapped in the list, shown chosen on the picture.
  int? focus;

  SensitiveReview(this.stepId, List<SensitiveFinding> found)
    : findings = List.unmodifiable(found),
      _chosen = List.filled(found.length, true);

  bool chosen(int i) => _chosen[i];
  int get count => _chosen.where((c) => c).length;
  bool get allChosen => count == findings.length;

  void toggle(int i) {
    _chosen[i] = !_chosen[i];
    focus = i;
    notifyListeners();
  }

  void chooseAll(bool on) {
    _chosen.fillRange(0, _chosen.length, on);
    notifyListeners();
  }

  void show(int? i) {
    focus = i;
    notifyListeners();
  }

  Iterable<SensitiveFinding> get accepted => [
    for (final (i, f) in findings.indexed)
      if (_chosen[i]) f,
  ];

  /// The id the canvas uses for proposal [i]; never saved.
  static String proposalId(int i) => 'proposal-$i';

  /// [step] as it would look: chosen places as opaque masks, the others as
  /// outlines in [hue]. For the canvas only; the guide is not touched.
  ProjectStep preview(ProjectStep step, String hue) => ProjectStep(
    id: step.id,
    title: step.title,
    body: step.body,
    imageUri: step.imageUri,
    imageWidth: step.imageWidth,
    imageHeight: step.imageHeight,
    annotations: [
      ...step.annotations,
      for (final (i, f) in findings.indexed)
        ProjectLayer(
          id: proposalId(i),
          kind: _chosen[i] ? 'redact' : 'rect',
          color: _chosen[i] ? '#000000' : hue,
          geometry: f.area,
        ),
    ],
  );
}
