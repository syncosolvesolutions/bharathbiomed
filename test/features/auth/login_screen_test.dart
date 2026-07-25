import 'package:bharathbiomedpharma/core/connectivity/connectivity_provider.dart';
import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/auth_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/product_repository.dart';
import 'package:bharathbiomedpharma/features/auth/login_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockProductRepository extends Mock implements ProductRepository {}

void main() {
  late MockAuthRepository authRepository;
  late MockProductRepository productRepository;

  setUp(() {
    authRepository = MockAuthRepository();
    productRepository = MockProductRepository();
    when(() => authRepository.authStateChanges()).thenAnswer((_) => Stream.value(null));
    when(() => authRepository.currentUser).thenReturn(null);
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        productRepositoryProvider.overrideWithValue(productRepository),
        connectivityProvider.overrideWith((ref) => Stream.value(const [ConnectivityResult.wifi])),
      ],
      child: const MaterialApp(home: LoginScreen()),
    );
  }

  testWidgets('leads with Continue Offline and no pre-filled credential fields', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Continue Offline'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('revealing the sign-in section shows empty email/password fields', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in to download / sync data'));
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields, hasLength(2));
    for (final field in fields) {
      expect(field.controller!.text, isEmpty);
    }
  });

  testWidgets('tapping Continue Offline with no cached data prompts to sign in and sync', (tester) async {
    when(() => productRepository.hasCachedCatalog()).thenAnswer((_) async => false);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue Offline'));
    await tester.pumpAndSettle();

    expect(find.text('No data yet'), findsOneWidget);
    // The sign-in section should now be expanded so the user can act on the prompt.
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
