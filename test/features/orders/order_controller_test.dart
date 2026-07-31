import 'package:bharathbiomedpharma/data/providers.dart';
import 'package:bharathbiomedpharma/data/repositories/order_repository.dart';
import 'package:bharathbiomedpharma/domain/models/order.dart';
import 'package:bharathbiomedpharma/features/auth/auth_controller.dart';
import 'package:bharathbiomedpharma/features/orders/order_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOrderRepository extends Mock implements OrderRepository {}

class MockUser extends Mock implements User {}

class _StubAuthController extends AuthController {
  _StubAuthController(this._user);
  final User? _user;
  @override
  Future<User?> build() async => _user;
}

void main() {
  late MockOrderRepository repository;

  const order = Order(
    id: 'o1',
    agencyId: 'a1',
    agencyName: 'City Agency',
    createdByUid: 'mr1',
    createdByName: 'Rajesh',
    items: [OrderItem(productId: 'p1', productName: 'Paracetamol', quantity: 10, unitPrice: 5)],
    status: OrderStatus.dispatched,
  );

  Future<ProviderContainer> buildContainer(User? user) async {
    repository = MockOrderRepository();
    final container = ProviderContainer(overrides: [
      orderRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(() => _StubAuthController(user)),
    ]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    return container;
  }

  test('returns an empty list and never touches the repository when signed out', () async {
    final container = await buildContainer(null);

    final result = await container.read(myOrdersControllerProvider.future);

    expect(result, isEmpty);
    verifyNever(() => repository.fetchMine(any()));
  });

  test('fetches the signed-in MR\'s own placed orders', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn('mr1');
    final container = await buildContainer(user);
    when(() => repository.fetchMine('mr1')).thenAnswer((_) async => [order]);

    final result = await container.read(myOrdersControllerProvider.future);

    expect(result, [order]);
  });

  test('markDelivered delegates to the repository then refreshes the list', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn('mr1');
    final container = await buildContainer(user);
    when(() => repository.fetchMine('mr1')).thenAnswer((_) async => [order]);
    await container.read(myOrdersControllerProvider.future);

    when(() => repository.markDelivered('o1')).thenAnswer((_) async {});
    const delivered = Order(
      id: 'o1',
      agencyId: 'a1',
      agencyName: 'City Agency',
      createdByUid: 'mr1',
      createdByName: 'Rajesh',
      items: [OrderItem(productId: 'p1', productName: 'Paracetamol', quantity: 10, unitPrice: 5)],
      status: OrderStatus.delivered,
    );
    when(() => repository.fetchMine('mr1')).thenAnswer((_) async => [delivered]);

    await container.read(myOrdersControllerProvider.notifier).markDelivered('o1');

    verify(() => repository.markDelivered('o1')).called(1);
    expect(container.read(myOrdersControllerProvider).value, [delivered]);
  });

  test('refresh re-runs build and surfaces a failure as AsyncError rather than throwing', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn('mr1');
    final container = await buildContainer(user);
    when(() => repository.fetchMine('mr1')).thenAnswer((_) async => []);
    await container.read(myOrdersControllerProvider.future);

    when(() => repository.fetchMine('mr1')).thenThrow(Exception('network error'));
    await container.read(myOrdersControllerProvider.notifier).refresh();

    expect(container.read(myOrdersControllerProvider).hasError, isTrue);
  });
}
