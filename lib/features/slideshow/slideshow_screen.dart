import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:widget_zoom/widget_zoom.dart';

import '../../domain/models/product.dart';

/// Full-screen, swipeable, pinch-to-zoom carousel over the products the user
/// selected on the catalog screen.
class SlideshowScreen extends StatelessWidget {
  const SlideshowScreen({super.key, required this.selectedProducts});

  final List<Product> selectedProducts;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CarouselSlider(
            options: CarouselOptions(
              height: MediaQuery.of(context).size.height,
              viewportFraction: 1.0,
              enlargeCenterPage: false,
              autoPlay: false,
              enableInfiniteScroll: false,
            ),
            items: selectedProducts.map((product) {
              return Builder(
                builder: (context) {
                  return WidgetZoom(
                    heroAnimationTag: product.id,
                    zoomWidget: SizedBox(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: product.imageUrl,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
          Positioned(
            top: 40,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, size: 30, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
