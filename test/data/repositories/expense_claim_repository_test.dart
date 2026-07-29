import 'package:bharathbiomedpharma/data/local/expense_claim_local_data_source.dart';
import 'package:bharathbiomedpharma/data/remote/expense_claim_remote_data_source.dart';
import 'package:bharathbiomedpharma/data/repositories/expense_claim_repository.dart';
import 'package:bharathbiomedpharma/domain/models/expense_claim.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExpenseClaimLocalDataSource extends Mock implements ExpenseClaimLocalDataSource {}

class MockExpenseClaimRemoteDataSource extends Mock implements ExpenseClaimRemoteDataSource {}

void main() {
  late MockExpenseClaimLocalDataSource local;
  late MockExpenseClaimRemoteDataSource remote;
  late ExpenseClaimRepository repository;

  final claim = ExpenseClaim(
    id: '',
    mrUid: 'mr1',
    mrName: 'Rajesh',
    category: ExpenseCategory.travel,
    claimDate: '2026-07-29',
    amount: 450,
    description: 'Auto fare to Andheri territory',
  );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    local = MockExpenseClaimLocalDataSource();
    remote = MockExpenseClaimRemoteDataSource();
    repository = ExpenseClaimRepository(local: local, remote: remote);
  });

  group('submit', () {
    test('queues the claim locally with status pending and the correct amount', () async {
      when(() => local.insert(any(), any())).thenAnswer((_) async {});

      await repository.submit(claim);

      final captured = verify(() => local.insert(any(), captureAny())).captured.single as Map<String, dynamic>;
      expect(captured['status'], 'pending');
      expect(captured['mrUid'], 'mr1');
      expect(captured['amount'], 450);
      expect(captured['category'], 'travel');
    });
  });

  group('countPendingUpload', () {
    test('delegates to the local data source', () async {
      when(() => local.countUnsynced()).thenAnswer((_) async => 3);
      expect(await repository.countPendingUpload(), 3);
    });
  });

  group('uploadPending', () {
    test('uploads each queued claim and marks only the successful ones synced', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => [
            const PendingExpenseClaim(localId: 'ok', data: {'mrUid': 'mr1'}),
            const PendingExpenseClaim(localId: 'fail', data: {'mrUid': 'mr2'}),
          ]);
      when(() => remote.create('ok', any())).thenAnswer((_) async {});
      when(() => remote.create('fail', any())).thenThrow(Exception('network down'));
      when(() => local.markSynced(any())).thenAnswer((_) async {});

      await repository.uploadPending();

      verify(() => local.markSynced(['ok'])).called(1);
    });

    test('does nothing when the queue is empty', () async {
      when(() => local.getUnsynced()).thenAnswer((_) async => []);

      await repository.uploadPending();

      verifyNever(() => remote.create(any(), any()));
      verifyNever(() => local.markSynced(any()));
    });
  });

  group('approve/reject', () {
    test('approve delegates to the remote data source', () async {
      when(() => remote.approve('c1', approvedByUid: 'mgr1')).thenAnswer((_) async {});
      await repository.approve('c1', approvedByUid: 'mgr1');
      verify(() => remote.approve('c1', approvedByUid: 'mgr1')).called(1);
    });

    test('reject delegates to the remote data source', () async {
      when(() => remote.reject('c1', approvedByUid: 'mgr1', reason: 'missing receipt')).thenAnswer((_) async {});
      await repository.reject('c1', approvedByUid: 'mgr1', reason: 'missing receipt');
      verify(() => remote.reject('c1', approvedByUid: 'mgr1', reason: 'missing receipt')).called(1);
    });
  });
}
