// Drives the app through login -> catalog -> slideshow on a real device or
// emulator and captures Play Store-ready screenshots at each screen.
//
// Credentials are passed in at run time via --dart-define so nothing ends up
// in source control (see docs/PLAY_STORE_CHECKLIST.md for the full command).
//
// Run with:
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_screenshot_test.dart \
//     -d <deviceId> \
//     --dart-define=TEST_EMAIL=you@example.com \
//     --dart-define=TEST_PASSWORD=yourpassword
//
// Screenshots land in ./screenshots/*.png on the host machine.

import 'package:bharathbiomedpharma/main.dart' as app;
import 'package:bharathbiomedpharma/features/catalog/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _testEmail = String.fromEnvironment('TEST_EMAIL');
const _testPassword = String.fromEnvironment('TEST_PASSWORD');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture Play Store screenshots', (tester) async {
    expect(
      _testEmail.isNotEmpty && _testPassword.isNotEmpty,
      isTrue,
      reason: 'Pass --dart-define=TEST_EMAIL=... --dart-define=TEST_PASSWORD=... when running this test.',
    );

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // --- 1. Login screen ---
    await binding.takeScreenshot('01_login');

    await tester.tap(find.text('Sign in to download / sync data'));
    await tester.pumpAndSettle();

    final formFields = find.byType(TextFormField);
    await tester.enterText(formFields.first, _testEmail);
    await tester.enterText(formFields.last, _testPassword);
    await tester.tap(find.text('Sign In & Sync'));
    // Covers sign-in + the sync it triggers + the brief confirmation dialog.
    await tester.pumpAndSettle(const Duration(seconds: 8));

    // --- 2. Catalog screen ---
    await binding.takeScreenshot('02_catalog');

    final productCards = find.byType(ProductCard);
    if (productCards.evaluate().length > 1) {
      await tester.tap(productCards.at(0));
      await tester.pumpAndSettle();
      await tester.tap(productCards.at(1));
      await tester.pumpAndSettle();

      // --- 3. Catalog with a selection made ---
      await binding.takeScreenshot('03_catalog_selected');

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // --- 4. Slideshow ---
      await binding.takeScreenshot('04_slideshow');
    }
  });
}
