import 'package:bharathbiomedpharma/data/remote/sales_target_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/sales_target_repository.dart';
import 'package:bharathbiomedpharma/domain/models/sales_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSalesTargetRemoteDataSource extends Mock implements SalesTargetRemoteDataSource {}

void main() {
  late MockSalesTargetRemoteDataSource remote;
  late SalesTargetRepository repository;

  const target = SalesTarget(id: 'mr1_2026-07', employeeUid: 'mr1', period: '2026-07', targetValue: 5000, createdByUid: 'rm1');

  setUp(() {
    remote = MockSalesTargetRemoteDataSource();
    repository = SalesTargetRepository(remote: remote);
  });

  test('setTarget delegates to the remote data source', () async {
    when(() => remote.setTarget(
          employeeUid: 'mr1',
          period: '2026-07',
          targetValue: 5000,
          createdByUid: 'rm1',
        )).thenAnswer((_) async {});

    await repository.setTarget(employeeUid: 'mr1', period: '2026-07', targetValue: 5000, createdByUid: 'rm1');

    verify(() => remote.setTarget(
          employeeUid: 'mr1',
          period: '2026-07',
          targetValue: 5000,
          createdByUid: 'rm1',
        )).called(1);
  });

  test('fetchForEmployee delegates to the remote data source', () async {
    when(() => remote.fetchForEmployee('mr1', '2026-07')).thenAnswer((_) async => target);
    expect(await repository.fetchForEmployee('mr1', '2026-07'), target);
  });

  test('fetchForEmployees delegates to the remote data source', () async {
    when(() => remote.fetchForEmployees(['mr1', 'mr2'], '2026-07')).thenAnswer((_) async => [target]);
    expect(await repository.fetchForEmployees(['mr1', 'mr2'], '2026-07'), [target]);
  });
}
