import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../money.dart';
import '../people/split_logic.dart';
import '../scope.dart';
import '../ui/figures.dart';
import 'entry_logic.dart';

/// One typed line read as an entry: the amount, its direction, the words.
typedef QuickLine = ({BigInt amount, String kind, String words});

final _amount = RegExp(r'^[+-]?\d[\d.,]*(k|tr|đ|d)?$', caseSensitive: false);
final _trMore = RegExp(r'^([+-]?\d+)tr(\d+)$', caseSensitive: false);
const _units = {
  'k': 'k',
  'ng': 'k',
  'nghìn': 'k',
  'ngàn': 'k',
  'tr': 'tr',
  'triệu': 'tr',
  'củ': 'tr',
};

/// Reads "cà phê 45k", "45.000 cà phê", "1tr2 tiền nhà" or "+5tr lương".
/// A figure with a money unit or grouping wins ("2 ly 30k" is 30k); else
/// the last figure. A leading + makes it income. Throws when the line holds
/// no figure.
QuickLine parseQuickLine(String line, String currency, {required bool vi}) {
  final words = line.trim().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  QuickLine? marked, last;
  for (var i = 0; i < words.length; i++) {
    var token = words[i];
    final more = _trMore.firstMatch(token);
    // "1tr2" is 1.2 million.
    if (more != null) token = '${more[1]}${vi ? ',' : '.'}${more[2]}tr';
    if (!_amount.hasMatch(token)) continue;
    var skip = 1;
    final unit = i + 1 < words.length
        ? _units[words[i + 1].toLowerCase()]
        : null;
    if (unit != null && RegExp(r'\d$').hasMatch(token)) {
      token += unit;
      skip = 2;
    }
    final BigInt value;
    try {
      value = parseAmount(token, currency, vi: vi).abs();
    } on FormatException {
      continue;
    }
    if (value == BigInt.zero) continue;
    final read = (
      amount: value,
      kind: token.startsWith('+') ? 'income' : 'expense',
      words: [...words.take(i), ...words.skip(i + skip)].join(' '),
    );
    if (RegExp(r'[a-zđ.,]$|\d[.,]\d{3}', caseSensitive: false).hasMatch(token))
      marked ??= read;
    last = read;
  }
  return marked ??
      last ??
      (throw const FormatException(
        'Write an amount, for example 45k / Viết số tiền, ví dụ 45k',
      ));
}

/// The Today line: type what was spent in words and save it with Enter.
/// The category comes from what the same words got before.
class QuickLineField extends StatefulWidget {
  final SpendScope scope;
  const QuickLineField({super.key, required this.scope});
  @override
  State<QuickLineField> createState() => _QuickLineFieldState();
}

class _QuickLineFieldState extends State<QuickLineField> {
  final text = TextEditingController();
  String? error;
  bool busy = false;

  SpendScope get scope => widget.scope;
  bool get vi => Localizations.localeOf(context).languageCode == 'vi';

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  /// The line as it would be saved, or null while it holds no figure.
  Entry? draft() {
    if (scope.openAccounts.isEmpty || text.text.trim().isEmpty) return null;
    final s = scope.state;
    try {
      final line = parseQuickLine(
        text.text,
        scope.account(defaultAccount(s, 'expense')).currency,
        vi: vi,
      );
      return buildEntry(
        s: s,
        kind: line.kind,
        account: defaultAccount(s, line.kind),
        entered: line.amount,
        date: scope.today,
        pending: false,
        category: categoryForPayee(s, line.kind, line.words),
        payee: line.words,
      );
    } on FormatException {
      return null;
    }
  }

  String reading(Entry next) => [
    moneyText(
      context,
      scope,
      next.amount,
      scope.account(next.account).currency,
    ),
    if (next.payee.isNotEmpty) next.payee,
    scope.category(next.category)?.name ??
        tr(context, 'no category yet', 'chưa có danh mục'),
  ].join(' · ');

  Future<void> save() async {
    if (busy) return;
    final next = draft();
    if (next == null) {
      setState(
        () => error = tr(
          context,
          'Write an amount too, for example "coffee 45k".',
          'Viết kèm số tiền, ví dụ "cà phê 45k".',
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await scope.controller.changeWithFiles(
        (s) => applyEntry(s, next),
        'save_transaction',
      );
      if (!mounted) return;
      scope.announce(
        context,
        tr(context, 'Recorded ${reading(next)}', 'Đã ghi ${reading(next)}'),
      );
      text.clear();
      setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = draft();
    return Padding(
      padding: const EdgeInsets.only(top: HandySpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('quick-line'),
            controller: text,
            enabled: !busy,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => error = null),
            onSubmitted: (_) => save(),
            decoration: InputDecoration(
              hintText: tr(
                context,
                'coffee 45k  ·  +5m salary',
                'cà phê 45k  ·  +5tr lương',
              ),
              prefixIcon: const Icon(Icons.edit_note),
              suffixIcon: next == null
                  ? null
                  : IconButton(
                      key: const Key('quick-line-save'),
                      tooltip: tr(context, 'Record', 'Ghi'),
                      icon: const Icon(Icons.keyboard_return),
                      onPressed: save,
                    ),
              errorText: error,
            ),
          ),
          if (next != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, HandySpace.xs, 2, 0),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  '${next.kind == 'income' ? tr(context, 'Income', 'Thu') : tr(context, 'Spent', 'Chi')}: ${reading(next)}',
                  key: const Key('quick-line-reading'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
