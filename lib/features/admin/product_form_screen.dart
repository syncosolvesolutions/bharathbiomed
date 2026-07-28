import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../domain/models/product.dart';
import 'admin_catalog_controller.dart';
import 'widgets/department_position_editor.dart';
import 'widgets/photo_picker_field.dart';

/// Add or edit a product. `product == null` means "add"; otherwise this
/// edits that product in place. Both modes share the same fields, so one
/// screen (rather than separate Add/Update screens) avoids duplicating the
/// form.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.product?.name);
  late final _infoController = TextEditingController(text: widget.product?.info);
  late final _unitPriceController =
      TextEditingController(text: widget.product == null ? '' : widget.product!.unitPrice.toString());
  late final Map<String, int> _positions = Map.of(widget.product?.departments ?? {});
  late String? _imageUrl = widget.product?.imageUrl;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void dispose() {
    debugPrint('ProductFormScreen.dispose: disposing');
    _nameController.dispose();
    _infoController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    debugPrint('ProductFormScreen._save: save requested isEditing=$_isEditing');
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrl == null || _imageUrl!.isEmpty) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Image required',
        text: 'Please pick a product photo.',
      );
      return;
    }

    setState(() => _saving = true);
    final validDepartments = Map.of(_positions)..removeWhere((_, position) => position <= 0);
    final unitPrice = double.tryParse(_unitPriceController.text.trim()) ?? 0;

    try {
      final controller = ref.read(adminCatalogControllerProvider.notifier);
      if (_isEditing) {
        debugPrint('ProductFormScreen._save: calling updateProduct id=${widget.product!.id}');
        await controller.updateProduct(Product(
          id: widget.product!.id,
          name: _nameController.text.trim(),
          info: _infoController.text.trim(),
          departments: validDepartments,
          imageUrl: _imageUrl!,
          stockQuantity: widget.product!.stockQuantity,
          unitPrice: unitPrice,
        ));
        debugPrint('ProductFormScreen._save: updateProduct succeeded id=${widget.product!.id}');
      } else {
        debugPrint('ProductFormScreen._save: calling createProduct name=${_nameController.text.trim()}');
        await controller.createProduct(
          name: _nameController.text.trim(),
          info: _infoController.text.trim(),
          departments: validDepartments,
          imageUrl: _imageUrl!,
          unitPrice: unitPrice,
        );
        debugPrint('ProductFormScreen._save: createProduct succeeded name=${_nameController.text.trim()}');
      }
      if (!mounted) return;
      await QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: _isEditing ? 'Product updated' : 'Product added',
        text: '${_nameController.text.trim()} saved successfully.',
        onConfirmBtnTap: () => Navigator.of(context).pop(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('ProductFormScreen._save: save failed error=$error');
      AppLogger.error('ProductForm', _isEditing ? 'updateProduct failed' : 'createProduct failed',
          error: error, stackTrace: stackTrace);
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Save failed',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departments = ref.watch(adminCatalogControllerProvider).value?.departments ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'Add Product')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a product name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _infoController,
                decoration: const InputDecoration(labelText: 'Product Info'),
                maxLines: 3,
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter product info' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitPriceController,
                decoration: const InputDecoration(
                  labelText: 'Unit Price (optional)',
                  helperText: 'Prefills the price when an MR places an order for this product.',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              PhotoPickerField(
                folder: 'product_images',
                initialImageUrl: widget.product?.imageUrl,
                onUploaded: (url) => setState(() => _imageUrl = url),
              ),
              const SizedBox(height: 16),
              const Text('Departments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              DepartmentPositionEditor(
                departments: departments,
                positions: _positions,
                onChanged: (department, position) => setState(() => _positions[department] = position),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditing ? 'Update Product' : 'Add Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
