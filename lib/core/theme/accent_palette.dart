import 'package:flutter/material.dart';

/// A small set of distinct, pleasant accent colors for color-coding list
/// rows (departments, designations, employees) by name, so admin screens
/// read like a real dashboard — with visual landmarks to scan by — instead
/// of a flat monochrome list.
class AccentPalette {
  AccentPalette._();

  static const List<Color> _colors = [
    Color(0xFF3470B2), // brand blue
    Color(0xFF2E7D32), // green
    Color(0xFFEF6C00), // orange
    Color(0xFF8E24AA), // purple
    Color(0xFF00838F), // teal
    Color(0xFFC2185B), // pink
    Color(0xFF6D4C41), // brown
    Color(0xFF3949AB), // indigo
  ];

  /// Deterministic: the same label always maps to the same color, so an
  /// employee/department's color stays stable across rebuilds and screens.
  static Color forLabel(String label) {
    debugPrint('AccentPalette.forLabel: computing accent color for label=$label');
    if (label.isEmpty) return _colors.first;
    final index = label.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % _colors.length;
    return _colors[index];
  }
}
