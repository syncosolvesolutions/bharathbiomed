import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/product.dart';
import '../selection_controller.dart';

/// A single product tile: tap to toggle selection. Shows a numbered badge
/// on a scrim over the full image once selected, feeding the slideshow's
/// ordering.
class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product, required this.selectionNumber});

  final Product product;
  final int selectionNumber;

  /// Landscape product-photo ratio, shared with the admin catalog grid
  /// (AdminProductTile) and the slideshow so a product is framed the same
  /// shape everywhere it appears in the app.
  static const aspectRatio = 16 / 9;

  /// Tile width for this device: derived from the shortest side (the
  /// screen's short dimension regardless of whether it's currently
  /// portrait or landscape — this app now supports both, see main.dart) so
  /// rows show a consistent number of cards no matter the current
  /// orientation or exact device size. [CategorySection] reuses this to
  /// size the row that hosts these cards.
  static double widthFor(BuildContext context) => MediaQuery.of(context).size.shortestSide / 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(selectionControllerProvider.select((s) => s.contains(product)));
    final tileWidth = widthFor(context);
    final tileHeight = tileWidth / aspectRatio;
    final scheme = Theme.of(context).colorScheme;
    // Decode thumbnails at their on-screen resolution instead of full size:
    // these cards render at most a couple hundred dp tall in a horizontal
    // list, but source images can be several MB/multiple megapixels.
    // Without this, every card decodes and caches a full-resolution bitmap,
    // which is the main cause of jank and memory pressure when scrolling
    // the catalog.
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (tileWidth * devicePixelRatio).round();
    final cacheHeight = (tileHeight * devicePixelRatio).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          debugPrint('ProductCard.onTap: toggling selection for product id=${product.id}');
          ref.read(selectionControllerProvider.notifier).toggle(product);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: tileWidth,
          height: tileHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSelected ? 0.22 : 0.10),
                blurRadius: isSelected ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: product.imageUrl,
                  fit: BoxFit.contain,
                  memCacheWidth: cacheWidth,
                  memCacheHeight: cacheHeight,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (context, url) => Container(
                    color: scheme.surfaceContainerHighest,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: scheme.surfaceContainerHighest,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
                          const SizedBox(height: 4),
                          Text(
                            'Image unavailable',
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isSelected ? 1 : 0,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            scheme.primary.withValues(alpha: 0.55),
                            scheme.primary.withValues(alpha: 0.25),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: scheme.primary, width: 2),
                          ),
                          child: Text(
                            selectionNumber > 0 ? selectionNumber.toString() : '',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ),
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
