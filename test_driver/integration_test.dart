import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Writes each screenshot taken by integration_test/app_screenshot_test.dart
/// to `./screenshots/<name>.png` on the host machine.
Future<void> main() => integrationDriver(
      onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
        final file = File('screenshots/$screenshotName.png');
        await file.create(recursive: true);
        await file.writeAsBytes(screenshotBytes);
        return true;
      },
    );
