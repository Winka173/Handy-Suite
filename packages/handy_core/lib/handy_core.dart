import 'dart:convert';

enum HandyPlatform { android, ios, windows, web }

enum CapabilityStatus {
  supported,
  limited,
  requiresPermission,
  requiresNativeComponent,
  unsupported,
}

class Capability {
  final String id;
  final CapabilityStatus status;
  final String reason;
  final bool implemented;
  final bool requiresSetup;
  const Capability(
    this.id,
    this.status,
    this.reason, {
    this.implemented = false,
    this.requiresSetup = false,
  });
  bool get usable =>
      implemented && !requiresSetup && status != CapabilityStatus.unsupported;
}

class Capabilities {
  final HandyPlatform platform;
  const Capabilities(this.platform);
  Capability get(String id) => switch (id) {
    'text' || 'calculator' || 'units' => Capability(
      id,
      CapabilityStatus.supported,
      'Bounded deterministic Dart processing.',
      implemented: true,
    ),
    'files' => Capability(
      id,
      CapabilityStatus.requiresPermission,
      platform == HandyPlatform.web
          ? 'User-selected upload/download only; no arbitrary filesystem access.'
          : 'User-selected system file dialogs.',
      implemented: true,
    ),
    'preferences' => Capability(
      id,
      CapabilityStatus.limited,
      'Noncritical settings only; export a backup. Browser storage can be evicted.',
      implemented: true,
    ),
    'http' => Capability(
      id,
      CapabilityStatus.limited,
      platform == HandyPlatform.web
          ? 'Browser CORS applies; no proxy bypass.'
          : 'Bounded HTTPS requests; headers/auth and cancellation are implemented. Live endpoint compatibility still needs QA.',
      implemented: true,
    ),
    'capture' => Capability(
      id,
      platform == HandyPlatform.web || platform == HandyPlatform.windows
          ? CapabilityStatus.unsupported
          : CapabilityStatus.requiresPermission,
      switch (platform) {
        HandyPlatform.android =>
          'Real MediaProjection consent; screen PNG and silent video, bounded trim/join/frame. Emulator verified, physical-device QA pending.',
        HandyPlatform.ios =>
          'ReplayKit records this app only; no cross-app screenshots. Native source is implemented but not built/run on this Windows host.',
        _ =>
          'Native screen recording is unavailable in this target. Import images/videos for local editing instead.',
      },
      implemented:
          platform == HandyPlatform.android || platform == HandyPlatform.ios,
    ),
    'notifications' => Capability(
      id,
      platform == HandyPlatform.android || platform == HandyPlatform.ios
          ? CapabilityStatus.requiresPermission
          : CapabilityStatus.unsupported,
      platform == HandyPlatform.android || platform == HandyPlatform.ios
          ? 'Local reminders require permission; OS battery policy can delay delivery. Android emulator checks pass; iOS runtime QA pending.'
          : 'Use the local in-app due list; OS notifications are unavailable on this target.',
      implemented:
          platform == HandyPlatform.android || platform == HandyPlatform.ios,
    ),
    'images' => Capability(
      id,
      CapabilityStatus.limited,
      'Local PNG/JPEG/static WebP conversion and batch processing. Animated WebP is rejected; WebP output is capped at 4M pixels. Metadata tools support verified PNG/JPEG only.',
      implemented: true,
    ),
    'qr' => Capability(
      id,
      platform == HandyPlatform.android || platform == HandyPlatform.ios
          ? CapabilityStatus.requiresPermission
          : CapabilityStatus.limited,
      platform == HandyPlatform.android || platform == HandyPlatform.ios
          ? 'Local QR generation/exports and native camera scanning; no automatic link launch.'
          : 'Local QR generation/exports and pasted-text review; camera scanning is unavailable.',
      implemented: true,
    ),
    'pdf' => Capability(
      id,
      CapabilityStatus.limited,
      platform == HandyPlatform.web
          ? 'Local PDF preview/page operations are implemented; browser runtime is unverified and watermark is unavailable.'
          : 'Local PDFium preview/page operations and ASCII watermark; no OCR. Native iOS runtime is unverified.',
      implemented: true,
    ),
    'purchase' => Capability(
      id,
      platform == HandyPlatform.web
          ? CapabilityStatus.unsupported
          : CapabilityStatus.requiresNativeComponent,
      'Native store adapters exist; publisher identities/product setup and real transactions are unverified. Owner configuration is still required. Free tools remain usable.',
      implemented: platform != HandyPlatform.web,
      requiresSetup: true,
    ),
    'ads' => Capability(
      id,
      platform == HandyPlatform.android || platform == HandyPlatform.ios
          ? CapabilityStatus.limited
          : CapabilityStatus.unsupported,
      platform == HandyPlatform.android || platform == HandyPlatform.ios
          ? 'Consent-gated mobile ad code exists. Publisher configuration is required; no production delivery is verified.'
          : 'Mobile AdMob is unavailable on this target; no unsupported SDK is initialized.',
      implemented:
          platform == HandyPlatform.android || platform == HandyPlatform.ios,
      requiresSetup: true,
    ),
    _ => Capability(
      id,
      CapabilityStatus.unsupported,
      'Feature not migrated on this target.',
    ),
  };
}

class Cancelled implements Exception {
  const Cancelled();
  @override
  String toString() => 'Operation canceled / Đã hủy thao tác';
}

class CancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
  void check() {
    if (_cancelled) throw const Cancelled();
  }
}

String safeFilename(String input) {
  var name = input
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
  if (name.isEmpty) name = 'output';
  if (RegExp(
    r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
    caseSensitive: false,
  ).hasMatch(name))
    name = 'file_$name';
  return name.length > 160 ? name.substring(0, 160) : name;
}

String decodeUtf8(List<int> bytes, {int maxBytes = 1000000}) {
  if (bytes.length > maxBytes)
    throw const FormatException('UTF-8 import size limit exceeded');
  final text = utf8.decode(bytes, allowMalformed: false);
  if (text.contains('\u0000'))
    throw const FormatException('Binary input is not supported');
  return text.startsWith('\ufeff') ? text.substring(1) : text;
}

bool safeArchivePath(String name) =>
    name.isNotEmpty &&
    name.length <= 240 &&
    !name.startsWith('/') &&
    !name.contains('\\') &&
    !name.contains(':') &&
    !name.contains('\u0000') &&
    name.split('/').every((s) => s.isNotEmpty && s != '.' && s != '..');

enum EntitlementState { free, proLifetime }

class Entitlement {
  final EntitlementState state;
  final String? storeProduct;
  const Entitlement.free() : state = EntitlementState.free, storeProduct = null;
  // Never construct paid entitlement from a user-imported settings file.
  const Entitlement.verified(this.storeProduct)
    : state = EntitlementState.proLifetime;
}

bool adsAllowed(
  Entitlement e, {
  required bool configured,
  required bool consent,
}) => e.state == EntitlementState.free && configured && consent;
