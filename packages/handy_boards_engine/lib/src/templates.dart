part of '../handy_boards_engine.dart';

/// Templates are creation blueprints, nothing more. Every board runs on the
/// same engine with the same features; a template only decides the first
/// title, columns (with the real finished one marked), categories, key
/// dates, time-view defaults, look and, when the person asks, a few example
/// cards. Changing or removing a template never touches a board made from
/// it: the board keeps only its id and version as provenance.

/// A text in both languages.
class L10n {
  final String en, vi;
  const L10n(this.en, this.vi);
  String of(bool vi) => vi ? this.vi : en;
}

enum TemplateGroup { study, work, personal, creative, planning }

enum FieldKind { text, chips, date, dateRange, select, toggle }

/// What an answer changes on the board. A field whose answer would change
/// nothing has no place in a template.
enum FieldRole {
  /// The board's title (a text field).
  title,

  /// One category per chip.
  categories,

  /// A key date (date) or two (dateRange) shown on the board and used as
  /// the anchor of example cards' dates.
  milestone,

  /// A toggle that keeps or drops the columns marked [TemplateColumn.onlyWith].
  optionalColumns,

  /// A select whose options carry their own column set.
  columnSet,

  /// A select whose options set compact or detailed cards.
  presentation,

  /// A select whose options set the time view's span and pin.
  timeRange,

  /// A select whose options pick which example cards are offered.
  sampleSet,
}

class SetupOption {
  final String id;
  final L10n label;
  final List<TemplateColumn>? columns;
  final String? presentation;
  final TimePreset? time;
  const SetupOption(
    this.id,
    this.label, {
    this.columns,
    this.presentation,
    this.time,
  });
}

class SetupField {
  final String id;
  final FieldKind kind;
  final FieldRole role;
  final L10n label, help;
  final L10n? placeholder;
  final bool required;

  /// text: the suggested value; chips: the suggested chips.
  final L10n? textDefault;
  final List<L10n> chipsDefault;

  /// date and dateRange start: 'today', 'weekStart' (Monday), 'monthStart',
  /// or null (empty until the person picks one).
  final String? dateDefault;

  /// dateRange: the end suggested this many days after the start (null:
  /// the end starts empty).
  final int? rangeDays;

  /// dateRange: the second date's name (the label names the first).
  final L10n? endLabel;
  final List<SetupOption> options;
  final String? optionDefault;
  final bool toggleDefault;
  final int maxChips;
  const SetupField(
    this.id,
    this.kind,
    this.role, {
    required this.label,
    required this.help,
    this.placeholder,
    this.required = false,
    this.textDefault,
    this.chipsDefault = const [],
    this.dateDefault,
    this.rangeDays,
    this.endLabel,
    this.options = const [],
    this.optionDefault,
    this.toggleDefault = true,
    this.maxChips = 12,
  });
}

class TemplateColumn {
  final L10n name;

  /// The column that means "finished" (never assumed to be the last one).
  final bool done;

  /// The id of a toggle field; the column exists only when it is on.
  final String? onlyWith;
  const TemplateColumn(this.name, {this.done = false, this.onlyWith});
}

/// How the time view starts on a new board: its span, whether its switch
/// is pinned beside the title, and whether the board opens on it.
///
/// A recommendation only: every board, from any template or blank, can
/// pin, unpin and change its range later, and the person's choice wins.
class TimePreset {
  final String unit;
  final int count;
  final bool pinned, open;

  /// Pinned only when the person gives the template one of its dates
  /// (a launch, an event, a trip): no date, nothing to look at by time.
  final bool pinIfDated;
  const TimePreset(
    this.unit, {
    this.count = 1,
    this.pinned = true,
    this.open = false,
    this.pinIfDated = false,
  });
}

class SampleCard {
  final L10n title;
  final int column;
  final int? category;
  final List<L10n> subtasks;
  final int done;
  final String? cover;

  /// Days from the anchor; no date when null or when the anchor is empty.
  final int? dueOffset;

  /// The date field it counts from ('<id>' or '<id>.end'); null = today.
  final String? anchor;

  /// Shown only with this option of the sampleSet field.
  final String? set;
  const SampleCard(
    this.title, {
    required this.column,
    this.category,
    this.subtasks = const [],
    this.done = 0,
    this.cover,
    this.dueOffset,
    this.anchor,
    this.set,
  });
}

class BoardTemplate {
  final String id;
  final int version;
  final bool pro;
  final TemplateGroup group;

  /// Shown first in the gallery, smallest first; null = not featured.
  final int? featured;
  final L10n name, goal, example;
  final List<String> tags;
  final String cover, look;
  final List<int> hues;
  final List<TemplateColumn> columns;
  final List<SetupField> fields;
  final List<SampleCard> samples;
  final TimePreset time;
  final String presentation;
  const BoardTemplate({
    required this.id,
    this.version = 1,
    required this.pro,
    required this.group,
    this.featured,
    required this.name,
    required this.goal,
    required this.example,
    this.tags = const [],
    required this.cover,
    this.look = 'default',
    this.hues = const [0, 1, 2, 4, 3, 5, 6, 7],
    required this.columns,
    required this.fields,
    this.samples = const [],
    this.time = const TimePreset('week'),
    this.presentation = 'compact',
  });

  SetupField? fieldFor(FieldRole role) =>
      fields.where((f) => f.role == role).firstOrNull;
}

BoardTemplate? templateById(String id) =>
    boardTemplates.where((t) => t.id == id).firstOrNull;

/// Answers to a template's questions, keyed by field id: text → String,
/// chips → List<String>, date → ISO day or null, dateRange → [start, end]
/// (each an ISO day or null), select → option id, toggle → bool. The key
/// [examplesKey] says whether example cards are added (off by default).
typedef TemplateAnswers = Map<String, Object?>;

const examplesKey = '_examples';

DateTime _anchorDay(String rule, DateTime now) => switch (rule) {
  'weekStart' => DateTime(now.year, now.month, now.day - (now.weekday - 1)),
  'monthStart' => DateTime(now.year, now.month),
  _ => DateTime(now.year, now.month, now.day),
};

/// The answers a template starts with, in [vi] or English.
TemplateAnswers defaultAnswers(
  BoardTemplate t, {
  required bool vi,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final a = <String, Object?>{
    examplesKey: false,
    cardFieldsKey: [
      for (var i = 0; i < templateCardFields(t.id).length; i++) i,
    ],
  };
  for (final f in t.fields) {
    a[f.id] = switch (f.kind) {
      FieldKind.text => f.textDefault?.of(vi) ?? '',
      FieldKind.chips => [for (final c in f.chipsDefault) c.of(vi)],
      FieldKind.date =>
        f.dateDefault == null
            ? null
            : isoDay(_anchorDay(f.dateDefault!, today)),
      FieldKind.dateRange => () {
        if (f.dateDefault == null) return <String?>[null, null];
        final start = _anchorDay(f.dateDefault!, today);
        return <String?>[
          isoDay(start),
          f.rangeDays == null
              ? null
              : isoDay(
                  DateTime(start.year, start.month, start.day + f.rangeDays!),
                ),
        ];
      }(),
      FieldKind.select => f.optionDefault ?? f.options.first.id,
      FieldKind.toggle => f.toggleDefault,
    };
  }
  return a;
}

/// Problems with [answers], by field id, in words a person can act on.
/// Empty when the board can be made.
Map<String, L10n> validateAnswers(BoardTemplate t, TemplateAnswers answers) {
  final errors = <String, L10n>{};
  for (final f in t.fields) {
    final v = answers[f.id];
    switch (f.kind) {
      case FieldKind.text:
        final s = (v as String? ?? '').trim();
        if (f.required && s.isEmpty)
          errors[f.id] = const L10n('Add a name.', 'Hãy đặt tên.');
        else if (s.length > 80)
          errors[f.id] = const L10n(
            'Keep it under 80 characters.',
            'Tối đa 80 ký tự.',
          );
      case FieldKind.chips:
        final list = [for (final c in (v as List? ?? const [])) '$c'.trim()];
        final seen = <String>{};
        if (list.length > f.maxChips)
          errors[f.id] = L10n(
            'At most ${f.maxChips}.',
            'Tối đa ${f.maxChips} mục.',
          );
        else if (list.any((c) => c.isEmpty || c.length > 40))
          errors[f.id] = const L10n(
            'Each name needs 1 to 40 characters.',
            'Mỗi tên cần 1–40 ký tự.',
          );
        else if (list.any((c) => !seen.add(c.toLowerCase())))
          errors[f.id] = const L10n(
            'Two have the same name.',
            'Có hai mục trùng tên.',
          );
      case FieldKind.dateRange:
        final r = (v as List?) ?? const [null, null];
        if (r[0] != null &&
            r[1] != null &&
            localDate(r[1] as String).isBefore(localDate(r[0] as String)))
          errors[f.id] = const L10n(
            'The end comes before the start.',
            'Ngày kết thúc đứng trước ngày bắt đầu.',
          );
      case FieldKind.date:
      case FieldKind.select:
      case FieldKind.toggle:
        break;
    }
  }
  return errors;
}

/// Everything a new board is made of, worked out from a template and its
/// answers (or written directly for a blank board).
class BoardPlan {
  final String title, cover, look, presentation;
  final String? template;
  final int? templateVersion;
  final List<(String, bool)> columns;
  final List<(String, int)> categories;
  final List<(String, String)> milestones;
  final TimePreset time;
  final List<PlannedCard> cards;

  /// Fields the board starts with: name, type, choices, shown on the card
  /// front. They came with the template, so they are free to fill.
  final List<(String, String, List<String>, bool)> cardFields;
  const BoardPlan({
    required this.title,
    required this.columns,
    this.cover = 'abstract.balanced-forms',
    this.look = 'default',
    this.presentation = 'compact',
    this.template,
    this.templateVersion,
    this.categories = const [],
    this.milestones = const [],
    this.time = const TimePreset('week'),
    this.cards = const [],
    this.cardFields = const [],
  });
}

class PlannedCard {
  final String title;
  final int column;
  final int? category;
  final List<String> subtasks;
  final int done;
  final String? cover;
  final String? due;
  const PlannedCard(
    this.title,
    this.column, {
    this.category,
    this.subtasks = const [],
    this.done = 0,
    this.cover,
    this.due,
  });
}

/// The board [t] makes from [answers]: titles, columns, categories, key
/// dates and, only when asked, example cards. Throws when the answers do
/// not validate.
BoardPlan planBoard(
  BoardTemplate t,
  TemplateAnswers answers, {
  required bool vi,
  DateTime? now,
}) {
  if (validateAnswers(t, answers).isNotEmpty)
    throw const FormatException('Answers need fixing');
  final today = now ?? DateTime.now();
  String? text0(FieldRole role) {
    final f = t.fieldFor(role);
    final v = f == null ? null : (answers[f.id] as String?)?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  SetupOption? option(FieldRole role) {
    final f = t.fieldFor(role);
    if (f == null) return null;
    final id = answers[f.id] as String? ?? f.optionDefault;
    return f.options.where((o) => o.id == id).firstOrNull;
  }

  var columns = option(FieldRole.columnSet)?.columns ?? t.columns;
  columns = [
    for (final c in columns)
      if (c.onlyWith == null || answers[c.onlyWith] != false) c,
  ];
  if (!columns.any((c) => c.done))
    throw StateError('Template ${t.id} has no finished column');

  final chips = t.fieldFor(FieldRole.categories);
  final names = chips == null
      ? const <String>[]
      : [for (final c in (answers[chips.id] as List? ?? const [])) '$c'.trim()];

  final milestones = <(String, String)>[];
  final dates = <String, String>{};
  for (final f in t.fields.where((f) => f.role == FieldRole.milestone)) {
    final v = answers[f.id];
    if (f.kind == FieldKind.date && v is String) {
      milestones.add((f.label.of(vi), v));
      dates[f.id] = v;
    }
    if (f.kind == FieldKind.dateRange && v is List) {
      if (v[0] is String) {
        milestones.add((f.label.of(vi), v[0] as String));
        dates[f.id] = v[0] as String;
      }
      if (v[1] is String) {
        milestones.add(((f.endLabel ?? f.label).of(vi), v[1] as String));
        dates['${f.id}.end'] = v[1] as String;
      }
    }
  }

  final cards = <PlannedCard>[];
  if (answers[examplesKey] == true) {
    final set = option(FieldRole.sampleSet)?.id;
    for (final c in t.samples) {
      if (c.set != null && c.set != set) continue;
      String? due;
      if (c.dueOffset != null) {
        final base = c.anchor == null ? isoDay(today) : dates[c.anchor];
        if (base != null) {
          final d = localDate(base);
          due = isoDay(DateTime(d.year, d.month, d.day + c.dueOffset!));
        }
      }
      cards.add(
        PlannedCard(
          c.title.of(vi),
          c.column.clamp(0, columns.length - 1),
          category: c.category != null && c.category! < names.length
              ? c.category
              : null,
          subtasks: [for (final s in c.subtasks) s.of(vi)],
          done: c.done,
          cover: c.cover,
          due: due,
        ),
      );
    }
  }

  return BoardPlan(
    title: text0(FieldRole.title) ?? t.name.of(vi),
    cover: t.cover,
    look: t.look,
    presentation:
        option(FieldRole.presentation)?.presentation ?? t.presentation,
    template: t.id,
    templateVersion: t.version,
    columns: [for (final c in columns) (c.name.of(vi), c.done)],
    categories: [
      for (var i = 0; i < names.length; i++)
        (names[i], t.hues[i % t.hues.length]),
    ],
    milestones: milestones,
    time: _timeOf(t, option(FieldRole.timeRange)?.time, dates.isNotEmpty),
    cards: cards,
    cardFields: [
      for (final (i, f) in templateCardFields(t.id).indexed)
        if ((answers[cardFieldsKey] as List? ?? const []).contains(i))
          (
            f.name.of(vi),
            f.type,
            [for (final o in f.options) o.of(vi)],
            f.onCard,
          ),
    ],
  );
}

/// The time view a template's board starts with. The Smart Setup answer
/// picks the unit (keeping the template's count for the same unit); the
/// template keeps pinning and opening, and "pin if dated" pins only when
/// one of its dates was given.
TimePreset _timeOf(BoardTemplate t, TimePreset? answer, bool dated) {
  final base = t.time;
  final unit = answer?.unit ?? base.unit;
  return TimePreset(
    unit,
    count: unit == base.unit ? base.count : (answer?.count ?? 1),
    // "Not by time" in the Smart Setup keeps the board off its timeline;
    // otherwise the template decides ("pin if dated" waits for a date).
    pinned: answer?.pinned == false
        ? false
        : (base.pinIfDated ? dated : base.pinned),
    open: base.open,
  );
}

/// A blank board: To Do / Doing / Done, or the person's own column names
/// (the last one is the finished column).
BoardPlan blankPlan({
  required String title,
  bool vi = false,
  List<String>? columns,
}) {
  final names = (columns ?? const [])
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toList();
  final list = names.length >= 2
      ? names
      : (vi
            ? const ['Cần làm', 'Đang làm', 'Xong']
            : const ['To Do', 'Doing', 'Done']);
  return BoardPlan(
    title: title,
    template: 'blank',
    templateVersion: 1,
    // Time is in the menu, a week at a time, until the person pins it.
    time: const TimePreset('week', pinned: false),
    columns: [
      for (var i = 0; i < list.length; i++) (list[i], i == list.length - 1),
    ],
  );
}

/// Makes the board of [plan] in one edit: fresh ids for everything, no
/// reference outside it. Example cards are ordinary cards.
BoardsState buildBoard(
  BoardsState s,
  BoardPlan plan, {
  DateTime? now,
  String? boardId,
}) {
  text(plan.title, empty: false, max: 200);
  final e = BoardsEdit(s),
      at = _now(now),
      b = boardId ?? newId(),
      w = s.rows('workspaces').firstOrNull?.id ?? newId();
  if (s.maybe('boards', b) != null) throw const FormatException('Board exists');
  if (s.maybe('workspaces', w) == null)
    e.put(
      'workspaces',
      BoardRecord({'id': w, 'title': 'Personal', 'created': at}),
    );
  e.put(
    'boards',
    BoardRecord({
      'id': b,
      'workspace': w,
      'title': plan.title.trim(),
      'zone': 'Asia/Ho_Chi_Minh',
      'created': at,
      'updated': at,
      'module': 'general',
      'cover': plan.cover,
      if (plan.look != 'default') 'appearance': plan.look,
      'template': plan.template ?? 'blank',
      'templateVersion': ?plan.templateVersion,
      'presentation': plan.presentation,
      'view': plan.time.open ? 'time' : 'board',
      'span': {'unit': plan.time.unit, 'count': plan.time.count},
      // A template that lives by time starts on its timeline.
      if (plan.time.pinned && timelineUnits.contains(plan.time.unit)) ...{
        'timeline': plan.time.unit,
        'timelineFloor': plan.time.unit,
      },
      'timePinned': plan.time.pinned,
      if (plan.milestones.isNotEmpty)
        'milestones': [
          for (final m in plan.milestones) {'label': m.$1, 'day': m.$2},
        ],
    }),
  );
  final columns = <String>[];
  for (var i = 0; i < plan.columns.length; i++) {
    final id = newId();
    columns.add(id);
    e.put(
      'statuses',
      BoardRecord({
        'id': id,
        'board': b,
        'title': plan.columns[i].$1,
        'order': i,
        'done': plan.columns[i].$2,
      }),
    );
  }
  final categories = <String>[];
  for (var i = 0; i < plan.categories.length; i++) {
    final id = newId();
    categories.add(id);
    e.put(
      'categories',
      BoardRecord({
        'id': id,
        'board': b,
        'title': plan.categories[i].$1,
        'order': i,
        'color': plan.categories[i].$2,
        'icon': 'folder',
        'preview': 3,
      }),
    );
  }
  for (final (i, f) in plan.cardFields.indexed) {
    if (!fieldTypes.contains(f.$2)) continue;
    e.put(
      'fields',
      BoardRecord({
        'id': newId(),
        'board': b,
        'title': text(f.$1.trim(), empty: false, max: 60),
        'type': f.$2,
        'options': f.$2 == 'single' ? f.$3 : <String>[],
        'onCard': f.$4,
        'order': i,
        // Came with the template: free to fill without Pro.
        'template': true,
      }),
    );
  }
  final done = {
    for (var i = 0; i < plan.columns.length; i++)
      if (plan.columns[i].$2) i,
  };
  for (var i = 0; i < plan.cards.length; i++) {
    final card = plan.cards[i], id = newId();
    e.put(
      'tasks',
      BoardRecord({
        'id': id,
        'board': b,
        'title': card.title,
        'notes': '',
        'category': card.category == null ? null : categories[card.category!],
        'parent': null,
        'status': columns[card.column],
        'priority': 1,
        'order': i,
        'tags': <String>[],
        'custom': <String, dynamic>{},
        'created': at,
        'updated': at,
        'completedAt': done.contains(card.column) ? at : null,
        if (card.cover != null) 'cover': 'art:${card.cover}',
        if (card.due != null) 'due': {'kind': 'day', 'day': card.due},
      }),
    );
    for (var j = 0; j < card.subtasks.length; j++)
      e.put(
        'checklist',
        BoardRecord({
          'id': newId(),
          'task': id,
          'title': card.subtasks[j],
          'order': j,
          'done': j < card.done,
          if (j < card.done) 'completedAt': at,
        }),
      );
  }
  return e.finish();
}

/// A blank Kanban board in one call (To Do / Doing / Done, or [columns]).
BoardsState createKanbanBoard(
  BoardsState s, {
  required String title,
  bool vi = false,
  DateTime? now,
  String? boardId,
  List<String>? columns,
}) => buildBoard(
  s,
  blankPlan(title: title, vi: vi, columns: columns),
  now: now,
  boardId: boardId,
);

/// A board from a template with its default answers (examples on or off).
BoardsState createFromTemplate(
  BoardsState s,
  BoardTemplate t, {
  bool vi = false,
  bool examples = false,
  TemplateAnswers? answers,
  DateTime? now,
  String? boardId,
}) {
  final a = {
    ...defaultAnswers(t, vi: vi, now: now),
    ...?answers,
    examplesKey: examples,
  };
  return buildBoard(
    s,
    planBoard(t, a, vi: vi, now: now),
    now: now,
    boardId: boardId,
  );
}

// ─── Board-level settings every board has ───────────────────────────────

/// The board's key dates (a semester end, a launch, a moving day), in
/// order. Any board can have them; templates only suggest the first ones.
List<({String label, DateTime day})> milestonesOf(BoardRecord board) {
  final raw = board.data['milestones'];
  if (raw is! List) return const [];
  return [
    for (final m in raw)
      (
        label: (m as Map)['label'] as String,
        day: localDate(m['day'] as String),
      ),
  ]..sort((a, b) => a.day.compareTo(b.day));
}

BoardsState setMilestones(
  BoardsState s,
  String board,
  List<({String label, DateTime day})> list, {
  DateTime? now,
}) {
  if (list.length > 8) throw const FormatException('At most 8 key dates');
  for (final m in list) text(m.label, empty: false, max: 80);
  final b = s.get('boards', board);
  return s.put(
    'boards',
    b.copy({
      'milestones': list.isEmpty
          ? null
          : [
              for (final m in list)
                {'label': m.label.trim(), 'day': isoDay(m.day)},
            ],
      'updated': _now(now),
    }),
  );
}

/// Whether the Board | Time switch sits beside the title (older boards:
/// yes). The time view stays reachable from the board menu either way.
bool timePinned(BoardRecord board) => board.data['timePinned'] != false;

String _two(int v) => v.toString().padLeft(2, '0');
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';
String clock(int minute) => '${_two(minute ~/ 60)}:${_two(minute % 60)}';

/// A stored calendar day as a local date (no time zone shift).
DateTime localDate(String iso) {
  final d = calendarDate(iso);
  return DateTime(d.year, d.month, d.day);
}

/// One reminder per card at [at] (null takes it off), so a card never
/// rings twice.
BoardsState setReminderAt(BoardsState s, String card, DateTime? at) {
  final t = s.get('tasks', card);
  final old = s.related('reminders', card).map((r) => r.id).toSet();
  final next = old.isEmpty ? s : s.remove('reminders', old);
  if (at == null) return next;
  return next.put(
    'reminders',
    BoardRecord({
      'id': newId(),
      'task': card,
      'board': t.str('board'),
      'at': at.toUtc().toIso8601String(),
      'zone': s.get('boards', t.str('board')).str('zone', 'Asia/Ho_Chi_Minh'),
      'enabled': true,
    }),
  );
}

/// Checks the template-era board fields (called from [validateKanban]).
/// Fields from older or newer versions that this one does not know (for
/// example a `type`, `product` or `post` from an unreleased build) are kept
/// as they are and never read.
void validateTemplateFields(BoardsState s) {
  for (final b in s.rows('boards')) {
    final m = b.data['milestones'];
    if (m != null) {
      if (m is! List || m.length > 8)
        throw const FormatException('Invalid key dates');
      for (final raw in m) {
        final x = object(raw);
        text(x['label'], max: 80, empty: false);
        day(x['day'] as String);
      }
    }
    final pinned = b.data['timePinned'];
    if (pinned != null && pinned is! bool)
      throw const FormatException('Invalid time pin');
    final version = b.data['templateVersion'];
    if (version != null && (version is! int || version < 1))
      throw const FormatException('Invalid template version');
  }
}

/// How many content templates each tier has, counted from the registry (the
/// one source for labels, the Pro page and tests).
int get freeTemplateCount => boardTemplates.where((t) => !t.pro).length;
int get proTemplateCount => boardTemplates.where((t) => t.pro).length;
