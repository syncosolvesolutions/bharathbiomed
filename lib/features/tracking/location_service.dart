import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Thin wrapper so nothing else in the app imports geolocator directly.
class LocationService {
  /// Never throws — returns null on denied/unavailable/timed-out location
  /// rather than blocking a usage session from being recorded. Location is
  /// a nice-to-have on top of the session itself, not a requirement.
  Future<Position?> getCurrentLocationBestEffort() async {
    debugPrint('LocationService.getCurrentLocationBestEffort: starting best-effort location lookup');
    try {
      debugPrint('LocationService.getCurrentLocationBestEffort: checking location permission');
      var permission = await Geolocator.checkPermission();
      debugPrint('LocationService.getCurrentLocationBestEffort: checkPermission returned $permission');
      if (permission == LocationPermission.denied) {
        debugPrint('LocationService.getCurrentLocationBestEffort: requesting location permission');
        permission = await Geolocator.requestPermission();
        debugPrint('LocationService.getCurrentLocationBestEffort: requestPermission returned $permission');
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('LocationService.getCurrentLocationBestEffort: permission not granted, returning null');
        return null;
      }
      debugPrint('LocationService.getCurrentLocationBestEffort: checking if location service is enabled');
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('LocationService.getCurrentLocationBestEffort: location service disabled, returning null');
        return null;
      }
      debugPrint('LocationService.getCurrentLocationBestEffort: calling Geolocator.getCurrentPosition');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 5)),
      );
      debugPrint('LocationService.getCurrentLocationBestEffort: getCurrentPosition succeeded');
      return position;
    } catch (error) {
      debugPrint('LocationService.getCurrentLocationBestEffort: location lookup failed error=$error');
      return null;
    }
  }
}
