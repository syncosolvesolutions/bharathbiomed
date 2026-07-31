import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/rcpa_repository.dart';
import 'package:bharathbiomedpharma/domain/models/rcpa_entry.dart';
import 'package:bharathbiomedpharma/features/auth/auth_controller.dart';
import 'package:bharathbiomedpharma/features/rcpa/rcpa_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRcpaRepository extends Mock implements RcpaRepository {}

class MockUser extends Mock implements User {}

class _StubAuthController extends AuthController {
  _StubAuthController(this._user);
  final User? _user;
  @override
  Future<User?> build() async => _user;
}

void main() {
  late MockRcpaRepository repository;

  RcpaEntry entry(String id, {required DateTime createdAt}) => RcpaEntry(
        id: id,
        mrUid: 'mr1',
        pharmacyId: 'ph1',
        pharmacyName: 'City Pharmacy',
        auditDate: '2026-07-01',
        createdAt: createdAt,
      );

  Future<ProviderContainer> buildContainer(User? user) async {
    repository = MockRcpaRepository();
    final container = ProviderContainer(overrides: [
      rcpaRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(() => _StubAuthController(user)),
    ]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    return container;
  }

  test('returns an empty list and never touches the repository when signed out', () async {
    final container = await buildContainer(null);

    final result = await container.read(myRcpaEntriesControllerProvider.future);

    expect(result, isEmpty);
    verifyNever(() => repository.loadForMr(any()));
  });

  test('loads the signed-in MR\'s own entries, newest first', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn('mr1');
    final container = await buildContainer(user);
    final older = entry('e1', createdAt: DateTime(2026, 7, 1));
    final newer = entry('e2', createdAt: DateTime(2026, 7, 2));
    when(() => repository.loadForMr('mr1')).thenAnswer((_) async => [older, newer]);

    final result = await container.read(myRcpaEntriesControllerProvider.future);

    expect(result, [newer, older]);
  });

  test('refresh re-runs build and surfaces a failure as AsyncError rather than throwing', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn('mr1');
    final container = await buildContainer(user);
    when(() => repository.loadForMr('mr1')).thenAnswer((_) async => []);
    await container.read(myRcpaEntriesControllerProvider.future);

    when(() => repository.loadForMr('mr1')).thenThrow(Exception('local db error'));
    await container.read(myRcpaEntriesControllerProvider.notifier).refresh();

    expect(container.read(myRcpaEntriesControllerProvider).hasError, isTrue);
  });
}
