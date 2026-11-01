import 'package:handy_files/handy_files.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import 'controller.dart';
import 'privacy.dart';
import 'reminders.dart';

/// What every Spend screen shares: the ledger, the adapters, and the
/// planning window the person is looking through.
class SpendScope {
  final SpendController controller;
  final HandyFiles files;
  final SpendReminders reminders;
  final SpendPrivacy privacy;

  /// Days from today the plan looks ahead (1–3660; over 30 needs Pro).
  final horizon = ValueNotifier(30);

  /// Count posted money only; otherwise add income marked reliable.
  final conservative = ValueNotifier(true);

  /// The area on screen (Today, Ledger, Plan, Accounts) and the account
  /// open in the Accounts area, so one area can send you to another.
  final area = ValueNotifier(0);
  final openAccount = ValueNotifier<String?>(null);

  /// The account the ledger is narrowed to when opened from an account.
  final ledgerAccount = ValueNotifier<String?>(null);
  SpendScope({
    required this.controller,
    required this.files,
    required this.reminders,
    required this.privacy,
  });

  SpendState get state => controller.state!;
  String get currency => state.currency;
  String get today =>
      reportDay(DateTime.now().toUtc().toIso8601String(), state.zone);

  /// The plan's last day, inclusive.
  String get end => day(calendar(today).add(Duration(days: horizon.value - 1)));
  Set<String> get planningAccounts => eligible(state, state.currency);
  bool get hidden => state.settings['hideAmounts'] == true;

  Account account(String id) => state.accounts.firstWhere((a) => a.id == id);
  Category? category(String? id) =>
      id == null ? null : state.categories.where((c) => c.id == id).firstOrNull;
  List<Account> get openAccounts =>
      state.accounts.where((a) => !a.archived).toList();

  /// Identity colours keep the order things were made in.
  int accountHue(String id) => state.accounts.indexWhere((a) => a.id == id);
  int categoryHue(String id) {
    var c = category(id);
    // A sub-category wears its parent's colour.
    for (var i = 0; c?.parent != null && i < 8; i++) {
      c = category(c!.parent) ?? c;
    }
    return state.categories.indexWhere((x) => x.id == c?.id);
  }

  bool pro(BuildContext context) => LifetimeScope.maybeOf(context)?.pro == true;

  void dispose() {
    horizon.dispose();
    conservative.dispose();
    area.dispose();
    openAccount.dispose();
    ledgerAccount.dispose();
  }

  /// Writes, then says so with an Undo; a failure says nothing changed.
  /// True when the write landed.
  Future<bool> write(
    BuildContext context,
    Future<void> Function() task, {
    String Function(BuildContext)? done,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await task();
    } catch (e) {
      if (context.mounted) {
        showHandyMessage(
          context,
          tr(
            context,
            'Not saved: ${errorText(context, e)}. Nothing changed.',
            'Chưa lưu được: ${errorText(context, e)}. Không có gì thay đổi.',
          ),
        );
      }
      return false;
    }
    if (done != null && context.mounted && messenger != null) {
      announce(context, done(context));
    }
    return true;
  }

  /// Says what was just written, with an Undo for that one change.
  void announce(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final undone = tr(context, 'Undone.', 'Đã hoàn tác.');
    final failed = tr(
      context,
      'Undo is no longer available.',
      'Không còn hoàn tác được.',
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          // With an action Flutter keeps it until tapped; this one goes away.
          persist: false,
          action: SnackBarAction(
            key: const Key('snack-undo'),
            label: tr(context, 'Undo', 'Hoàn tác'),
            onPressed: () async {
              try {
                await controller.undo();
                messenger.showSnackBar(SnackBar(content: Text(undone)));
              } catch (_) {
                messenger.showSnackBar(SnackBar(content: Text(failed)));
              }
            },
          ),
        ),
      );
  }
}
