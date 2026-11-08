part of '../handy_boards_engine.dart';

// Automation rules (Pro): small, local "when this happens to a card on this
// board, do that" rules. They extend the older `rules` records (same kind,
// same fields, still synced and backed up) and are run here, nowhere else.
//
//   {id, board, title, enabled, order, trigger, days?, when?, actions, updated}
//
// - trigger  'created' | 'moved' | 'completed' | 'due soon'
//            ('due changed' and 'opened' from older data stay valid and do
//            nothing);
// - days     for 'due soon': how many days before the deadline (0..14);
// - when     optional conditions, all must hold: {status (for 'moved': the
//            column it moved into; otherwise the column it is in), category,
//            priority (at least)};
// - actions  up to ten of {type, value}:
//            priority 0..3 · category id · checklist 'subtask title' ·
//            template card-template id (its subtasks) · suggestStatus
//            column id (move there) · remindMinutes N (a reminder N minutes
//            before the deadline, or from now without one) · notify true
//            ('due soon' only: a notification on the day, planned with the
//            other notifications, so it fires with the app closed).
//
// Guards. A rule runs once per card and event: the changes it makes never
// start other rules (one pass, no cascade). At most [ruleOpsCap] actions
// run per change. When two rules set the same field of a card, the first
// in order wins and the second is logged as skipped. Adding a subtask is
// skipped when the card already has one with that title, so a rule that
// runs on two synced devices does not add it twice. Each run is logged in
// `executions` (this device only) and is part of the same Undo step as the
// person's own change.

const ruleTriggers = ['created', 'moved', 'completed', 'due soon'];
const ruleActions = [
  'priority',
  'category',
  'checklist',
  'template',
  'suggestStatus',
  'remindMinutes',
  'notify',
];
const ruleOpsCap = 50;
const rulesPerBoard = 20;

/// The board's rules in their order.
List<BoardRecord> rulesOf(BoardsState s, String board) =>
    s.rows('rules').where((r) => r.str('board') == board).toList()
      ..sort((a, b) {
        final o = a.number('order').compareTo(b.number('order'));
        return o != 0 ? o : a.id.compareTo(b.id);
      });

/// Adds or replaces a rule (validated with the rest of the state).
BoardsState saveRule(BoardsState s, BoardRecord rule, {DateTime? now}) {
  final board = rule.str('board');
  final others = rulesOf(s, board).where((r) => r.id != rule.id).toList();
  if (s.maybe('rules', rule.id) == null && others.length >= rulesPerBoard)
    throw const FormatException('At most 20 rules per board');
  final order = s.maybe('rules', rule.id)?.data['order'] ?? others.length;
  return s.put(
    'rules',
    rule.copy({
      'order': rule.data['order'] ?? order,
      'enabled': rule.data['enabled'] ?? true,
      'updated': _now(now),
    }),
  );
}

/// Removes a rule and its log on this device.
BoardsState deleteRule(BoardsState s, String id) {
  final e = BoardsEdit(s)..remove('rules', id);
  for (final x in s.rows('executions'))
    if (x.str('rule') == id) e.remove('executions', x.id);
  return e.finish();
}

/// This device's log of a rule (or of every rule on [board]), newest first.
List<BoardRecord> ruleLog(BoardsState s, {String? rule, String? board}) {
  final rules = board == null ? null : rulesOf(s, board).map((r) => r.id);
  return s
      .rows('executions')
      .where(
        (x) =>
            (rule == null || x.str('rule') == rule) &&
            (rules == null || rules.contains(x.str('rule'))),
      )
      .toList()
    ..sort((a, b) => b.str('at').compareTo(a.str('at')));
}

/// What happened to a card between two states, as rule triggers.
List<String> _cardEvents(BoardsState before, BoardsState after, String id) {
  final a = before.maybe('tasks', id), b = after.get('tasks', id);
  if (a == null) return ['created'];
  final out = <String>[];
  if (a.str('status') != b.str('status')) out.add('moved');
  if (!completed(before, a) && completed(after, b)) out.add('completed');
  return out;
}

bool _ruleWhen(BoardsState s, BoardRecord rule, BoardRecord card) {
  final when = rule.data['when'];
  if (when is! Map) return true;
  if (when['status'] != null && card.str('status') != when['status'])
    return false;
  if (when['category'] != null && card.data['category'] != when['category'])
    return false;
  if (when['priority'] is int &&
      (card.data['priority'] as int? ?? 1) < (when['priority'] as int))
    return false;
  return true;
}

/// One planned action and whether it would do anything.
class RuleEffect {
  final String rule, card, type;
  final Object? value;

  /// Empty when it applies; otherwise why it is skipped.
  final String skipped;
  const RuleEffect(
    this.rule,
    this.card,
    this.type,
    this.value, {
    this.skipped = '',
  });
}

/// What the rules would do after the person's change from [before] to
/// [after]: only cards that change in it, only rules of their board, at
/// most [ruleOpsCap] effects. A change touching more than 25 cards (an
/// import, a restore, a new board) runs no rules.
List<RuleEffect> planRules(
  BoardsState before,
  BoardsState after, {
  Set<String>? only,
}) {
  final changed = [
    for (final t in topTasks(after))
      if (!identical(before.maybe('tasks', t.id), t)) t,
  ];
  if (changed.length > 25) return const [];
  final out = <RuleEffect>[];
  for (final card in changed) {
    if (!activeTask(card)) continue;
    final events = _cardEvents(before, after, card.id);
    if (events.isEmpty) continue;
    for (final rule in rulesOf(after, card.str('board'))) {
      if (!rule.flag('enabled') || (only != null && !only.contains(rule.id)))
        continue;
      if (!events.contains(rule.str('trigger'))) continue;
      if (!_ruleWhen(after, rule, card)) continue;
      out.addAll(_effects(after, rule, card, out));
      if (out.length >= ruleOpsCap) return out.take(ruleOpsCap).toList();
    }
  }
  return out;
}

List<RuleEffect> _effects(
  BoardsState s,
  BoardRecord rule,
  BoardRecord card,
  List<RuleEffect> earlier,
) {
  final out = <RuleEffect>[];
  bool taken(String type) => [...earlier, ...out].any(
    (e) =>
        e.card == card.id &&
        e.type == type &&
        e.skipped.isEmpty &&
        const {'priority', 'category', 'suggestStatus'}.contains(type),
  );
  final titles = {
    for (final c in s.related('checklist', card.id))
      c.str('title').trim().toLowerCase(),
  };
  for (final raw in rule.data['actions'] as List) {
    final a = object(raw);
    final type = a['type'] as String, value = a['value'];
    String skip = '';
    switch (type) {
      case 'priority':
        if (card.data['priority'] == value) skip = 'already';
      case 'category':
        if (card.data['category'] == value) skip = 'already';
      case 'suggestStatus':
        if (card.str('status') == value) skip = 'already';
      case 'checklist':
        if (titles.contains('$value'.trim().toLowerCase())) skip = 'already';
      case 'template':
        if (s.maybe('templates', '$value') == null) skip = 'missing';
      case 'remindMinutes':
        if (s.related('reminders', card.id).any((r) => r.flag('enabled')))
          skip = 'already';
      case 'notify':
        continue; // planned with the notifications, not run on a change
      default:
        skip = 'unsupported';
    }
    if (skip.isEmpty && taken(type)) skip = 'another rule';
    out.add(RuleEffect(rule.id, card.id, type, value, skipped: skip));
  }
  return out;
}

/// Applies [effects] to [s] and logs them. Returns [s] itself when none
/// applies.
BoardsState applyRuleEffects(
  BoardsState s,
  List<RuleEffect> effects, {
  String trigger = '',
  Json Function(String card)? extra,
  DateTime? now,
}) {
  if (effects.isEmpty) return s;
  final at = now ?? DateTime.now();
  var next = s;
  final byRun = <(String, String), List<RuleEffect>>{};
  for (final e in effects) (byRun[(e.rule, e.card)] ??= []).add(e);
  for (final entry in byRun.entries) {
    final (ruleId, cardId) = entry.key;
    final rule = next.maybe('rules', ruleId);
    if (rule == null || next.maybe('tasks', cardId) == null) continue;
    final done = <String>[];
    for (final e in entry.value) {
      if (e.skipped.isNotEmpty) {
        done.add('${e.type}: skipped (${e.skipped})');
        continue;
      }
      final card = next.get('tasks', cardId);
      switch (e.type) {
        case 'priority':
          next = next.put('tasks', card.copy({'priority': e.value}));
        case 'category':
          if (next.maybe('categories', '${e.value}')?.str('board') ==
              card.str('board'))
            next = next.put('tasks', card.copy({'category': e.value}));
        case 'suggestStatus':
          final col = next.maybe('statuses', '${e.value}');
          if (col == null || col.str('board') != card.str('board')) continue;
          next = moveCard(next, cardId, column: col.id, index: 0, now: at);
        case 'checklist':
          next = next.put(
            'checklist',
            BoardRecord({
              'id': newId(),
              'task': cardId,
              'title': '${e.value}'.trim(),
              'done': false,
              'order': next.related('checklist', cardId).length,
            }),
          );
        case 'template':
          final tpl = next.get('templates', '${e.value}');
          final have = {
            for (final c in next.related('checklist', cardId))
              c.str('title').trim().toLowerCase(),
          };
          var i = next.related('checklist', cardId).length;
          for (final title in (tpl.data['checklist'] as List? ?? const []))
            if (have.add('$title'.trim().toLowerCase()))
              next = next.put(
                'checklist',
                BoardRecord({
                  'id': newId(),
                  'task': cardId,
                  'title': '$title',
                  'done': false,
                  'order': i++,
                }),
              );
        case 'remindMinutes':
          final minutes = e.value as int;
          final due = card.data['due'];
          DateTime base = at;
          if (due is Map && due['kind'] == 'at')
            base = DateTime.parse(due['at'] as String).toLocal();
          if (due is Map && due['kind'] == 'day') {
            final d = DateTime.parse(due['day'] as String);
            base = DateTime(d.year, d.month, d.day, 9);
          }
          var when = due == null
              ? at.add(Duration(minutes: minutes))
              : base.subtract(Duration(minutes: minutes));
          if (!when.isAfter(at)) when = at.add(const Duration(minutes: 5));
          next = next
              .copy(preferences: {...next.preferences, 'notifications': true})
              .put(
                'reminders',
                BoardRecord({
                  'id': newId(),
                  'task': cardId,
                  'board': card.str('board'),
                  'at': when.toUtc().toIso8601String(),
                  'zone': next
                      .get('boards', card.str('board'))
                      .str('zone', 'Asia/Ho_Chi_Minh'),
                  'enabled': true,
                }),
              );
      }
      done.add(e.type);
    }
    final log = BoardsEdit(next);
    log.put(
      'executions',
      BoardRecord({
        'id': newId(),
        'task': cardId,
        'rule': ruleId,
        'at': at.toUtc().toIso8601String(),
        'trigger': trigger.isEmpty ? rule.str('trigger') : trigger,
        'steps': done,
        ...?extra?.call(cardId),
      }),
    );
    if (done.any((d) => !d.contains('skipped')))
      log.event(cardId, 'automation', at, details: {'rule': rule.str('title')});
    next = log.finish();
  }
  return next;
}

/// Runs the rules for the person's change from [before] to [after].
BoardsState runRules(BoardsState before, BoardsState after, {DateTime? now}) {
  if (!after.rows('rules').any((r) => r.flag('enabled'))) return after;
  return applyRuleEffects(after, planRules(before, after), now: now);
}

/// Cards a 'due soon' [rule] covers today: open, on its board, matching its
/// conditions, with a deadline within its days.
List<BoardRecord> dueSoonCards(BoardsState s, BoardRecord rule, DateTime now) {
  final today = calendarDay(now), days = rule.number('days');
  return [
    for (final c in topTasks(s))
      if (c.str('board') == rule.str('board') &&
          isOpenCard(s, c) &&
          _ruleWhen(s, rule, c))
        if (dueDay(c) case final d?)
          if (daysBetween(today, d) >= 0 && daysBetween(today, d) <= days) c,
  ];
}

/// The 'due soon' rules, on opening the app and coming back to it: each
/// card is handled once per rule and deadline (the log on this device
/// remembers it), so opening the app again changes nothing.
BoardsState runDueSoonRules(BoardsState s, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final effects = <RuleEffect>[];
  for (final rule in s.rows('rules')) {
    if (!rule.flag('enabled') || rule.str('trigger') != 'due soon') continue;
    for (final c in dueSoonCards(s, rule, at)) {
      final key = isoDay(dueDay(c)!);
      final ran = s
          .rows('executions')
          .any(
            (x) =>
                x.str('rule') == rule.id &&
                x.str('task') == c.id &&
                x.str('due') == key,
          );
      if (ran) continue;
      final list = _effects(s, rule, c, effects);
      if (list.isEmpty) continue;
      effects.addAll(list);
      if (effects.length >= ruleOpsCap) break;
    }
  }
  if (effects.isEmpty) return s;
  // Remember the deadline each run was for.
  return applyRuleEffects(
    s,
    effects,
    trigger: 'due soon',
    extra: (card) => {'due': isoDay(dueDay(s.get('tasks', card))!)},
    now: at,
  );
}

/// What a rule would do now, for the wizard's preview: for event rules the
/// cards on its board the conditions match today (the ones a move or a new
/// card would look like); for 'due soon' the cards it covers today.
List<BoardRecord> rulePreviewCards(
  BoardsState s,
  BoardRecord rule,
  DateTime now,
) => rule.str('trigger') == 'due soon'
    ? dueSoonCards(s, rule, now)
    : [
        for (final c in topTasks(s))
          if (c.str('board') == rule.str('board') &&
              activeTask(c) &&
              _ruleWhen(s, rule, c))
            c,
      ];

/// After a column or category is removed: drops the rules' actions and
/// conditions that pointed at it; a rule left with no action is turned off.
void pruneRuleRefs(BoardsEdit e, String board) {
  for (final r in e.data['rules']!.values.toList()) {
    if (r.str('board') != board) continue;
    bool gone(String kind, Object? id) =>
        id is String && !e.data[kind]!.containsKey(id);
    final actions = (r.data['actions'] as List).where((raw) {
      final a = object(raw);
      return !(a['type'] == 'category' && gone('categories', a['value']) ||
          a['type'] == 'suggestStatus' && gone('statuses', a['value']));
    }).toList();
    final when = r.data['when'] is Map
        ? Map<String, dynamic>.from(r.data['when'] as Map)
        : null;
    when?.removeWhere(
      (k, v) =>
          k == 'status' && gone('statuses', v) ||
          k == 'category' && gone('categories', v),
    );
    if (actions.length == (r.data['actions'] as List).length &&
        (when?.length ?? 0) == ((r.data['when'] as Map?)?.length ?? 0))
      continue;
    e.put(
      'rules',
      r.copy({
        'actions': actions,
        'when': when == null || when.isEmpty ? null : when,
        'enabled': actions.isNotEmpty && r.flag('enabled'),
      }),
    );
  }
}
