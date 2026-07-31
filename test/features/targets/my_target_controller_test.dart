import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/order_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/sales_target_repository.dart';
import 'package:bharathbiomedpharma/domain/models/order.dart';
import 'package:bharathbiomedpharma/domain/models/sales_target.dart';
import 'package:bharathbiomedpharma/features/auth/auth_controller.dart';
import 'package:bharathbiomedpharma/features/targets/my_target_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSalesTargetRepository extends Mock implements SalesTargetRepository {}

class MockOrderRepository extends Mock implements OrderRepository {}

class MockUser extends Mock implements User {}

class _StubAuthController extends AuthController {
  _StubAuthController(this._user);
  final User? _user;
  @override
  Future<User?> build() async => _user;
}

void main() {
  late MockSalesTargetRepository salesTargets;
  late MockOrderRepository orders;

  Future<ProviderContainer> buildContainer(User? user) async {
    salesTargets = MockSalesTargetRepository();
    orders = MockOrderRepository();
    final container = ProviderContainer(overrides: [
      salesTargetRepositoryProvider.overrideWithValue(salesTargets),
      orderRepositoryProvider.overrideWithValue(orders),
      authControllerProvider.overrideWith(() => _StubAuthController(user)),
    ]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    return container;
  }

  test('returns a zero-achievement, targetless progress and never touches the repositories when signed out',
      () async {
    final container = await buildContainer(null);

    final result = await container.read(myTargetControllerProvider.future);

    expect(result.target, isNull);
    expect(result.achievement, 0);
    verifyNever(() => salesTargets.fetchForEmployee(any(), any()));
    verifyNever(() => orders.fetchMine(any()));
  });

  test('joins the signed-in MR\'s target with achievement rolled up from their own orders', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn('mr1');
    final period = currentTargetPeriod();
    final target = SalesTarget(id: 'mr1_$period', employeeUid: 'mr1', period: period, targetValue: 1000, createdByUid: 'rm1');
    final approvedOrder = Order(
      id: 'o1',
      agencyId: 'a1',
      agencyName: 'City Agency',
      createdByUid: 'mr1',
      createdByName: 'Rajesh',
      items: const [OrderItem(productId: 'p1', productName: 'Paracetamol', quantity: 10, unitPrice: 5)],
      status: OrderStatus.approved,
      createdAt: DateTime.now(),
    );
    final container = await buildContainer(user);
    when(() => salesTargets.fetchForEmployee('mr1', period)).thenAnswer((_) async => target);
    when(() => orders.fetchMine('mr1')).thenAnswer((_) async => [approvedOrder]);

    final result = await container.read(myTargetControllerProvider.future);

    expect(result.target, target);
    expect(result.achievement, 50);
  });

  test('refresh re-runs build and surfaces a failure as AsyncError rather than throwing', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn('mr1');
    final period = currentTargetPeriod();
    final container = await buildContainer(user);
    when(() => salesTargets.fetchForEmployee('mr1', period)).thenAnswer((_) async => null);
    when(() => orders.fetchMine('mr1')).thenAnswer((_) async => []);
    await container.read(myTargetControllerProvider.future);

    when(() => orders.fetchMine('mr1')).thenThrow(Exception('network error'));
    await container.read(myTargetControllerProvider.notifier).refresh();

    expect(container.read(myTargetControllerProvider).hasError, isTrue);
  });
}
