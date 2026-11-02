import 'package:geolocator/geolocator.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';

abstract interface class ForegroundLocation {
  Future<CapturedLocation> capture();
}

class SystemForegroundLocation implements ForegroundLocation {
  @override
  Future<CapturedLocation> capture() async {
    if (!await Geolocator.isLocationServiceEnabled())
      throw StateError('Location service unavailable; use manual check-in');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine)
      throw StateError('Location denied; manual check-in still works');
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return CapturedLocation(
      Geo(p.latitude, p.longitude),
      p.accuracy,
      p.timestamp,
    );
  }
}
