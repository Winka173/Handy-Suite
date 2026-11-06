import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart';

/// Everything Pro Lifetime adds, by one id each. One policy for all of
/// them: Pro is a verified store purchase ([LifetimeController.pro]);
/// nothing here grants it, and losing it never deletes what was made
/// with it (a chosen theme simply waits until Pro is back).
enum ProFeature {
  smartCollections,
  premiumThemes,
  premiumLayouts,
  focusSkins,
  premiumExport,
  autoOrganize,
  advancedBulk,
  readerHighlights,
  deepSearch,
  ocrOffline,
}

/// The features this build actually ships. The Explore Pro screen lists
/// only these as available; the rest are not advertised.
const shippedProFeatures = {
  ProFeature.smartCollections,
  ProFeature.premiumThemes,
  ProFeature.premiumLayouts,
  ProFeature.focusSkins,
  ProFeature.premiumExport,
  ProFeature.autoOrganize,
  ProFeature.advancedBulk,
  ProFeature.readerHighlights,
};

/// Whether this person owns a verified Pro Lifetime.
bool hasPro(BuildContext context) =>
    LifetimeScope.maybeOf(context)?.pro == true;

/// The one gate: true when Pro is verified; otherwise opens Explore Pro
/// (at [feature]'s pillar) and reports whether Pro became verified there.
Future<bool> requirePro(BuildContext context, ProFeature feature) async {
  if (hasPro(context)) return true;
  await Navigator.pushNamed(context, '/pro', arguments: feature);
  return context.mounted && hasPro(context);
}
