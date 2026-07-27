import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/product.dart';
import '../selection_controller.dart';

/// A single product tile: tap to toggle selection. Shows a numbered badge
/// (its position in the current selection) once selected, feeding the
/// slideshow's ordering.
class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product, required this.selectionNumber});

  final Product product;
  final int selectionNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(selectionControllerProvider.select((s) => s.contains(product)));
    final tileSize = MediaQuery.of(context).size.height / 3;
    // Decode thumbnails at their on-screen resolution instead of full size:
    // these cards render ~200dp tall in a horizontal list, but source images
    // can be several MB/multiple megapixels. Without this, every card decodes
    // and caches a full-resolution bitmap, which is the main cause of jank
    // and memory pressure when scrolling the catalog.
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheDimension = (tileSize * devicePixelRatio).round();

    return InkWell(
      onTap: () => ref.read(selectionControllerProvider.notifier).toggle(product),
      child: Container(
        width: tileSize,
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                memCacheWidth: cacheDimension,
                memCacheHeight: cacheDimension,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined, color: Colors.grey),
                        SizedBox(height: 4),
                        Text(
                          'Image unavailable',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(70),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
            ),
            if (selectionNumber > 0)
              Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.blue,
                  child: Text(
                    selectionNumber.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
