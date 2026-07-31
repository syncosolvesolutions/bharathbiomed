import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/auth_repository.dart';
import 'package:bharathbiomedpharma/features/auth/auth_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUser extends Mock implements User {}

void main() {
  late MockAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockAuthRepository();
    container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repository)]);
    // AuthController.build() awaits this stream's first event — an empty
    // stream would leave `.first` waiting forever (surfacing as "Bad state:
    // No element" once it closes), so it always needs at least one emission,
    // mirroring the real Firebase stream's immediate signed-out/in replay.
    when(() => repository.authStateChanges()).thenAnswer((_) => Stream.value(null));
  });

  tearDown(() => container.dispose());

  test('build reads the initial signed-out state from the repository', () async {
    final user = await container.read(authControllerProvider.future);
    expect(user, isNull);
  });

  group('signIn', () {
    test('a successful sign-in resolves to the signed-in user', () async {
      final user = MockUser();
      when(() => repository.signIn('rajesh_kumar', 'secret')).thenAnswer((_) async => user);
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).signIn('rajesh_kumar', 'secret');

      expect(container.read(authControllerProvider).value, user);
    });

    test('a failed sign-in surfaces as AsyncError, not a thrown exception', () async {
      when(() => repository.signIn('rajesh_kumar', 'wrong')).thenThrow(
        FirebaseAuthException(code: 'wrong-password'),
      );
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).signIn('rajesh_kumar', 'wrong');

      expect(container.read(authControllerProvider).hasError, isTrue);
    });
  });

  group('signOut', () {
    test('signs out via the repository and resets state to signed-out', () async {
      final user = MockUser();
      when(() => repository.signIn('rajesh_kumar', 'secret')).thenAnswer((_) async => user);
      await container.read(authControllerProvider.future);
      await container.read(authControllerProvider.notifier).signIn('rajesh_kumar', 'secret');

      when(() => repository.signOut()).thenAnswer((_) async {});
      await container.read(authControllerProvider.notifier).signOut();

      verify(() => repository.signOut()).called(1);
      expect(container.read(authControllerProvider).value, isNull);
    });
  });

  group('changePassword', () {
    test('delegates to the repository and does not touch auth state', () async {
      when(() => repository.changePassword(currentPassword: 'old', newPassword: 'new'))
          .thenAnswer((_) async {});
      await container.read(authControllerProvider.future);
      final stateBefore = container.read(authControllerProvider);

      await container.read(authControllerProvider.notifier).changePassword(currentPassword: 'old', newPassword: 'new');

      verify(() => repository.changePassword(currentPassword: 'old', newPassword: 'new')).called(1);
      expect(container.read(authControllerProvider), stateBefore);
    });

    test('propagates a repository failure to the caller instead of swallowing it', () async {
      when(() => repository.changePassword(currentPassword: 'old', newPassword: 'new'))
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));
      await container.read(authControllerProvider.future);

      expect(
        () => container.read(authControllerProvider.notifier).changePassword(currentPassword: 'old', newPassword: 'new'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });

  group('sendPasswordResetEmail', () {
    test('delegates to the repository', () async {
      when(() => repository.sendPasswordResetEmail('admin@example.com')).thenAnswer((_) async {});
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).sendPasswordResetEmail('admin@example.com');

      verify(() => repository.sendPasswordResetEmail('admin@example.com')).called(1);
    });

    test('propagates a repository failure to the caller instead of swallowing it', () async {
      when(() => repository.sendPasswordResetEmail('admin@example.com'))
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));
      await container.read(authControllerProvider.future);

      expect(
        () => container.read(authControllerProvider.notifier).sendPasswordResetEmail('admin@example.com'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });
}
