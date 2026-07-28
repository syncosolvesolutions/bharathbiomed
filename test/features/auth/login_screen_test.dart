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

  testWidgets('always shows the sign-in form with no Continue Offline path', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Continue Offline'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('sign-in fields start empty', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields, hasLength(2));
    for (final field in fields) {
      expect(field.controller!.text, isEmpty);
    }
  });
}
