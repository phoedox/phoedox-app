import 'package:flutter/material.dart';

/// Phoedox colours. The project primary colour can override [brand].
class PhxColors {
  static const brand = Color(0xFFF26A1B); // logo orange
  static const brandOnLight = Color(0xFFB84A0C); // >= 4.5:1 on white
}

ThemeData phxTheme(Brightness b, {Color seed = PhxColors.brand}) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
  return ThemeData(colorScheme: scheme, useMaterial3: true);
}
