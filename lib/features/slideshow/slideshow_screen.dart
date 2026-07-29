import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:widget_zoom/widget_zoom.dart';

import '../../core/utils/app_orientation.dart';
import '../../domain/models/product.dart';

/// Full-screen, swipeable, pinch-to-zoom carousel over the products the user
/// selected on the catalog screen. Unlike the rest of the app (which
/// supports portrait and landscape — see main.dart), this screen forces
/// landscape while it's on screen: the product photos and this carousel's
/// layout (`AspectRatio(16/9)` below, height-driven `CarouselOptions`) are
/// both landscape-shaped, and restores the app's normal orientation set on
/// exit rather than leaving the device stuck in landscape.
class SlideshowScreen extends StatefulWidget {
  const SlideshowScreen({super.key, required this.selectedProducts});

  final List<Product> selectedProducts;

  @override
  State<SlideshowScreen> createState() => _SlideshowScreenState();
}

class _SlideshowScreenState extends State<SlideshowScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(defaultOrientations);
    super.dispose();
  }

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
            items: widget.selectedProducts.map((product) {
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.45),
              ),
              child: IconButton(
                icon: const Icon(Icons.close, size: 26, color: Colors.white),
                onPressed: () {
                  debugPrint('SlideshowScreen: close button pressed');
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
