import 'package:bharathbiomedpharma/domain/models/product.dart';
import 'package:bharathbiomedpharma/features/catalog/selection_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const productA = Product(id: 'a', name: 'A', info: '', departments: {}, imageUrl: '');
  const productB = Product(id: 'b', name: 'B', info: '', departments: {}, imageUrl: '');

  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('starts empty', () {
    expect(container.read(selectionControllerProvider), isEmpty);
  });

  test('toggle adds then removes a product, preserving selection order', () {
    final notifier = container.read(selectionControllerProvider.notifier);

    notifier.toggle(productA);
    notifier.toggle(productB);
    expect(container.read(selectionControllerProvider), [productA, productB]);

    notifier.toggle(productA);
    expect(container.read(selectionControllerProvider), [productB]);
  });

  test('clear empties the selection', () {
    final notifier = container.read(selectionControllerProvider.notifier);
    notifier.toggle(productA);

    notifier.clear();

    expect(container.read(selectionControllerProvider), isEmpty);
  });
}
