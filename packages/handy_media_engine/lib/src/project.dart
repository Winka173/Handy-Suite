import 'dart:convert';
import 'dart:math' as math;

const annotationKinds = [
  'arrow',
  'rect',
  'ellipse',
  'highlight',
  'redact',
  'text',
  'step',
  'pen',
  'spotlight',
];
Map<String, dynamic> _object(dynamic v, List<String> keys) {
  if (v is! Map<String, dynamic> || v.keys.any((k) => !keys.contains(k)))
    throw const FormatException('Unknown or invalid project fields');
  return v;
}

String _text(dynamic v, int max, {bool multiline = false}) {
  if (v is! String ||
      v.length > max ||
      (multiline
              ? RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]')
              : RegExp(r'[\x00-\x1f\x7f]'))
          .hasMatch(v))
    throw const FormatException('Invalid project text');
  return v;
}

String _id(dynamic v) {
  final s = _text(v, 100);
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$').hasMatch(s))
    throw const FormatException('Invalid project ID');
  return s;
}

double _number(dynamic v, double low, double high) {
  if (v is! num || !v.isFinite || v < low || v > high)
    throw const FormatException('Invalid project coordinate');
  return v.toDouble();
}

List<dynamic> _list(dynamic v, int max) {
  if (v is! List || v.length > max)
    throw const FormatException('Project list limit exceeded');
  return v;
}

void _unique(Iterable<String> ids) {
  final list = ids.toList();
  if (list.toSet().length != list.length)
    throw const FormatException('Duplicate project IDs');
}

String _date(dynamic v) {
  final s = _text(v, 30), date = DateTime.tryParse(s);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$').hasMatch(s) ||
      date == null ||
      date.toUtc().toIso8601String() != s)
    throw const FormatException('Invalid project timestamp');
  return s;
}

String projectImageUri(dynamic value) {
  final s = _text(value, 2048);
  if (!RegExp(r'^(file:///|content://[^/]+/)').hasMatch(s) ||
      RegExp(r'[?#\\]').hasMatch(s))
    throw const FormatException('Local image URI required');
  String decoded;
  try {
    decoded = Uri.decodeComponent(s);
  } catch (_) {
    throw const FormatException('Malformed image URI');
  }
  if (RegExp(r'[\x00-\x1f\x7f\\]').hasMatch(decoded) ||
      decoded.split('/').any((s) => s == '.' || s == '..'))
    throw const FormatException('Unsafe image URI');
  return s;
}

class ProjectPoint {
  final double x, y;
  const ProjectPoint(this.x, this.y);
  factory ProjectPoint.parse(dynamic raw) {
    final v = _object(raw, ['x', 'y']);
    return ProjectPoint(_number(v['x'], 0, 1), _number(v['y'], 0, 1));
  }
  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

class LayerGeometry {
  final double x, y, width, height;
  const LayerGeometry(this.x, this.y, this.width, this.height);
  void validate() {
    for (final n in [x, y, width, height]) {
      _number(n, 0, 1);
    }
    if (x + width > 1.000000001 || y + height > 1.000000001)
      throw const FormatException('Layer exceeds image bounds');
  }

  LayerGeometry clamped() {
    if (![x, y, width, height].every((n) => n.isFinite))
      throw const FormatException('Nonfinite geometry');
    final a = x.clamp(0.0, 1.0), b = y.clamp(0.0, 1.0);
    return LayerGeometry(
      a,
      b,
      width.clamp(0.0, 1 - a),
      height.clamp(0.0, 1 - b),
    );
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

class ProjectLayer {
  final String id, kind, color, text;
  final LayerGeometry geometry;
  final List<ProjectPoint>? points;
  ProjectLayer({
    required this.id,
    required this.kind,
    required this.geometry,
    this.color = '#EA580C',
    this.text = '',
    List<ProjectPoint>? points,
  }) : points = points == null ? null : List.unmodifiable(points);
  factory ProjectLayer.parse(dynamic raw) {
    final v = _object(raw, [
      'id',
      'kind',
      'x',
      'y',
      'width',
      'height',
      'color',
      'text',
      'points',
    ]);
    final g = LayerGeometry(
      _number(v['x'], 0, 1),
      _number(v['y'], 0, 1),
      _number(v['width'], 0, 1),
      _number(v['height'], 0, 1),
    );
    g.validate();
    if (!annotationKinds.contains(v['kind']) ||
        v['color'] is! String ||
        !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v['color']))
      throw const FormatException('Invalid annotation kind/color');
    final points = v.containsKey('points')
        ? _list(v['points'], 2000).map(ProjectPoint.parse).toList()
        : null;
    if (v['kind'] == 'arrow' && points != null && points.length != 2 ||
        v['kind'] == 'pen' && (points == null || points.length < 2))
      throw const FormatException('Invalid stroke points');
    if (!['arrow', 'pen'].contains(v['kind']) &&
        (g.width == 0 || g.height == 0))
      throw const FormatException('Layer needs visible area');
    return ProjectLayer(
      id: _id(v['id']),
      kind: v['kind'],
      geometry: g,
      color: v['color'],
      text: _text(v['text'], 500, multiline: true),
      points: points,
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    ...geometry.toJson(),
    'color': color,
    'text': text,
    if (points != null) 'points': [for (final p in points!) p.toJson()],
  };
  ProjectLayer copyWith({
    LayerGeometry? geometry,
    String? color,
    String? text,
  }) {
    final next = geometry ?? this.geometry, old = this.geometry;
    final mapped = points == null
        ? null
        : [
            for (final p in points!)
              ProjectPoint(
                (old.width > 0
                        ? next.x + (p.x - old.x) * next.width / old.width
                        : p.x + next.x - old.x)
                    .clamp(0, 1),
                (old.height > 0
                        ? next.y + (p.y - old.y) * next.height / old.height
                        : p.y + next.y - old.y)
                    .clamp(0, 1),
              ),
          ];
    return ProjectLayer.parse({
      ...toJson(),
      ...next.toJson(),
      'color': color ?? this.color,
      'text': text ?? this.text,
      if (mapped != null) 'points': [for (final p in mapped) p.toJson()],
    });
  }
}

class ProjectStep {
  final String id, title, body, imageUri;
  final int imageWidth, imageHeight;
  final List<ProjectLayer> annotations;
  ProjectStep({
    required this.id,
    required this.title,
    required this.body,
    required this.imageUri,
    required this.imageWidth,
    required this.imageHeight,
    List<ProjectLayer> annotations = const [],
  }) : annotations = List.unmodifiable(annotations);
  factory ProjectStep.parse(dynamic raw) {
    final v = _object(raw, [
      'id',
      'title',
      'body',
      'imageUri',
      'imageWidth',
      'imageHeight',
      'annotations',
    ]);
    final w = _number(v['imageWidth'], 1, 16384),
        h = _number(v['imageHeight'], 1, 16384);
    if (w != w.roundToDouble() || h != h.roundToDouble() || w * h > 32000000)
      throw const FormatException('Image exceeds legacy 32Mpx limits');
    final layers = _list(
      v['annotations'],
      100,
    ).map(ProjectLayer.parse).toList();
    _unique(layers.map((l) => l.id));
    return ProjectStep(
      id: _id(v['id']),
      title: _text(v['title'], 200),
      body: _text(v['body'], 4000, multiline: true),
      imageUri: projectImageUri(v['imageUri']),
      imageWidth: w.toInt(),
      imageHeight: h.toInt(),
      annotations: layers,
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'imageUri': imageUri,
    'imageWidth': imageWidth,
    'imageHeight': imageHeight,
    'annotations': [for (final a in annotations) a.toJson()],
  };
  ProjectStep copyWith({
    String? title,
    String? body,
    String? imageUri,
    List<ProjectLayer>? annotations,
  }) => ProjectStep.parse({
    ...toJson(),
    'title': title ?? this.title,
    'body': body ?? this.body,
    'imageUri': imageUri ?? this.imageUri,
    'annotations': [
      for (final a in annotations ?? this.annotations) a.toJson(),
    ],
  });
}

class CaptureProject {
  final String id, title, kind, createdAt, updatedAt;
  final List<String> tags;
  final List<ProjectStep> steps;
  final Map<String, String> bug;
  CaptureProject._(
    this.id,
    this.title,
    this.kind,
    this.createdAt,
    this.updatedAt,
    this.tags,
    this.steps,
    this.bug,
  );
  factory CaptureProject.parse(dynamic raw) {
    final v = _object(raw, [
      'version',
      'id',
      'title',
      'kind',
      'tags',
      'createdAt',
      'updatedAt',
      'steps',
      'bug',
    ]);
    if (v['version'] != 1 ||
        !['guide', 'bug', 'comparison'].contains(v['kind']))
      throw const FormatException('Unsupported Snap project');
    final b = _object(v['bug'], [
          'environment',
          'expected',
          'actual',
          'reproduction',
        ]),
        steps = _list(v['steps'], 100).map(ProjectStep.parse).toList();
    _unique(steps.map((s) => s.id));
    final project = CaptureProject._(
      _id(v['id']),
      _text(v['title'], 200),
      v['kind'],
      _date(v['createdAt']),
      _date(v['updatedAt']),
      List.unmodifiable(_list(v['tags'], 32).map((t) => _text(t, 40))),
      List.unmodifiable(steps),
      Map.unmodifiable({
        for (final k in ['environment', 'expected', 'actual', 'reproduction'])
          k: _text(b[k], k == 'reproduction' ? 8000 : 4000, multiline: true),
      }),
    );
    if (utf8.encode(jsonEncode(project.toJson())).length > 2000000)
      throw const FormatException('Project exceeds 2 MB');
    return project;
  }
  factory CaptureProject.fromText(String text) {
    if (utf8.encode(text).length > 2000000)
      throw const FormatException('Project exceeds 2 MB');
    return CaptureProject.parse(jsonDecode(text));
  }
  factory CaptureProject.create(
    String id, {
    String title = '',
    String kind = 'guide',
  }) {
    final date = DateTime.now().toUtc();
    final now =
        '${date.toIso8601String().split('.').first}.${date.millisecond.toString().padLeft(3, '0')}Z';
    return CaptureProject.parse({
      'version': 1,
      'id': id,
      'title': title,
      'kind': kind,
      'tags': <String>[],
      'createdAt': now,
      'updatedAt': now,
      'steps': <dynamic>[],
      'bug': {
        'environment': '',
        'expected': '',
        'actual': '',
        'reproduction': '',
      },
    });
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'title': title,
    'kind': kind,
    'tags': tags.toList(),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'steps': [for (final s in steps) s.toJson()],
    'bug': Map.of(bug),
  };
  String serialize() => jsonEncode(toJson());
  CaptureProject copyWith({
    String? title,
    String? kind,
    List<String>? tags,
    Map<String, String>? bug,
    List<ProjectStep>? steps,
  }) {
    final date = DateTime.now().toUtc();
    final now =
        '${date.toIso8601String().split('.').first}.${date.millisecond.toString().padLeft(3, '0')}Z';
    return CaptureProject.parse({
      ...toJson(),
      'title': title ?? this.title,
      'kind': kind ?? this.kind,
      'tags': tags ?? this.tags,
      'bug': bug ?? this.bug,
      'updatedAt': now,
      'steps': [for (final s in steps ?? this.steps) s.toJson()],
    });
  }
}

/// Existing Snap behavior: repeat an opaque mask at the same relative region.
/// Every target is validated before a new project is returned; inputs stay intact.
CaptureProject repeatProjectMask(
  CaptureProject input,
  String stepId,
  String layerId, {
  required String Function() newLayerId,
}) {
  final project = CaptureProject.parse(input.toJson());
  final step = project.steps.where((s) => s.id == stepId).firstOrNull;
  final mask = step?.annotations
      .where((a) => a.id == layerId && a.kind == 'redact')
      .firstOrNull;
  if (step == null || mask == null)
    throw const FormatException('Select a redaction mask first');
  final steps = [
    for (final s in project.steps)
      if (s.id == stepId)
        s
      else
        s.copyWith(
          annotations: [
            ...s.annotations,
            ProjectLayer(
              id: newLayerId(),
              kind: 'redact',
              color: '#000000',
              geometry: mask.geometry,
            ),
          ],
        ),
  ];
  return project.copyWith(steps: steps);
}

ProjectLayer defaultLayer(String id, String kind, {int step = 1}) =>
    ProjectLayer.parse({
      'id': id,
      'kind': kind,
      'x': 0.2,
      'y': 0.2,
      'width': 0.35,
      'height': 0.15,
      'color': '#EA580C',
      'text': kind == 'text'
          ? 'Note'
          : kind == 'step'
          ? '$step'
          : '',
      if (kind == 'pen')
        'points': [
          {'x': 0.2, 'y': 0.2},
          {'x': 0.55, 'y': 0.35},
        ],
    });
LayerGeometry alignLayer(LayerGeometry geometry, String alignment) {
  geometry.validate();
  return switch (alignment) {
    'left' => LayerGeometry(0, geometry.y, geometry.width, geometry.height),
    'center' => LayerGeometry(
      (1 - geometry.width) / 2,
      geometry.y,
      geometry.width,
      geometry.height,
    ),
    'right' => LayerGeometry(
      1 - geometry.width,
      geometry.y,
      geometry.width,
      geometry.height,
    ),
    'top' => LayerGeometry(geometry.x, 0, geometry.width, geometry.height),
    'middle' => LayerGeometry(
      geometry.x,
      (1 - geometry.height) / 2,
      geometry.width,
      geometry.height,
    ),
    'bottom' => LayerGeometry(
      geometry.x,
      1 - geometry.height,
      geometry.width,
      geometry.height,
    ),
    _ => throw const FormatException('Unknown alignment'),
  };
}

LayerGeometry layerBounds(ProjectLayer layer) {
  if (layer.points == null || layer.points!.isEmpty) return layer.geometry;
  final xs = layer.points!.map((p) => p.x),
      ys = layer.points!.map((p) => p.y),
      x = xs.reduce(math.min),
      y = ys.reduce(math.min);
  return LayerGeometry(x, y, xs.reduce(math.max) - x, ys.reduce(math.max) - y);
}
