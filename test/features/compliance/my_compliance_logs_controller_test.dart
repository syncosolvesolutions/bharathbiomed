import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/compliance_log_repository.dart';
import 'package:bharathbiomedpharma/domain/models/compliance_log.dart';
import 'package:bharathbiomedpharma/features/auth/auth_controller.dart';
import 'package:bharathbiomedpharma/features/compliance/my_compliance_logs_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockComplianceLogRepository extends Mock implements ComplianceLogRepository {}

class MockUser extends Mock implements User {}

class _StubAuthController extends AuthController {
  _StubAuthController(this._user);
  final User? _user;
  @override
  Future<User?> build() async => _user;
}

void main() {
  late MockComplianceLogRepository repository;

  ComplianceLog log(String id, {required DateTime createdAt}) => ComplianceLog(
        id: id,
        mrUid: 'mr1',
        mrName: 'Rajesh',
        doctorId: 'doc1',
        doctorName: 'Dr. Verma',
        category: ComplianceCategory.sample,
        value: 100,
        logDate: '2026-07-01',
        createdAt: createdAt,
      );

  Future<ProviderContainer> buildContainer(User? user) async {
    repository = MockComplianceLogRepository();
    final container = ProviderContainer(overrides: [
      complianceLogRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(() => _StubAuthController(user)),
    ]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    return container;
  }

  test('returns an empty list and never touches the repository when signed out', () async {
    final container = await buildContainer(null);

    final result = await container.read(myComplianceLogsControllerProvider.future);

    expect(result, isEmpty);
    verifyNever(() => repository.loadForMr(any()));
  });

  test('loads the signed-in MR\'s own logs, newest first', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn('mr1');
    final container = await buildContainer(user);
    final older = log('l1', createdAt: DateTime(2026, 7, 1));
    final newer = log('l2', createdAt: DateTime(2026, 7, 2));
    when(() => repository.loadForMr('mr1')).thenAnswer((_) async => [older, newer]);

    final result = await container.read(myComplianceLogsControllerProvider.future);

    expect(result, [newer, older]);
  });

  test('refresh re-runs build and surfaces a failure as AsyncError rather than throwing', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn('mr1');
    final container = await buildContainer(user);
    when(() => repository.loadForMr('mr1')).thenAnswer((_) async => []);
    await container.read(myComplianceLogsControllerProvider.future);

    when(() => repository.loadForMr('mr1')).thenThrow(Exception('local db error'));
    await container.read(myComplianceLogsControllerProvider.notifier).refresh();

    expect(container.read(myComplianceLogsControllerProvider).hasError, isTrue);
  });
}
