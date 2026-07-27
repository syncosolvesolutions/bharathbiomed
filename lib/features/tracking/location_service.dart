import 'package:geolocator/geolocator.dart';

/// Thin wrapper so nothing else in the app imports geolocator directly.
class LocationService {
  /// Never throws — returns null on denied/unavailable/timed-out location
  /// rather than blocking a usage session from being recorded. Location is
  /// a nice-to-have on top of the session itself, not a requirement.
  Future<Position?> getCurrentLocationBestEffort() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 5)),
      );
    } catch (_) {
      return null;
    }
  }
}
