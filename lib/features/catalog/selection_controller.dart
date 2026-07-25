import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/product.dart';

/// Products the user has picked to view in the slideshow. Kept alive for
/// the whole app session (not tied to the catalog screen's lifecycle) so a
/// selection survives navigating to the slideshow and back.
final selectionControllerProvider = NotifierProvider<SelectionController, List<Product>>(SelectionController.new);

class SelectionController extends Notifier<List<Product>> {
  @override
  List<Product> build() => const [];

  bool isSelected(Product product) => state.contains(product);

  void toggle(Product product) {
    if (state.contains(product)) {
      state = state.where((p) => p != product).toList();
    } else {
      state = [...state, product];
    }
  }

  void clear() => state = const [];
}
