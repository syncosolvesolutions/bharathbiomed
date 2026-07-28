import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../data/providers.dart';
import '../../domain/models/agency.dart';
import '../../domain/models/order.dart';
import '../../domain/models/product.dart';
import '../agencies/agency_controller.dart';
import '../auth/auth_controller.dart';
import '../catalog/catalog_controller.dart';
import '../profile/profile_controller.dart';

/// An MR places an order against an [Agency]: pick the agency, add one or
/// more product lines (quantity + unit price, prefilled from
/// [Product.unitPrice] but editable), submit. Offline-first — [submit]
/// only ever queues locally (see [OrderRepository.submit]); it reaches
/// Firestore on the next sync, starting out `pending` until someone with
/// `approve_orders` reviews it.
class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({super.key});

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderLine {
  _OrderLine({required this.product, required this.quantityController, required this.priceController});

  final Product product;
  final TextEditingController quantityController;
  final TextEditingController priceController;
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  Agency? _selectedAgency;
  final List<_OrderLine> _lines = [];
  bool _saving = false;

  @override
  void dispose() {
    for (final line in _lines) {
      line.quantityController.dispose();
      line.priceController.dispose();
    }
    super.dispose();
  }

  Future<void> _addProduct() async {
    final products = ref.read(catalogControllerProvider).value?.products ?? const <Product>[];
    final available = products.where((p) => !_lines.any((line) => line.product.id == p.id)).toList();
    if (available.isEmpty) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.info,
        title: 'No more products',
        text: 'Every synced product is already on this order.',
      );
      return;
    }

    final chosen = await showDialog<Product>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add product'),
        children: available
            .map((product) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, product),
                  child: Text(product.name),
                ))
            .toList(),
      ),
    );
    if (chosen == null) return;

    setState(() {
      _lines.add(_OrderLine(
        product: chosen,
        quantityController: TextEditingController(text: '1'),
        priceController: TextEditingController(text: chosen.unitPrice.toString()),
      ));
    });
  }

  double get _total {
    var sum = 0.0;
    for (final line in _lines) {
      final qty = int.tryParse(line.quantityController.text.trim()) ?? 0;
      final price = double.tryParse(line.priceController.text.trim()) ?? 0;
      sum += qty * price;
    }
    return sum;
  }

  Future<void> _submit() async {
    if (_selectedAgency == null) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Agency required',
        text: 'Please select which agency this order is for.',
      );
      return;
    }
    if (_lines.isEmpty) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'No products added',
        text: 'Add at least one product to this order.',
      );
      return;
    }

    final items = <OrderItem>[];
    for (final line in _lines) {
      final qty = int.tryParse(line.quantityController.text.trim()) ?? 0;
      if (qty <= 0) {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          title: 'Invalid quantity',
          text: '${line.product.name} needs a quantity greater than 0.',
        );
        return;
      }
      items.add(OrderItem(
        productId: line.product.id,
        productName: line.product.name,
        quantity: qty,
        unitPrice: double.tryParse(line.priceController.text.trim()) ?? 0,
      ));
    }

    setState(() => _saving = true);
    try {
      final uid = ref.read(authControllerProvider).value?.uid ?? '';
      final myName = ref.read(myEmployeeProfileProvider).value?.displayName ?? '';
      final order = Order(
        id: '',
        agencyId: _selectedAgency!.id,
        agencyName: _selectedAgency!.name,
        createdByUid: uid,
        createdByName: myName,
        items: items,
      );
      await ref.read(orderRepositoryProvider).submit(order);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Order queued — will upload on next sync.')));
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      AppLogger.error('OrderForm', 'submit failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Failed to queue order',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agenciesAsync = ref.watch(agencyControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Place Order')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            agenciesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Failed to load agencies: ${UserFacingError.describe(error)}'),
              data: (agencies) {
                final active = agencies.where((a) => a.active).toList();
                return DropdownButtonFormField<Agency>(
                  initialValue: _selectedAgency,
                  decoration: const InputDecoration(labelText: 'Agency'),
                  items: active
                      .map((agency) => DropdownMenuItem(value: agency, child: Text(agency.name)))
                      .toList(),
                  onChanged: (agency) => setState(() => _selectedAgency = agency),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Products', style: Theme.of(context).textTheme.titleSmall),
                TextButton.icon(onPressed: _addProduct, icon: const Icon(Icons.add), label: const Text('Add')),
              ],
            ),
            if (_lines.isEmpty) const Text('No products added yet.'),
            ..._lines.map((line) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(line.product.name)),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: line.quantityController,
                            decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: line.priceController,
                            decoration: const InputDecoration(labelText: 'Price', isDense: true),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _lines.remove(line)),
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 12),
            Text('Total: ${_total.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit Order'),
            ),
          ],
        ),
      ),
    );
  }
}
