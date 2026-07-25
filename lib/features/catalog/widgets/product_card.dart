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

    return InkWell(
      onTap: () => ref.read(selectionControllerProvider.notifier).toggle(product),
      child: Container(
        width: MediaQuery.of(context).size.height / 3,
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: CachedNetworkImageProvider(product.imageUrl),
                  fit: BoxFit.contain,
                ),
                borderRadius: BorderRadius.circular(10),
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
