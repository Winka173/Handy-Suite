import 'package:flutter/foundation.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../scope.dart';

/// Phones open other apps by link; elsewhere the link has nowhere to go.
bool get canHandOff =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// A purchase as a new thing in Handy Keep: name, price, currency and date
/// pre-filled there; Keep saves nothing until the person does.
Uri keepLink(SpendState state, Entry e) {
  final currency = state.accounts.firstWhere((a) => a.id == e.account).currency;
  final category = state.categories
      .where((c) => c.id == e.category)
      .firstOrNull;
  final name = [
    e.payee,
    e.note,
    category?.name ?? '',
  ].map((s) => s.trim()).firstWhere((s) => s.isNotEmpty, orElse: () => '');
  return Uri(
    scheme: 'handy-keep',
    host: 'new',
    queryParameters: {
      if (name.isNotEmpty)
        'name': name.length > 120 ? name.substring(0, 120) : name,
      'price': decimalMoney(e.amount.abs(), currency),
      'currency': currency,
      'date': reportDay(e.when, state.zone),
    },
  );
}

Future<void> sendToKeep(BuildContext context, SpendScope scope, Entry e) async {
  var opened = false;
  try {
    opened = await launchUrl(
      keepLink(scope.state, e),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted)
    showHandyMessage(
      context,
      tr(
        context,
        'Handy Keep is not on this device.',
        'Máy này chưa có Handy Keep.',
      ),
    );
}
