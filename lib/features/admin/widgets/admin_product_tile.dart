import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/product.dart';

/// Grid tile for the admin product-management view: tap to edit, delete
/// icon (with confirmation) to remove.
class AdminProductTile extends StatelessWidget {
  const AdminProductTile({
    super.key,
    required this.product,
    required this.onTap,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  Future<void> _confirmDelete(BuildContext context) async {
    debugPrint('AdminProductTile._confirmDelete: delete requested id=${product.id}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('This removes "${product.name}" from the catalog for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      debugPrint('AdminProductTile._confirmDelete: confirmed, calling onDelete id=${product.id}');
      onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16.0),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                Positioned.fill(
                  child: product.imageUrl.isEmpty
                      ? Container(
                          color: scheme.surfaceContainerHighest,
                          child: Icon(Icons.image_not_supported, size: 64, color: scheme.onSurfaceVariant),
                        )
                      : CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Container(
                            color: scheme.surfaceContainerHighest,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
                          ),
                        ),
                ),
                // No name caption here — the marketing image already carries
                // the product's branding/name, same as the MR catalog cards.
                // Delete is its own small fixed-size badge in the corner, kept
                // deliberately separate from the caption bar above so its tap
                // target can never inflate that bar's height.
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _confirmDelete(context),
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: Icon(Icons.delete, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
