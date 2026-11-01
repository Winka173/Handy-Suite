part of '../handy_spend_engine.dart';

class Account {
  final String id, name, currency, type, asOf;
  final BigInt opening;
  final bool archived, liquid;
  Account({
    required this.id,
    required this.name,
    required this.currency,
    this.type = 'cash',
    required this.opening,
    required this.asOf,
    this.archived = false,
    this.liquid = true,
  }) {
    scale(currency);
    calendar(asOf);
    if (id.isEmpty ||
        name.trim().isEmpty ||
        name.length > 512 ||
        !{
          'cash',
          'bank',
          'wallet',
          'savings',
          'credit',
          'loan',
          'other',
        }.contains(type))
      throw const FormatException('Invalid account');
  }
  bool get liability => type == 'credit' || type == 'loan';
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'currency': currency,
    'type': type,
    'opening': '$opening',
    'asOf': asOf,
    'archived': archived,
    'liquid': liquid,
  };
  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: _text(j['id']),
    name: _text(j['name']),
    currency: _text(j['currency']),
    type: _text(j['type']),
    opening: _big(j['opening']),
    asOf: _text(j['asOf']),
    archived: j['archived'] == true,
    liquid: j['liquid'] == true,
  );
}

class Category {
  final String id, name, kind, color, icon;
  final String? parent;
  final bool archived;
  Category({
    required this.id,
    required this.name,
    this.kind = 'expense',
    this.parent,
    this.color = '#A855F7',
    this.icon = 'category',
    this.archived = false,
  }) {
    if (id.isEmpty ||
        name.trim().isEmpty ||
        name.length > 512 ||
        !{'income', 'expense'}.contains(kind) ||
        !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color))
      throw const FormatException('Invalid category');
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'parent': parent,
    'color': color,
    'icon': icon,
    'archived': archived,
  };
  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: _text(j['id']),
    name: _text(j['name']),
    kind: _text(j['kind']),
    parent: j['parent'] as String?,
    color: _text(j['color']),
    icon: _text(j['icon']),
    archived: j['archived'] == true,
  );
}

class Entry {
  final String id, account, kind, when, created, payee, note, status;
  final String? category, toAccount, rate, refundOf, batch, occurrence;
  final List<String> tags;
  final BigInt amount, fee;
  final BigInt? target;
  Entry({
    required this.id,
    required this.account,
    required this.kind,
    required this.amount,
    required String when,
    String? created,
    this.payee = '',
    this.note = '',
    this.status = 'posted',
    this.category,
    this.toAccount,
    this.target,
    this.rate,
    this.refundOf,
    this.batch,
    this.occurrence,
    List<String> tags = const [],
    BigInt? fee,
  }) : when = timestamp(when),
       created = timestamp(created ?? DateTime.now().toUtc().toIso8601String()),
       fee = fee ?? BigInt.zero,
       tags = List.unmodifiable(tags) {
    if (id.isEmpty ||
        !{
          'expense',
          'income',
          'transfer',
          'adjustment',
          'refund',
        }.contains(kind) ||
        !{'posted', 'pending'}.contains(status) ||
        amount == BigInt.zero ||
        note.length > 65536 ||
        payee.length > 512 ||
        tags.length > 100 ||
        tags.any((e) => e.length > 128))
      throw const FormatException('Invalid transaction');
    if (kind == 'expense' && !amount.isNegative ||
        (kind == 'income' || kind == 'refund') && amount.isNegative ||
        this.fee.isNegative)
      throw const FormatException('Invalid amount direction');
    if (kind == 'transfer' &&
        (!amount.isNegative ||
            toAccount == null ||
            toAccount == account ||
            target == null ||
            target! <= BigInt.zero))
      throw const FormatException('Invalid linked transfer');
    if (kind != 'transfer' &&
        (toAccount != null || target != null || this.fee != BigInt.zero))
      throw const FormatException('Transfer fields on ordinary transaction');
    if (kind == 'refund' && refundOf == null)
      throw const FormatException('Refund requires original expense');
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'account': account,
    'kind': kind,
    'amount': '$amount',
    'when': when,
    'created': created,
    'payee': payee,
    'note': note,
    'status': status,
    'category': category,
    'toAccount': toAccount,
    'target': target?.toString(),
    'rate': rate,
    'refundOf': refundOf,
    'batch': batch,
    'occurrence': occurrence,
    'tags': tags,
    'fee': '$fee',
  };
  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: _text(j['id']),
    account: _text(j['account']),
    kind: _text(j['kind']),
    amount: _big(j['amount']),
    when: _text(j['when']),
    created: _text(j['created']),
    payee: _text(j['payee']),
    note: _text(j['note'], 65536),
    status: _text(j['status']),
    category: j['category'] as String?,
    toAccount: j['toAccount'] as String?,
    target: j['target'] == null ? null : _big(j['target']),
    rate: j['rate'] as String?,
    refundOf: j['refundOf'] as String?,
    batch: j['batch'] as String?,
    occurrence: j['occurrence'] as String?,
    tags: List<String>.from(j['tags'] as List? ?? []),
    fee: _big(j['fee'] ?? '0'),
  );
  Entry copy(Map<String, dynamic> changes) =>
      Entry.fromJson({...toJson(), ...changes});
}

class Budget {
  final String id, name, currency, start, end;
  final String? account, category;
  final BigInt limit;
  final bool rollover;
  Budget({
    required this.id,
    required this.name,
    required this.currency,
    required this.start,
    required this.end,
    required this.limit,
    this.account,
    this.category,
    this.rollover = false,
  }) {
    scale(currency);
    if (!calendar(end).isAfter(calendar(start)) || limit < BigInt.zero)
      throw const FormatException('Invalid budget period');
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'currency': currency,
    'start': start,
    'end': end,
    'limit': '$limit',
    'account': account,
    'category': category,
    'rollover': rollover,
  };
  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
    id: _text(j['id']),
    name: _text(j['name']),
    currency: _text(j['currency']),
    start: _text(j['start']),
    end: _text(j['end']),
    limit: _big(j['limit']),
    account: j['account'] as String?,
    category: j['category'] as String?,
    rollover: j['rollover'] == true,
  );
}

class Goal {
  final String id, name, account, due;
  final BigInt target, reserved;
  Goal({
    required this.id,
    required this.name,
    required this.account,
    required this.due,
    required this.target,
    required this.reserved,
  }) {
    calendar(due);
    if (target <= BigInt.zero || reserved < BigInt.zero || reserved > target)
      throw const FormatException('Invalid goal reserve');
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'account': account,
    'due': due,
    'target': '$target',
    'reserved': '$reserved',
  };
  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
    id: _text(j['id']),
    name: _text(j['name']),
    account: _text(j['account']),
    due: _text(j['due']),
    target: _big(j['target']),
    reserved: _big(j['reserved']),
  );
}

class Bill {
  final String id, name, account, due, frequency;
  final String? category, toAccount, rate;
  final BigInt amount;
  final BigInt? target;
  final bool reliable, enabled, remind;
  Bill({
    required this.id,
    required this.name,
    required this.account,
    required this.amount,
    required this.due,
    this.frequency = 'monthly',
    this.category,
    this.toAccount,
    this.target,
    this.rate,
    this.reliable = false,
    this.enabled = true,
    this.remind = false,
  }) {
    calendar(due);
    if (amount == BigInt.zero ||
        !{'once', 'weekly', 'monthly', 'yearly'}.contains(frequency))
      throw const FormatException('Invalid schedule');
    if (toAccount != null &&
        (!amount.isNegative ||
            target == null ||
            target! <= BigInt.zero ||
            toAccount == account))
      throw const FormatException('Invalid scheduled transfer');
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'account': account,
    'amount': '$amount',
    'due': due,
    'frequency': frequency,
    'category': category,
    'toAccount': toAccount,
    'target': target?.toString(),
    'rate': rate,
    'reliable': reliable,
    'enabled': enabled,
    'remind': remind,
  };
  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
    id: _text(j['id']),
    name: _text(j['name']),
    account: _text(j['account']),
    amount: _big(j['amount']),
    due: _text(j['due']),
    frequency: _text(j['frequency']),
    category: j['category'] as String?,
    toAccount: j['toAccount'] as String?,
    target: j['target'] == null ? null : _big(j['target']),
    rate: j['rate'] as String?,
    reliable: j['reliable'] == true,
    enabled: j['enabled'] != false,
    remind: j['remind'] == true,
  );
}

class Scenario {
  final String id, name, asOf;
  final Map<String, dynamic> baseline;
  final List<Entry> staged;
  final List<String> skipBills;
  Scenario({
    required this.id,
    required this.name,
    required this.asOf,
    required Map<String, dynamic> baseline,
    required List<Entry> staged,
    List<String> skipBills = const [],
  }) : baseline = _frozenMap(baseline),
       staged = List.unmodifiable(staged),
       skipBills = List.unmodifiable(skipBills) {
    calendar(asOf);
    if (this.baseline['scenarios'] is List &&
        (this.baseline['scenarios'] as List).isNotEmpty)
      throw const FormatException('Nested scenarios prohibited');
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'asOf': asOf,
    'baseline': baseline,
    'staged': staged.map((e) => e.toJson()).toList(),
    'skipBills': skipBills,
  };
  factory Scenario.fromJson(Map<String, dynamic> j) => Scenario(
    id: _text(j['id']),
    name: _text(j['name']),
    asOf: _text(j['asOf']),
    baseline: _map(j['baseline']),
    staged: _list(j['staged'], Entry.fromJson),
    skipBills: List<String>.from(j['skipBills'] as List? ?? []),
  );
}

class SpendState {
  final int revision;
  final List<Account> accounts;
  final List<Category> categories;
  final List<Entry> entries;
  final List<Budget> budgets;
  final List<Goal> goals;
  final List<Bill> bills;
  final List<Scenario> scenarios;
  final Map<String, dynamic> settings;
  final List<Map<String, dynamic>> profiles, rules, imports, audit;
  SpendState({
    this.revision = 0,
    List<Account> accounts = const [],
    List<Category> categories = const [],
    List<Entry> entries = const [],
    List<Budget> budgets = const [],
    List<Goal> goals = const [],
    List<Bill> bills = const [],
    List<Scenario> scenarios = const [],
    Map<String, dynamic> settings = const {},
    List<Map<String, dynamic>> profiles = const [],
    List<Map<String, dynamic>> rules = const [],
    List<Map<String, dynamic>> imports = const [],
    List<Map<String, dynamic>> audit = const [],
  }) : accounts = List.unmodifiable(accounts),
       categories = List.unmodifiable(categories),
       entries = List.unmodifiable(entries),
       budgets = List.unmodifiable(budgets),
       goals = List.unmodifiable(goals),
       bills = List.unmodifiable(bills),
       scenarios = List.unmodifiable(scenarios),
       settings = _frozenMap(settings),
       profiles = List.unmodifiable(profiles.map((v) => _frozenMap(v))),
       rules = List.unmodifiable(rules.map((v) => _frozenMap(v))),
       imports = List.unmodifiable(imports.map((v) => _frozenMap(v))),
       audit = List.unmodifiable(audit.map((v) => _frozenMap(v)));
  String get currency => settings['currency'] as String? ?? 'VND';
  String get zone => settings['zone'] as String? ?? 'Asia/Ho_Chi_Minh';
  Map<String, dynamic> toJson() => {
    'version': 1,
    'revision': revision,
    'accounts': accounts.map((e) => e.toJson()).toList(),
    'categories': categories.map((e) => e.toJson()).toList(),
    'entries': entries.map((e) => e.toJson()).toList(),
    'budgets': budgets.map((e) => e.toJson()).toList(),
    'goals': goals.map((e) => e.toJson()).toList(),
    'bills': bills.map((e) => e.toJson()).toList(),
    'scenarios': scenarios.map((e) => e.toJson()).toList(),
    'settings': settings,
    'profiles': profiles,
    'rules': rules,
    'imports': imports,
    'audit': audit,
  };
  factory SpendState.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1)
      throw const FormatException('Unsupported Spend schema');
    final s = SpendState(
      revision: j['revision'] as int? ?? 0,
      accounts: _list(j['accounts'], Account.fromJson),
      categories: _list(j['categories'], Category.fromJson),
      entries: _list(j['entries'], Entry.fromJson),
      budgets: _list(j['budgets'], Budget.fromJson),
      goals: _list(j['goals'], Goal.fromJson),
      bills: _list(j['bills'], Bill.fromJson),
      scenarios: _list(j['scenarios'], Scenario.fromJson),
      settings: _map(j['settings']),
      profiles: _list(j['profiles'], (e) => e),
      rules: _list(j['rules'], (e) => e),
      imports: _list(j['imports'], (e) => e),
      audit: _list(j['audit'], (e) => e),
    );
    s.validate();
    return s;
  }
  SpendState copy(Map<String, dynamic> changes) =>
      SpendState.fromJson({...toJson(), ...changes});
  void validate() {
    for (final key in ['hideAmounts', 'notifications', 'deviceLock']) {
      if (settings[key] != null && settings[key] is! bool)
        throw const FormatException('Invalid privacy setting');
    }
    final lock = settings['lockSeconds'];
    if (lock != null && (lock is! int || lock < 0 || lock > 3600))
      throw const FormatException('Invalid lock timeout');
    if (settings['buffer'] != null && _big(settings['buffer']) < BigInt.zero)
      throw const FormatException('Invalid cash buffer');
    if (settings['eligibleAccounts'] != null &&
        (settings['eligibleAccounts'] is! List ||
            (settings['eligibleAccounts'] as List).any(
              (id) => id is! String || !accounts.any((a) => a.id == id),
            )))
      throw const FormatException('Unknown planning account');
    scale(currency);
    location(zone);
    if (revision < 0) throw const FormatException('Invalid revision');
    void unique(Iterable<String> ids) {
      final l = ids.toList();
      if (l.any((e) => e.isEmpty) || l.toSet().length != l.length)
        throw const FormatException('Duplicate or empty ID');
    }

    unique(accounts.map((e) => e.id));
    unique(entries.map((e) => e.id));
    unique(categories.map((e) => e.id));
    unique(bills.map((e) => e.id));
    unique(goals.map((e) => e.id));
    unique(budgets.map((e) => e.id));
    unique(scenarios.map((e) => e.id));
    final ac = {for (final a in accounts) a.id: a},
        cats = {for (final c in categories) c.id: c},
        tx = {for (final e in entries) e.id: e};
    for (final c in categories) {
      final seen = <String>{c.id};
      var p = c.parent;
      while (p != null) {
        if (!cats.containsKey(p) || !seen.add(p) || cats[p]!.kind != c.kind)
          throw const FormatException('Invalid category hierarchy');
        p = cats[p]!.parent;
      }
    }
    for (final e in entries) {
      final a = ac[e.account];
      if (a == null || reportDay(e.when, zone).compareTo(a.asOf) < 0)
        throw const FormatException(
          'Account missing or transaction before opening balance',
        );
      if (e.category != null &&
          (!cats.containsKey(e.category) ||
              cats[e.category]!.kind !=
                  (e.kind == 'income' ? 'income' : 'expense')))
        throw const FormatException('Invalid category reference');
      if (e.kind == 'transfer') {
        final b = ac[e.toAccount];
        if (b == null) throw const FormatException('Missing destination');
        final expected = a.currency == b.currency
            ? -e.amount
            : convert(-e.amount, a.currency, b.currency, e.rate ?? '');
        if (e.target != expected)
          throw const FormatException('Transfer amount/rate mismatch');
      }
      if (e.kind == 'refund') {
        final original = tx[e.refundOf];
        if (original == null ||
            original.kind != 'expense' ||
            original.account != e.account ||
            original.status != 'posted')
          throw const FormatException('Invalid refund reference');
      }
    }
    final refunded = <String, BigInt>{};
    for (final e in entries.where(
      (e) => e.kind == 'refund' && e.status == 'posted',
    )) {
      refunded[e.refundOf!] = (refunded[e.refundOf!] ?? BigInt.zero) + e.amount;
      if (refunded[e.refundOf!]! > -tx[e.refundOf]!.amount)
        throw const FormatException('Refund exceeds original expense');
    }
    final occurrences = <String>{};
    for (final e in entries) {
      if (e.occurrence != null && !occurrences.add(e.occurrence!))
        throw const FormatException('Occurrence already recorded');
    }
    for (final b in budgets) {
      if (b.account != null && ac[b.account]?.currency != b.currency ||
          b.category != null && !cats.containsKey(b.category))
        throw const FormatException('Invalid budget scope');
    }
    for (final g in goals) {
      if (!ac.containsKey(g.account))
        throw const FormatException('Missing goal account');
    }
    for (final b in bills) {
      if (!ac.containsKey(b.account) ||
          b.category != null && !cats.containsKey(b.category))
        throw const FormatException('Invalid bill reference');
      if (b.category != null &&
          cats[b.category]!.kind !=
              (b.amount.isNegative ? 'expense' : 'income'))
        throw const FormatException('Bill category direction mismatch');
      if (b.toAccount != null) {
        final to = ac[b.toAccount];
        if (to == null ||
            b.target !=
                (ac[b.account]!.currency == to.currency
                    ? -b.amount
                    : convert(
                        -b.amount,
                        ac[b.account]!.currency,
                        to.currency,
                        b.rate ?? '',
                      )))
          throw const FormatException('Scheduled transfer rate mismatch');
      }
    }
    for (final s in scenarios) {
      final base = SpendState.fromJson(s.baseline);
      base.copy({
        'entries': [
          ...base.entries.map((e) => e.toJson()),
          ...s.staged.map((e) => e.toJson()),
        ],
      });
    }
  }
}
