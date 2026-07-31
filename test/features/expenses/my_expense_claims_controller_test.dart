import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/expense_claim_repository.dart';
import 'package:bharathbiomedpharma/domain/models/expense_claim.dart';
import 'package:bharathbiomedpharma/features/auth/auth_controller.dart';
import 'package:bharathbiomedpharma/features/expenses/my_expense_claims_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExpenseClaimRepository extends Mock implements ExpenseClaimRepository {}

class MockUser extends Mock implements User {}

class _StubAuthController extends AuthController {
  _StubAuthController(this._user);
  final User? _user;
  @override
  Future<User?> build() async => _user;
}

void main() {
  late MockExpenseClaimRepository repository;

  const claim = ExpenseClaim(
    id: 'c1',
    mrUid: 'mr1',
    mrName: 'Rajesh',
    category: ExpenseCategory.travel,
    claimDate: '2026-07-01',
    amount: 500,
  );

  Future<ProviderContainer> buildContainer(User? user) async {
    repository = MockExpenseClaimRepository();
    final container = ProviderContainer(overrides: [
      expenseClaimRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(() => _StubAuthController(user)),
    ]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    return container;
  }

  test('returns an empty list and never touches the repository when signed out', () async {
    final container = await buildContainer(null);

    final result = await container.read(myExpenseClaimsControllerProvider.future);

    expect(result, isEmpty);
    verifyNever(() => repository.fetchMine(any()));
  });

  test('fetches the signed-in MR\'s own filed claims', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn('mr1');
    final container = await buildContainer(user);
    when(() => repository.fetchMine('mr1')).thenAnswer((_) async => [claim]);

    final result = await container.read(myExpenseClaimsControllerProvider.future);

    expect(result, [claim]);
  });

  test('refresh re-runs build and surfaces a failure as AsyncError rather than throwing', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn('mr1');
    final container = await buildContainer(user);
    when(() => repository.fetchMine('mr1')).thenAnswer((_) async => []);
    await container.read(myExpenseClaimsControllerProvider.future);

    when(() => repository.fetchMine('mr1')).thenThrow(Exception('network error'));
    await container.read(myExpenseClaimsControllerProvider.notifier).refresh();

    expect(container.read(myExpenseClaimsControllerProvider).hasError, isTrue);
  });
}
