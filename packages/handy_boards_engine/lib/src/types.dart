part of '../handy_boards_engine.dart';

/// Four kinds of board on one Kanban engine. Each adds one structured
/// module the others do not have:
///
/// * `standard`: the neutral Kanban baseline;
/// * `study`: subjects (a category plus its `subjects` row: code, credits),
///   a weekly timetable (`classes` rows) inside the board's term, and exams
///   (a card with an `exam` entry: its day, time and room, never its due);
/// * `shopping`: products on cards (`product`: price in minor units,
///   currency, quantity, store, link, size for unit prices), a board budget,
///   and column stages that say what counts as bought;
/// * `content`: posts on cards (`post`: format, platforms, the planned
///   publish time and the published records the person typed in), and
///   column stages that tell scheduled from published.
///
/// A board without `type` is a standard board: older boards never change
/// kind on their own.
const boardTypes = ['standard', 'study', 'shopping', 'content'];

/// Kinds whose creation needs Pro. A board that exists stays fully usable
/// whatever the entitlement says.
const proBoardTypes = {'shopping', 'content'};

String boardType(BoardRecord board) {
  final t = board.data['type'];
  return boardTypes.contains(t) ? t as String : 'standard';
}

String boardTypeOf(BoardsState s, String board) =>
    boardType(s.get('boards', board));

/// Column stages of the kinds that need them, in workflow order.
const columnStages = {
  'shopping': ['want', 'ordered', 'received', 'cancelled'],
  'content': ['idea', 'making', 'ready', 'published'],
};

/// The stage of a column on a shopping or content board (null elsewhere).
/// A column without one is read from its finished flag: finished columns
/// count as received or published, the others as want or idea.
String? stageOf(BoardsState s, BoardRecord column) {
  final stages = columnStages[boardTypeOf(s, column.str('board'))];
  if (stages == null) return null;
  final v = column.data['stage'];
  if (stages.contains(v)) return v as String;
  if (!column.flag('done')) return stages[0];
  return stages.contains('received') ? 'received' : 'published';
}

String? cardStage(BoardsState s, BoardRecord card) =>
    stageOf(s, s.get('statuses', card.str('status')));

BoardsState setColumnStage(BoardsState s, String column, String stage) {
  final c = s.get('statuses', column);
  final stages = columnStages[boardTypeOf(s, c.str('board'))];
  if (stages == null || !stages.contains(stage))
    throw const FormatException('Stage not on this board');
  return s.put('statuses', c.copy({'stage': stage}));
}

/// Opt-in: a standard board becomes a study board. Nothing else changes;
/// its categories become its subjects. Other conversions are not offered.
BoardsState convertToStudy(BoardsState s, String board, {DateTime? now}) {
  final b = s.get('boards', board);
  if (boardType(b) != 'standard')
    throw const FormatException('Only a standard board converts');
  return s.put('boards', b.copy({'type': 'study', 'updated': _now(now)}));
}

String _two(int v) => v.toString().padLeft(2, '0');
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';
String clock(int minute) => '${_two(minute ~/ 60)}:${_two(minute % 60)}';

/// A stored calendar day as a local date (no time zone shift).
DateTime localDate(String iso) {
  final d = calendarDate(iso);
  return DateTime(d.year, d.month, d.day);
}

// ─── Study ───────────────────────────────────────────────────────────────

/// A subject's extra fields (code, credits), kept on its category's
/// `subjects` row. The category is the subject: one name, one colour.
BoardRecord? subjectOf(BoardsState s, String category) =>
    s.related('subjects', category, field: 'category').firstOrNull;

BoardsState saveSubject(
  BoardsState s,
  String category, {
  String code = '',
  int credits = 0,
}) {
  final c = s.get('categories', category);
  if (boardTypeOf(s, c.str('board')) != 'study')
    throw const FormatException('Subjects live on study boards');
  text(code, max: 40);
  if (credits < 0 || credits > 60) throw const FormatException('Credits 0..60');
  final old = subjectOf(s, category);
  return s.put(
    'subjects',
    BoardRecord({
      'id': old?.id ?? newId(),
      'board': c.str('board'),
      'category': category,
      'code': code.trim(),
      'credits': credits,
    }),
  );
}

/// The term the timetable repeats in, as calendar days, or null when the
/// person has not set one (then classes repeat every week).
({DateTime start, DateTime end})? termOf(BoardRecord board) {
  final t = board.data['term'];
  if (t is! Map) return null;
  return (
    start: localDate(t['start'] as String),
    end: localDate(t['end'] as String),
  );
}

BoardsState setTerm(
  BoardsState s,
  String board,
  DateTime? start,
  DateTime? end, {
  DateTime? now,
}) {
  final b = s.get('boards', board);
  if ((start == null) != (end == null))
    throw const FormatException('A term needs both days');
  if (start != null &&
      (end!.isBefore(start) || end.difference(start).inDays > 400))
    throw const FormatException('A term is up to 400 days');
  return s.put(
    'boards',
    b.copy({
      'term': start == null
          ? null
          : {'start': isoDay(start), 'end': isoDay(end!)},
      'updated': _now(now),
    }),
  );
}

/// The board's weekly classes, Monday first, then by start time.
List<BoardRecord> classesOf(BoardsState s, String board) =>
    s.rows('classes').where((c) => c.str('board') == board).toList()
      ..sort((a, b) {
        final d = a.number('weekday').compareTo(b.number('weekday'));
        return d != 0
            ? d
            : a.number('startMinute').compareTo(b.number('startMinute'));
      });

/// Adds or changes a weekly class: [weekday] 1 (Monday) to 7, minutes
/// after midnight, the subject (a category of the same study board) and an
/// optional room.
BoardsState saveClass(
  BoardsState s, {
  String? id,
  required String board,
  required String category,
  required int weekday,
  required int startMinute,
  required int endMinute,
  String room = '',
}) {
  if (boardTypeOf(s, board) != 'study')
    throw const FormatException('Timetables live on study boards');
  if (s.get('categories', category).str('board') != board)
    throw const FormatException('Subject outside board');
  text(room, max: 200);
  if (weekday < 1 ||
      weekday > 7 ||
      startMinute < 0 ||
      endMinute > 1440 ||
      endMinute <= startMinute)
    throw const FormatException('Invalid class time');
  final b = s.get('boards', board);
  return s.put(
    'classes',
    BoardRecord({
      'id': id ?? newId(),
      'board': board,
      'category': category,
      'weekday': weekday,
      'startMinute': startMinute,
      'endMinute': endMinute,
      'room': room.trim(),
      'zone': b.str('zone', 'Asia/Ho_Chi_Minh'),
    }),
  );
}

BoardsState deleteClass(BoardsState s, String id) {
  s.get('classes', id);
  return s.remove('classes', {id});
}

bool _inTerm(BoardRecord board, DateTime day) {
  final term = termOf(board);
  return term == null || (!day.isBefore(term.start) && !day.isAfter(term.end));
}

/// The classes held on [day] (a calendar day), by start time.
List<BoardRecord> classesOn(BoardsState s, String board, DateTime day) {
  if (!_inTerm(s.get('boards', board), day)) return const [];
  return [
    for (final c in classesOf(s, board))
      if (c.number('weekday') == day.weekday) c,
  ];
}

/// The next class from [now]: today's later ones, then the coming days
/// (two weeks ahead at most), with the moment it starts.
({BoardRecord session, DateTime start})? nextClass(
  BoardsState s,
  String board,
  DateTime now,
) {
  for (var i = 0; i < 15; i++) {
    final day = DateTime(now.year, now.month, now.day + i);
    for (final c in classesOn(s, board, day)) {
      final start = day.add(Duration(minutes: c.number('startMinute')));
      final end = day.add(Duration(minutes: c.number('endMinute')));
      if (end.isAfter(now)) return (session: c, start: start);
    }
  }
  return null;
}

/// An exam's moment in the board's own calendar: its day at its time, or
/// the start of its day when it has no time.
DateTime? examMoment(BoardRecord card) {
  final e = card.data['exam'];
  if (e is! Map || e['day'] == null) return null;
  final d = localDate(e['day'] as String);
  final time = e['time'] as String?;
  if (time == null) return d;
  final p = time.split(':');
  return DateTime(d.year, d.month, d.day, int.parse(p[0]), int.parse(p[1]));
}

/// The board's exams (active cards with an exam), soonest first; with
/// [from], only those on or after that day.
List<BoardRecord> examsOf(BoardsState s, String board, {DateTime? from}) {
  final start = from == null ? null : DateTime(from.year, from.month, from.day);
  return [
    for (final t in topTasks(s, board: board))
      if (examMoment(t) case final at?)
        if (start == null || !at.isBefore(start)) t,
  ]..sort((a, b) => examMoment(a)!.compareTo(examMoment(b)!));
}

/// Sets (or with null removes) the exam entry of a card on a study board.
/// The card's due date is left alone: an exam's moment is not a deadline.
BoardsState setExam(
  BoardsState s,
  String card, {
  required DateTime? day,
  int? minute,
  String location = '',
  DateTime? now,
}) {
  final t = s.get('tasks', card);
  if (boardTypeOf(s, t.str('board')) != 'study')
    throw const FormatException('Exams live on study boards');
  text(location, max: 200);
  return s.put(
    'tasks',
    t.copy({
      'exam': day == null
          ? null
          : {
              'day': isoDay(day),
              if (minute != null) 'time': clock(minute),
              if (location.trim().isNotEmpty) 'location': location.trim(),
            },
      'updated': _now(now),
    }),
  );
}

/// A new exam: a card in the board's first column with the exam entry.
BoardsState addExam(
  BoardsState s,
  String board, {
  required String title,
  required String? category,
  required DateTime day,
  int? minute,
  String location = '',
  DateTime? now,
  String? id,
}) {
  text(title, empty: false);
  final first = columnsOf(s, board).first;
  final card = newTask(
    s,
    board,
    title.trim(),
    category: category,
  ).copy({'id': ?id, 'status': first.id, 'order': -1});
  final next = saveTask(s, card, now: now);
  return setExam(
    next,
    card.id,
    day: day,
    minute: minute,
    location: location,
    now: now,
  );
}

/// One reminder per card at [at] (null takes it off): what the card's
/// Remind chip, an exam and a scheduled post all set, so a card never
/// rings twice.
BoardsState setReminderAt(BoardsState s, String card, DateTime? at) {
  final t = s.get('tasks', card);
  final old = s.related('reminders', card).map((r) => r.id).toSet();
  var next = old.isEmpty ? s : s.remove('reminders', old);
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

// ─── Shopping ────────────────────────────────────────────────────────────

/// Currencies a price can be in, with their minor-unit digits.
const currencyDigits = {
  'VND': 0,
  'USD': 2,
  'EUR': 2,
  'JPY': 0,
  'KRW': 0,
  'THB': 2,
  'SGD': 2,
};

const productUnits = ['g', 'kg', 'ml', 'l', 'pcs'];

/// Reads typed money ("1.250.000", "12,50", "1,250,000.5") as minor units
/// of [currency]; null when it is not a price.
int? parseMoney(String input, String currency) {
  final digits = currencyDigits[currency] ?? 0;
  var v = input.trim().replaceAll(RegExp(r'[^\d.,]'), '');
  if (v.isEmpty) return null;
  String whole = v, part = '';
  if (digits > 0) {
    final m = RegExp(r'[.,](\d{1,2})$').firstMatch(v);
    if (m != null) {
      whole = v.substring(0, m.start);
      part = m[1]!;
    }
  }
  whole = whole.replaceAll(RegExp(r'[.,]'), '');
  if (whole.isEmpty) whole = '0';
  if (whole.length > 13) return null;
  final minor =
      int.parse(whole) * _pow10(digits) +
      (part.isEmpty ? 0 : int.parse(part.padRight(digits, '0')));
  return minor;
}

int _pow10(int n) => n == 0 ? 1 : 10 * _pow10(n - 1);

/// Money for people: "1.250.000 đ" / "1,250,000 ₫"-free "$12.50" style,
/// grouped by the language's separator.
String moneyText(int minor, String currency, {bool vi = true}) {
  final digits = currencyDigits[currency] ?? 0;
  final negative = minor < 0;
  final abs = minor.abs();
  final whole = (abs ~/ _pow10(digits)).toString();
  final group = vi ? '.' : ',', point = vi ? ',' : '.';
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(group);
    buf.write(whole[i]);
  }
  if (digits > 0)
    buf
      ..write(point)
      ..write((abs % _pow10(digits)).toString().padLeft(digits, '0'));
  final n = '${negative ? '−' : ''}$buf';
  return switch (currency) {
    'VND' => '$n đ',
    'USD' => vi ? '$n US\$' : '\$$n',
    'EUR' => '$n €',
    _ => '$n $currency',
  };
}

/// The product entry of a card, or null.
Json? productOf(BoardRecord card) {
  final p = card.data['product'];
  return p is Map ? Map<String, dynamic>.from(p) : null;
}

/// Sets (or with null removes) a card's product. [price] is in minor
/// units of [currency] and may be missing ("no price yet").
BoardsState setProduct(
  BoardsState s,
  String card, {
  int? price,
  String currency = 'VND',
  int qty = 1,
  String store = '',
  String url = '',
  num? size,
  String? unit,
  bool remove = false,
  DateTime? now,
}) {
  final t = s.get('tasks', card);
  if (boardTypeOf(s, t.str('board')) != 'shopping')
    throw const FormatException('Products live on shopping boards');
  return s.put(
    'tasks',
    t.copy({
      'product': remove
          ? null
          : {
              'price': ?price,
              'currency': currency,
              'qty': qty,
              if (store.trim().isNotEmpty) 'store': store.trim(),
              if (url.trim().isNotEmpty) 'url': url.trim(),
              'size': ?size,
              'unit': ?unit,
            },
      'updated': _now(now),
    }),
  );
}

/// The board's budget, or null.
({int amount, String currency})? budgetOf(BoardRecord board) {
  final b = board.data['budget'];
  if (b is! Map) return null;
  return (amount: b['amount'] as int, currency: b['currency'] as String);
}

BoardsState setBudget(
  BoardsState s,
  String board, {
  int? amount,
  String currency = 'VND',
  DateTime? now,
}) {
  final b = s.get('boards', board);
  if (boardType(b) != 'shopping')
    throw const FormatException('Budgets live on shopping boards');
  return s.put(
    'boards',
    b.copy({
      'budget': amount == null
          ? null
          : {'amount': amount, 'currency': currency},
      'updated': _now(now),
    }),
  );
}

/// Money on one shopping board, per currency: [planned] is every product
/// not cancelled, [spent] those in ordered or received columns, [toBuy]
/// the rest. Products without a price are counted in [unpriced] only.
class ShoppingTotals {
  final Map<String, ({int planned, int spent, int toBuy})> byCurrency;
  final int products, unpriced;
  final ({int amount, String currency})? budget;
  const ShoppingTotals(
    this.byCurrency,
    this.products,
    this.unpriced,
    this.budget,
  );

  /// Budget minus what was spent in the budget's currency.
  int? get left => budget == null
      ? null
      : budget!.amount - (byCurrency[budget!.currency]?.spent ?? 0);
}

ShoppingTotals shoppingTotals(BoardsState s, String board) {
  final sums = <String, ({int planned, int spent, int toBuy})>{};
  var products = 0, unpriced = 0;
  for (final t in topTasks(s, board: board)) {
    final p = productOf(t);
    if (p == null) continue;
    final stage = cardStage(s, t);
    if (stage == 'cancelled') continue;
    products++;
    final price = p['price'] as int?;
    if (price == null) {
      unpriced++;
      continue;
    }
    final amount = price * (p['qty'] as int? ?? 1);
    final c = p['currency'] as String? ?? 'VND';
    final old = sums[c] ?? (planned: 0, spent: 0, toBuy: 0);
    final bought = stage == 'ordered' || stage == 'received';
    sums[c] = (
      planned: old.planned + amount,
      spent: old.spent + (bought ? amount : 0),
      toBuy: old.toBuy + (bought ? 0 : amount),
    );
  }
  return ShoppingTotals(
    sums,
    products,
    unpriced,
    budgetOf(s.get('boards', board)),
  );
}

/// The price of one unit of size (per 1 g, ml or piece; kg and l are
/// turned into g and ml), in minor units, or null without price or size.
double? unitPrice(Json product) {
  final price = product['price'] as int?, size = product['size'] as num?;
  if (price == null || size == null || size <= 0) return null;
  final scale = switch (product['unit']) {
    'kg' || 'l' => 1000,
    _ => 1,
  };
  return price / (size * scale);
}

// ─── Content ─────────────────────────────────────────────────────────────

const postFormats = ['video', 'image', 'post', 'story', 'other'];
const postPlatforms = ['tiktok', 'instagram', 'youtube', 'facebook', 'other'];

Json? postOf(BoardRecord card) {
  final p = card.data['post'];
  return p is Map ? Map<String, dynamic>.from(p) : null;
}

/// Sets (or removes) a card's post: format, platforms, planned publish
/// moment and caption. Published records are kept as they were.
BoardsState setPost(
  BoardsState s,
  String card, {
  String format = 'video',
  List<String> platforms = const [],
  DateTime? scheduleAt,
  String caption = '',
  bool remove = false,
  DateTime? now,
}) {
  final t = s.get('tasks', card);
  if (boardTypeOf(s, t.str('board')) != 'content')
    throw const FormatException('Posts live on content boards');
  final old = postOf(t);
  return s.put(
    'tasks',
    t.copy({
      'post': remove
          ? null
          : {
              'format': format,
              'platforms': platforms,
              if (scheduleAt != null)
                'scheduleAt': scheduleAt.toUtc().toIso8601String(),
              if (caption.trim().isNotEmpty) 'caption': caption.trim(),
              'published': old?['published'] ?? const [],
            },
      'updated': _now(now),
    }),
  );
}

/// Records that a post went out: when (the real moment, which the person
/// may change) and, if they paste it, its public link. Nothing is fetched.
BoardsState recordPublished(
  BoardsState s,
  String card, {
  required String platform,
  required DateTime at,
  String url = '',
  DateTime? now,
}) {
  final t = s.get('tasks', card);
  final p =
      postOf(t) ??
      {
        'format': 'other',
        'platforms': [platform],
      };
  final list = [...(p['published'] as List? ?? const [])];
  if (list.length >= 20) throw const FormatException('At most 20 records');
  list.add({
    'platform': platform,
    'at': at.toUtc().toIso8601String(),
    if (url.trim().isNotEmpty) 'url': url.trim(),
  });
  return s.put(
    'tasks',
    t.copy({
      'post': {...p, 'published': list},
      'updated': _now(now),
    }),
  );
}

BoardsState removePublished(BoardsState s, String card, int index) {
  final t = s.get('tasks', card), p = postOf(t)!;
  final list = [...(p['published'] as List)]..removeAt(index);
  return s.put(
    'tasks',
    t.copy({
      'post': {...p, 'published': list},
    }),
  );
}

/// Published, scheduled or still in the making, from the column's stage
/// and the post's own fields.
String postState(BoardsState s, BoardRecord card) {
  if (cardStage(s, card) == 'published') return 'published';
  final p = postOf(card);
  if (p?['scheduleAt'] != null) return 'scheduled';
  return cardStage(s, card) ?? 'idea';
}

/// A card that sits in a published column with nothing recorded yet: the
/// app offers to note when and where it went out.
bool needsPublishRecord(BoardsState s, BoardRecord card) =>
    cardStage(s, card) == 'published' &&
    ((postOf(card)?['published'] as List?)?.isEmpty ?? true);

/// Posts still to go out, soonest first (overdue ones too).
List<BoardRecord> scheduledPosts(BoardsState s, String board) =>
    [
      for (final t in topTasks(s, board: board))
        if (postState(s, t) == 'scheduled') t,
    ]..sort(
      (a, b) => postOf(a)!['scheduleAt'].toString().compareTo(
        postOf(b)!['scheduleAt'].toString(),
      ),
    );

/// Every published record of the board, newest first.
List<({BoardRecord card, String platform, DateTime at, String? url})>
publishedRecords(BoardsState s, String board) => [
  for (final t in topTasks(s, board: board))
    for (final raw in (postOf(t)?['published'] as List? ?? const []))
      (
        card: t,
        platform: (raw as Map)['platform'] as String,
        at: DateTime.parse(raw['at'] as String),
        url: raw['url'] as String?,
      ),
]..sort((a, b) => b.at.compareTo(a.at));

// ─── Shared rules ────────────────────────────────────────────────────────

/// What a copy of a card keeps of its module: a product goes back to the
/// first column that is not bought (a copy is never money spent), a post
/// loses its published records and its slot, an exam stays.
Json typedCopy(BoardsState s, BoardRecord card) {
  final changes = <String, dynamic>{};
  final post = postOf(card);
  if (post != null)
    changes['post'] = {...post, 'published': const [], 'scheduleAt': null}
      ..removeWhere((k, v) => v == null);
  return changes;
}

/// The column a copy of [card] starts in.
String copyColumn(BoardsState s, BoardRecord card) {
  final stage = cardStage(s, card);
  if (stage == null) return card.str('status');
  final columns = columnsOf(s, card.str('board'));
  final safe = boardTypeOf(s, card.str('board')) == 'shopping'
      ? const {'want'}
      : const {'idea', 'making', 'ready'};
  if (safe.contains(stage)) return card.str('status');
  return columns
      .firstWhere(
        (c) => safe.contains(stageOf(s, c)),
        orElse: () => columns.first,
      )
      .id;
}

/// Checks the typed fields (called from [validateKanban]).
void validateTypes(BoardsState s) {
  for (final b in s.rows('boards')) {
    final t = b.data['type'];
    if (t != null && !boardTypes.contains(t))
      throw const FormatException('Unknown board type');
    final budget = b.data['budget'];
    if (budget != null) {
      if (budget is! Map ||
          budget['amount'] is! int ||
          (budget['amount'] as int) < 0 ||
          (budget['amount'] as int) > 1000000000000000 ||
          !currencyDigits.containsKey(budget['currency']))
        throw const FormatException('Invalid budget');
    }
    final term = b.data['term'];
    if (term != null) {
      if (term is! Map) throw const FormatException('Invalid term');
      final a = calendarDate(day(term['start'] as String)),
          z = calendarDate(day(term['end'] as String));
      if (z.isBefore(a)) throw const FormatException('Invalid term');
    }
  }
  for (final c in s.rows('statuses')) {
    final stage = c.data['stage'];
    if (stage == null) continue;
    final stages = columnStages[boardTypeOf(s, c.str('board'))];
    if (stages == null || !stages.contains(stage))
      throw const FormatException('Invalid column stage');
  }
  for (final sub in s.rows('subjects')) {
    text(sub.data['code'] ?? '', max: 40);
    if (sub.number('credits') < 0 || sub.number('credits') > 60)
      throw const FormatException('Credits 0..60');
  }
  for (final c in s.rows('classes')) text(c.data['room'] ?? '', max: 200);
  for (final t in s.rows('tasks')) {
    final exam = t.data['exam'];
    if (exam is Map && exam['day'] != null) {
      day(exam['day'] as String);
      final time = exam['time'];
      if (time != null &&
          (time is! String ||
              !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)))
        throw const FormatException('Invalid exam time');
    }
    final p = t.data['product'];
    if (p != null) {
      if (p is! Map) throw const FormatException('Invalid product');
      final price = p['price'], qty = p['qty'] ?? 1, size = p['size'];
      if (price != null &&
          (price is! int || price < 0 || price > 100000000000000))
        throw const FormatException('Invalid price');
      if (qty is! int || qty < 1 || qty > 9999)
        throw const FormatException('Quantity 1..9999');
      if (!currencyDigits.containsKey(p['currency'] ?? 'VND'))
        throw const FormatException('Unknown currency');
      if (size != null && (size is! num || !size.isFinite || size <= 0))
        throw const FormatException('Invalid size');
      if (p['unit'] != null && !productUnits.contains(p['unit']))
        throw const FormatException('Invalid unit');
      text(p['store'] ?? '', max: 200);
      if (p['url'] != null) safeUrl(p['url'] as String);
    }
    final post = t.data['post'];
    if (post != null) {
      if (post is! Map || !postFormats.contains(post['format']))
        throw const FormatException('Invalid post');
      final platforms = post['platforms'] ?? const [];
      if (platforms is! List ||
          platforms.any((p) => !postPlatforms.contains(p)))
        throw const FormatException('Invalid platforms');
      if (post['scheduleAt'] != null) _instant(post['scheduleAt'] as String);
      text(post['caption'] ?? '', max: 5000);
      final published = post['published'] ?? const [];
      if (published is! List || published.length > 20)
        throw const FormatException('Invalid published records');
      for (final raw in published) {
        final r = object(raw);
        if (!postPlatforms.contains(r['platform']))
          throw const FormatException('Invalid platform');
        _instant(r['at'] as String);
        if (r['url'] != null) safeUrl(r['url'] as String);
      }
    }
  }
}
