import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const habitSystemChannel = MethodChannel('handy_habit/system');

/// Read-only OS facts. Null is unknown, never an assumed permission grant.
class HabitSystemStatus {
  final bool? exactAllowed, batteryExempt;
  const HabitSystemStatus({this.exactAllowed, this.batteryExempt});
}

Future<HabitSystemStatus> habitSystemStatus() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android)
    return const HabitSystemStatus();
  try {
    final m = await habitSystemChannel.invokeMapMethod<String, dynamic>(
      'status',
    );
    return HabitSystemStatus(
      exactAllowed: m?['exactAllowed'] as bool?,
      batteryExempt: m?['batteryExempt'] as bool?,
    );
  } catch (_) {
    return const HabitSystemStatus();
  }
}

Future<void> openHabitSystemSettings({bool battery = false}) async {
  if (kIsWeb)
    throw UnsupportedError(
      'System settings unavailable / Không có cài đặt hệ thống',
    );
  if (defaultTargetPlatform == TargetPlatform.android) {
    await habitSystemChannel.invokeMethod<void>(
      battery ? 'battery' : 'notifications',
    );
    return;
  }
  final uri = defaultTargetPlatform == TargetPlatform.windows
      ? Uri.parse('ms-settings:notifications')
      : Uri.parse('app-settings:');
  if (!await launchUrl(uri))
    throw StateError('Could not open Settings / Chưa mở được Cài đặt');
}
