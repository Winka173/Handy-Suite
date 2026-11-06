package dev.flutter.plugins.integration_test;

import io.flutter.embedding.engine.plugins.FlutterPlugin;

/**
 * Release-only stand-in for the dev-only integration_test plugin.
 *
 * <p>`flutter pub get`, `flutter test` and debug runs write a
 * GeneratedPluginRegistrant that registers dev dependencies such as
 * integration_test. Only `flutter build --release` with pub rewrites it
 * without them; `--no-pub`, or a `flutter test` in this app while Gradle is
 * compiling, leaves the debug registrant in place. The Flutter Gradle plugin
 * keeps dev-dependency plugin projects off the release classpath, so that
 * registrant would not compile ("package dev.flutter.plugins.integration_test
 * does not exist"). This class lets it compile and does nothing at run time.
 *
 * <p>It lives in the release source set only: debug and profile builds get the
 * real plugin, and a release built from a correct registrant never references
 * it, so R8 removes it.
 */
public final class IntegrationTestPlugin implements FlutterPlugin {
  @Override
  public void onAttachedToEngine(FlutterPluginBinding binding) {}

  @Override
  public void onDetachedFromEngine(FlutterPluginBinding binding) {}
}
