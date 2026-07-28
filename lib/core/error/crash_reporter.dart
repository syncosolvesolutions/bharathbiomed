import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Wires Crashlytics with device identification. Only Android and iOS are
/// supported build targets for this app (see android/, ios/ folders).
class CrashReporter {
  CrashReporter._();

  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  static Future<void> initialize() async {
    debugPrint('CrashReporter.initialize: reading device info for platform=$defaultTargetPlatform');
    try {
      final deviceData = switch (defaultTargetPlatform) {
        TargetPlatform.android => _readAndroidBuildData(await _deviceInfoPlugin.androidInfo),
        TargetPlatform.iOS => _readIosDeviceInfo(await _deviceInfoPlugin.iosInfo),
        _ => <String, dynamic>{'error': 'Unsupported platform for device info'},
      };
      debugPrint('CrashReporter.initialize: device info read successfully');

      final userId = '${deviceData['serialNumber'] ?? deviceData['identifierForVendor'] ?? 'unknown_device'}';
      debugPrint('CrashReporter.initialize: setting Crashlytics user identifier and custom keys');
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
      await FirebaseCrashlytics.instance.setCustomKey('device_name', deviceData['name'] ?? 'Unknown');
      await FirebaseCrashlytics.instance.setCustomKey('model', deviceData['model'] ?? 'Unknown');
      debugPrint('CrashReporter.initialize: Crashlytics user identifier and custom keys set');
    } on PlatformException catch (e, st) {
      debugPrint('CrashReporter: failed to read device info: $e');
      await FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
    }
  }

  static Map<String, dynamic> _readAndroidBuildData(AndroidDeviceInfo build) {
    return <String, dynamic>{
      'name': build.model,
      'model': build.model,
      'manufacturer': build.manufacturer,
      'sdkInt': build.version.sdkInt,
      'isPhysicalDevice': build.isPhysicalDevice,
      // AndroidDeviceInfo doesn't expose a serialNumber getter in recent
      // device_info_plus versions; the device id is a stable substitute.
      'serialNumber': build.id,
    };
  }

  static Map<String, dynamic> _readIosDeviceInfo(IosDeviceInfo data) {
    return <String, dynamic>{
      'name': data.name,
      'model': data.modelName,
      'systemVersion': data.systemVersion,
      'isPhysicalDevice': data.isPhysicalDevice,
      'identifierForVendor': data.identifierForVendor,
    };
  }
}
