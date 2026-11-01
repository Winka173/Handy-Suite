# Pinned native RE2 build-hook patch

Copied from pub.dev re2 **1.1.5** (MIT wrapper, Google RE2 BSD license retained in
src/third_party/re2/LICENSE) on 2026-10-31. Original lib/src/hook, README, LICENSE
and pubspec are retained. No matching engine or Dart API code was changed.

Patch: return from hook/build.dart before reading HookConfig.code when
input.config.buildCodeAssets is false. Flutter invokes package hooks for Web,
where that configuration has no native code target. Upstream 1.1.5 accessed it
unconditionally and failed the Web build even with conditional Dart imports.

The root path override makes this patch reproducible without modifying the user's
global Pub cache. Native builds still compile the original RE2 C++ shim/library.
Flutter source fingerprints explicitly include this vendored source and hook.
1.1.6/1.1.7 currently require code_assets 2 / meta 1.19, incompatible with this
Flutter SDK's pinned meta 1.18; no SDK pin was overridden.

Web uses the separately licensed same-origin RE2JS 2.9.1 asset and Dart JS interop,
with no fallback to backtracking RegExp and no CDN dependency. This third-party
dependency is part of the Flutter implementation, not a retained Expo app.
