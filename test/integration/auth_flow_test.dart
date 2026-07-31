import 'package:bharathbiomedpharma/features/admin/manage_employees_screen.dart';
import 'package:bharathbiomedpharma/features/admin/manage_inventory_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

/// Login screen -> role-based landing. See docs/BUSINESS_OVERVIEW.md §1 for
/// the role model and app_router.dart for the redirect rules under test.
void main() {
  const appTitle = 'Bharath Biomed Pharma';
  const adminEmail = 'bharathbiomedpharma@gmail.com';

  Future<void> signIn(WidgetTester tester, {required String identifier, required String password}) async {
    await tester.enterText(find.byType(TextFormField).at(0), identifier);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.tap(find.text('Sign In & Sync'));
    await settle(tester);
  }

  group('positive: interactive sign-in', () {
    testWidgets('MR credentials land on the catalog with no admin shield icon', (tester) async {
      final backend = TestBackend();
      backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));
      backend.auth.registerAccount(
        loginIdentifier: 'rajesh_kumar',
        password: 'secret123',
        user: buildFirebaseUser(uid: 'mr1', email: null),
      );

      await pumpApp(tester, backend: backend);
      await signIn(tester, identifier: 'rajesh_kumar', password: 'secret123');

      // The router's own redirect reacts to the auth-state change as soon as
      // sign-in resolves and navigates straight to /catalog — it doesn't
      // wait for LoginScreen's own post-sign-in sync-then-"Synced"-dialog
      // tail to finish, which becomes a no-op once LoginScreen unmounts
      // (its `mounted` guard short-circuits before ever showing that dialog).
      expect(find.text(appTitle), findsOneWidget);
      expect(find.byIcon(Icons.admin_panel_settings_outlined), findsNothing);
    });

    testWidgets('admin credentials land on the catalog with the admin shield icon', (tester) async {
      final backend = TestBackend();
      backend.auth.registerAccount(
        loginIdentifier: adminEmail,
        password: 'adminpass',
        user: buildFirebaseUser(uid: 'admin1', email: adminEmail),
      );

      await pumpApp(tester, backend: backend);
      await signIn(tester, identifier: adminEmail, password: 'adminpass');

      expect(find.text(appTitle), findsOneWidget);
      expect(find.byIcon(Icons.admin_panel_settings_outlined), findsOneWidget);
    });
  });

  group('positive: already-signed-in session on launch', () {
    testWidgets('MR session skips the login screen and lands on the catalog', (tester) async {
      final backend = TestBackend();
      backend.employees.employees.add(buildEmployee(uid: 'mr2', username: 'anita_rao'));

      await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr2', email: null));

      expect(find.text('Sign In'), findsNothing);
      expect(find.text(appTitle), findsOneWidget);
    });

    testWidgets('admin session skips the login screen and lands on Admin', (tester) async {
      final backend = TestBackend();

      await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));

      expect(find.text('Sign In'), findsNothing);
      expect(find.text('Admin'), findsOneWidget);
    });
  });

  group('negative', () {
    testWidgets('wrong password shows an error and stays on the login screen', (tester) async {
      final backend = TestBackend();
      backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));
      backend.auth.registerAccount(
        loginIdentifier: 'rajesh_kumar',
        password: 'secret123',
        user: buildFirebaseUser(uid: 'mr1', email: null),
      );

      await pumpApp(tester, backend: backend);
      await signIn(tester, identifier: 'rajesh_kumar', password: 'wrong-password');

      expect(find.text('Sign-in error'), findsOneWidget);
      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('submitting empty fields is blocked by validation before any sign-in attempt', (tester) async {
      final backend = TestBackend();

      await pumpApp(tester, backend: backend);
      await tester.tap(find.text('Sign In & Sync'));
      await settle(tester);

      expect(find.text('Please enter your email or username'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  });

  group('edge cases', () {
    testWidgets('a disabled account is rejected with a plain-language message', (tester) async {
      final backend = TestBackend();
      backend.employees.employees.add(buildEmployee(uid: 'mr3', username: 'suspended_mr', disabled: true));
      backend.auth.registerAccount(
        loginIdentifier: 'suspended_mr',
        password: 'secret123',
        user: buildFirebaseUser(uid: 'mr3', email: null),
        disabled: true,
      );

      await pumpApp(tester, backend: backend);
      await signIn(tester, identifier: 'suspended_mr', password: 'secret123');

      expect(find.text('This account has been disabled. Contact your administrator.'), findsOneWidget);
    });

    testWidgets('a first-login MR is forced through Complete Your Profile before reaching the catalog', (tester) async {
      final backend = TestBackend();
      backend.employees.employees.add(buildEmployee(uid: 'mr4', username: 'new_mr', profileCompleted: false));

      await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr4', email: null));

      expect(find.text('Complete Your Profile'), findsOneWidget);
      expect(find.text(appTitle), findsNothing);
    });

    testWidgets('an Office Admin hitting an admin-only mobile route is redirected to Inventory', (tester) async {
      final backend = TestBackend();
      backend.employees.employees.add(buildEmployee(uid: 'oa1', username: 'office_admin', category: 'office_administration'));

      await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'oa1', email: null));
      expect(find.text(appTitle), findsOneWidget);

      routerOf(tester).go('/admin/employees');
      await settle(tester);

      expect(find.byType(ManageEmployeesScreen), findsNothing);
      expect(find.byType(ManageInventoryScreen), findsOneWidget);
    });
  });
}
