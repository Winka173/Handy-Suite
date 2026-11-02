import 'package:flutter/services.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../money.dart';
import '../people/split_logic.dart';
import '../people/split_sheet.dart';
import '../receipts/receipt_logic.dart';
import '../receipts/receipt_view.dart';
import '../links/keep_link.dart';
import '../scope.dart';
import '../ui/figures.dart';
import '../ui/sheet.dart';
import 'entry_logic.dart';
import 'entry_parts.dart';

/// Records or edits one entry. New entries start with the amount in focus;
/// everything else has a sensible default (last account, today, posted).
Future<void> openEntry(
  BuildContext context,
  SpendScope scope, {
  Entry? entry,
  Entry? refundOf,
  String kind = 'expense',
}) async {
  if (scope.openAccounts.isEmpty) return;
  Entry? next = entry, refund = refundOf;
  var preset = false;
  while (context.mounted) {
    final result = await openSheet<_After>(
      context,
      scope,
      (_) => EntrySheet(
        scope: scope,
        existing: next,
        refundOf: refund,
        kind: kind,
        preset: preset,
      ),
    );
    if (!context.mounted || result == null) return;
    switch (result) {
      case _Saved(:final message):
        scope.announce(context, message);
        return;
      case _Deleted():
        scope.announce(context, tr(context, 'Deleted.', 'Đã xóa.'));
        return;
      case _Refund(:final original):
        (next, refund, preset) = (null, original, false);
      case _Preset(:final original):
        (next, refund, preset) = (
          presetFrom(original, scope.today, scope.state.zone),
          null,
          true,
        );
    }
  }
}

sealed class _After {}

class _Saved extends _After {
  final String message;
  _Saved(this.message);
}

class _Deleted extends _After {}

class _Refund extends _After {
  final Entry original;
  _Refund(this.original);
}

class _Preset extends _After {
  final Entry original;
  _Preset(this.original);
}

class EntrySheet extends StatefulWidget {
  final SpendScope scope;
  final Entry? existing, refundOf;
  final String kind;

  /// [existing] is a copy of an old entry to save as a new one.
  final bool preset;
  const EntrySheet({
    super.key,
    required this.scope,
    this.existing,
    this.refundOf,
    this.kind = 'expense',
    this.preset = false,
  });
  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  SpendScope get scope => widget.scope;
  SpendState get s => scope.state;
  Entry? get e => widget.existing;
  late String kind =
      e?.kind ?? (widget.refundOf != null ? 'refund' : widget.kind);
  late String account =
      e?.account ?? widget.refundOf?.account ?? defaultAccount(s, kind);
  late String? to = e?.toAccount;
  late String? category = e?.category ?? widget.refundOf?.category;
  late String date = e == null ? scope.today : reportDay(e!.when, s.zone);
  late bool pending = e?.status == 'pending';
  late bool details = (e?.note ?? '').isNotEmpty || (e?.tags ?? []).isNotEmpty;
  bool categoryChosen = false, busy = false;
  String error = '';

  /// The entry's ID before it is saved, so new receipts can name it.
  late final String entryId = e?.id ?? newId();
  final waiting = <PendingReceipt>[];
  final removing = <String>{};
  late SplitDraft? split = () {
    final x = e == null ? null : scope.splitOf(e!.id);
    return x == null ? null : SplitDraft.of(x);
  }();
  final amount = TextEditingController(),
      payee = TextEditingController(),
      note = TextEditingController(),
      tags = TextEditingController(),
      rate = TextEditingController(),
      fee = TextEditingController();

  bool get vi => Localizations.localeOf(context).languageCode == 'vi';
  bool get fixedKind => kind == 'refund' || kind == 'adjustment';
  Account get from => scope.account(account);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (amount.text.isNotEmpty || e == null && widget.refundOf == null) {
      return;
    }
    final source = e ?? widget.refundOf!;
    final value = kind == 'adjustment' ? source.amount : source.amount.abs();
    amount.text = editableAmount(
      value,
      scope.account(source.account).currency,
      vi: vi,
    );
    payee.text = source.payee;
    if (e != null) {
      note.text = e!.note;
      tags.text = e!.tags.join(', ');
      rate.text = e!.rate ?? '';
      if (e!.fee != BigInt.zero)
        fee.text = editableAmount(e!.fee, from.currency, vi: vi);
    }
  }

  @override
  void dispose() {
    for (final c in [amount, payee, note, tags, rate, fee]) {
      c.dispose();
    }
    super.dispose();
  }

  void setKind(String next) => setState(() {
    kind = next;
    if (!categoryChosen) category = categoryForPayee(s, kind, payee.text);
    if (category != null &&
        scope.category(category)?.kind !=
            (kind == 'income' ? 'income' : 'expense'))
      category = null;
  });

  void payeeChanged(String text) {
    if (categoryChosen) return;
    final guess = categoryForPayee(s, kind, text);
    if (guess != null && guess != category) setState(() => category = guess);
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final entered = parseAmount(amount.text, from.currency, vi: vi);
      final next = buildEntry(
        s: s,
        id: entryId,
        existing: e,
        refundOf: widget.refundOf,
        kind: kind,
        account: account,
        entered: entered,
        date: date,
        pending: pending,
        category: category,
        payee: payee.text,
        note: note.text,
        tags: tags.text,
        toAccount: to,
        rate: rate.text,
        fee: fee.text.trim().isEmpty
            ? null
            : parseAmount(fee.text, from.currency, vi: vi),
      );
      final before = scope.splitOf(next.id);
      final shared = split != null && kind == 'expense'
          ? split!.build(
              id: before?.id,
              total: -next.amount,
              currency: from.currency,
              date: date,
              name: entryTitle(context, scope, next),
              entry: next.id,
              category: next.category,
            )
          : null;
      final add = [for (final p in waiting) p.receipt];
      await scope.controller.changeWithFiles(
        (s) => applyEntry(
          s,
          next,
          add: add,
          remove: removing,
          split: shared,
          dropSplit: shared == null && before != null,
          people: split?.added ?? const [],
        ),
        'save_transaction',
        files: {for (final p in waiting) p.receipt.id: p.bytes},
      );
      if (!mounted) return;
      final what = entryTitle(context, scope, next);
      final figure = moneyText(context, scope, next.amount, from.currency);
      Navigator.pop(
        context,
        _Saved(
          e == null || widget.preset
              ? tr(
                  context,
                  'Recorded $figure · $what',
                  'Đã ghi $figure · $what',
                )
              : tr(context, 'Saved $what', 'Đã lưu $what'),
        ),
      );
    } catch (err) {
      if (mounted)
        setState(
          () => error = tr(
            context,
            'Not saved: ${errorText(context, err)}.',
            'Chưa lưu: ${errorText(context, err)}.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> delete() async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Delete this entry?', 'Xóa giao dịch này?'),
      message: tr(
        context,
        'Its receipts and split go with it; Undo brings them back. A refund or a paid-back share linked to it stops the delete.',
        'Hóa đơn và phần chia tiền đi cùng nó; Hoàn tác sẽ đưa lại. Nếu có khoản hoàn tiền hay tiền trả lại gắn với nó thì không xóa được.',
      ),
      confirmLabel: tr(context, 'Delete', 'Xóa'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await scope.controller.deleteEntries({e!.id}, 'delete_transaction');
      if (mounted) Navigator.pop(context, _Deleted());
    } catch (err) {
      if (mounted)
        setState(
          () => error = tr(
            context,
            'Not deleted: ${errorText(context, err)}.',
            'Chưa xóa: ${errorText(context, err)}.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addReceipts({bool camera = false}) async {
    try {
      final files = await pickReceiptFiles(scope, camera: camera);
      if (files == null || !mounted) return;
      final checked = checkReceipts(
        s,
        entryId,
        files,
        waiting: waiting,
        removing: removing,
      );
      setState(() {
        error = '';
        waiting.addAll(checked);
      });
    } catch (err) {
      if (mounted)
        setState(
          () => error = tr(
            context,
            'Receipt not added: ${errorText(context, err)}.',
            'Chưa thêm hóa đơn: ${errorText(context, err)}.',
          ),
        );
    }
  }

  void removeReceipt(String id) => setState(() {
    final i = waiting.indexWhere((p) => p.receipt.id == id);
    i >= 0 ? waiting.removeAt(i) : removing.add(id);
  });

  Future<void> editSplit() async {
    BigInt total;
    try {
      total = parseAmount(amount.text, from.currency, vi: vi);
      if (total <= BigInt.zero) throw const FormatException('');
    } catch (_) {
      setState(
        () => error = tr(
          context,
          'Enter the amount first, then split it.',
          'Nhập số tiền trước rồi chia.',
        ),
      );
      return;
    }
    final result = await openSplitSheet(
      context,
      scope,
      total: total,
      currency: from.currency,
      draft: split,
    );
    if (result != null && mounted)
      setState(() {
        error = '';
        split = result.draft;
      });
  }

  String splitLabel() {
    final d = split;
    if (d == null) return tr(context, 'Split', 'Chia tiền');
    final n = d.chosen.length;
    return tr(context, 'Split $n ways', 'Chia $n người');
  }

  String get title => switch (kind) {
    _ when widget.preset => tr(context, 'Record again', 'Ghi lại khoản này'),
    'refund' => tr(context, 'Refund', 'Hoàn tiền'),
    'adjustment' => tr(context, 'Adjustment', 'Điều chỉnh số dư'),
    _ when e != null => tr(context, 'Entry', 'Giao dịch'),
    'income' => tr(context, 'Record income', 'Ghi khoản thu'),
    'transfer' => tr(context, 'Move money', 'Chuyển tiền'),
    _ => tr(context, 'Record spending', 'Ghi khoản chi'),
  };

  @override
  Widget build(BuildContext context) {
    final editable = e != null && !widget.preset;
    final canRefund = editable && kind == 'expense' && !pending;
    final canRepeat =
        editable && ['expense', 'income', 'transfer'].contains(kind);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): save,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): save,
      },
      child: SheetFrame(
        title: title,
        busy: busy,
        error: error,
        actions: [
          if (editable)
            HandyMenuButton(
              items: [
                if (canRefund)
                  HandyMenuItem(
                    Icons.undo,
                    tr(context, 'Record a refund', 'Ghi hoàn tiền'),
                    () => Navigator.pop(context, _Refund(e!)),
                    key: const Key('entry-refund'),
                  ),
                if (e != null && e!.kind == 'expense' && canHandOff)
                  HandyMenuItem(
                    Icons.inventory_2_outlined,
                    tr(context, 'Add to Handy Keep', 'Thêm vào Handy Keep'),
                    () => sendToKeep(context, scope, e!),
                    key: const Key('entry-keep'),
                  ),
                if (canRepeat)
                  HandyMenuItem(
                    Icons.replay,
                    tr(context, 'Record again as new', 'Ghi lại như khoản mới'),
                    () => Navigator.pop(context, _Preset(e!)),
                    key: const Key('entry-preset'),
                  ),
                HandyMenuItem(
                  Icons.delete_outline,
                  tr(context, 'Delete', 'Xóa'),
                  delete,
                  destructive: true,
                  key: const Key('entry-delete'),
                ),
              ],
            ),
        ],
        primary: FilledButton(
          key: const Key('editor-save'),
          onPressed: busy ? null : save,
          child: Text(
            busy
                ? tr(context, 'Saving…', 'Đang lưu…')
                : tr(context, 'Save', 'Lưu'),
          ),
        ),
        children: [
          if (!fixedKind)
            KindSwitch(
              kind: kind,
              canTransfer: scope.openAccounts.length > 1,
              onChanged: busy ? null : setKind,
            )
          else if (widget.refundOf != null || e?.refundOf != null)
            RefundOrigin(
              scope: scope,
              entry:
                  widget.refundOf ??
                  scope.state.entries.firstWhere((x) => x.id == e!.refundOf),
            ),
          const SizedBox(height: HandySpace.l),
          AmountField(
            controller: amount,
            unit: currencyUnit(from.currency),
            autofocus: e == null && widget.refundOf == null,
            signed: kind == 'adjustment',
            enabled: !busy,
            onSubmitted: save,
          ),
          const SizedBox(height: HandySpace.l),
          if (kind == 'transfer')
            TransferParts(
              scope: scope,
              from: account,
              to: to,
              rate: rate,
              fee: fee,
              enabled: !busy,
              onFrom: (v) => setState(() => account = v),
              onTo: (v) => setState(() => to = v),
            )
          else if (kind != 'adjustment')
            CategoryChips(
              scope: scope,
              kind: kind == 'income' ? 'income' : 'expense',
              recent: recentCategories(s, kind),
              selected: category,
              enabled: !busy,
              onChanged: (v) => setState(() {
                categoryChosen = true;
                category = v;
              }),
            ),
          PayeeField(
            scope: scope,
            kind: kind,
            controller: payee,
            enabled: !busy,
            onChanged: payeeChanged,
          ),
          const SizedBox(height: HandySpace.m),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              if (kind != 'transfer')
                AccountChip(
                  key: const Key('entry-account'),
                  scope: scope,
                  value: account,
                  enabled: !busy && !(e != null && kind == 'adjustment'),
                  onChanged: (v) => setState(() => account = v),
                ),
              ActionChip(
                key: const Key('entry-date'),
                avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(whenLabel(context, scope, date)),
                onPressed: busy
                    ? null
                    : () async {
                        final picked = await pickHandyDate(context, date);
                        if (picked != null) setState(() => date = picked);
                      },
              ),
              if (kind == 'expense' && e?.settles == null)
                ActionChip(
                  key: const Key('entry-split'),
                  avatar: Icon(
                    split == null ? Icons.call_split : Icons.groups_outlined,
                    size: 16,
                  ),
                  label: Text(splitLabel()),
                  onPressed: busy ? null : editSplit,
                ),
              FilterChip(
                key: const Key('entry-pending'),
                label: Text(tr(context, 'Not yet paid', 'Chưa trả thật')),
                tooltip: tr(
                  context,
                  'Pending: counts in the plan, not in balances',
                  'Dự kiến: tính trong kế hoạch, chưa trừ vào số dư',
                ),
                selected: pending,
                onSelected: busy ? null : (v) => setState(() => pending = v),
              ),
            ],
          ),
          const SizedBox(height: HandySpace.s),
          if (!details)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('entry-details'),
                onPressed: () => setState(() => details = true),
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr(context, 'Note and tags', 'Ghi chú và nhãn')),
              ),
            )
          else
            HandyReveal(
              child: DetailFields(note: note, tags: tags, enabled: !busy),
            ),
          const SizedBox(height: HandySpace.l),
          ReceiptStrip(
            key: const Key('entry-receipts'),
            scope: scope,
            kept: e == null || widget.preset
                ? const []
                : scope.receiptsOf(e!.id),
            waiting: waiting,
            removing: removing,
            enabled: !busy,
            onAdd: addReceipts,
            onOpen: (r, bytes) => openReceipt(context, scope, r, bytes: bytes),
            onRemove: removeReceipt,
            onKeep: (id) => setState(() => removing.remove(id)),
          ),
        ],
      ),
    );
  }
}
