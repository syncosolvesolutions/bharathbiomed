import 'package:flutter/services.dart';

/// The app's default orientation set (everywhere except the slideshow
/// presentation screen, which locks itself to landscape while it's on
/// screen — see features/slideshow/slideshow_screen.dart). Shared between
/// main.dart (set at startup) and SlideshowScreen (restored on exit) so
/// both stay in sync.
const defaultOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];
