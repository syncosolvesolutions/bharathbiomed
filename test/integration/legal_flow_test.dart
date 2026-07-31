import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

/// Terms & Conditions / Privacy Policy: bundled in-app, reachable from the
/// login screen without signing in — no self-registration in this app, so
/// there's no checkbox to tick, just links. See docs/BUSINESS_OVERVIEW.md
/// §13.
void main() {
  testWidgets('positive: Terms & Conditions opens from the login screen and can be navigated back from', (tester) async {
    final backend = TestBackend();
    await pumpApp(tester, backend: backend);

    await tester.tap(find.text('Terms & Conditions'));
    await settle(tester);
    expect(find.text('Terms & Conditions'), findsWidgets); // AppBar title
    expect(find.textContaining('Acceptance of these terms'), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('positive: Privacy Policy opens from the login screen and can be navigated back from', (tester) async {
    final backend = TestBackend();
    await pumpApp(tester, backend: backend);

    await tester.tap(find.text('Privacy Policy'));
    await settle(tester);
    expect(find.text('Privacy Policy'), findsWidgets);

    await tester.pageBack();
    await settle(tester);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
