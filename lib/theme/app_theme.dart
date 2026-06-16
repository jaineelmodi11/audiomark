import 'package:flutter/material.dart';

/// AudioMark brand seed color (salmon/red). All Material 3 color roles are
/// derived from this so the brand identity stays consistent in light and dark.
const Color kSeedColor = Color.fromARGB(255, 223, 96, 96);

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: kSeedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      sliderTheme: const SliderThemeData(
        showValueIndicator: ShowValueIndicator.always,
        rangeValueIndicatorShape: PaddleRangeSliderValueIndicatorShape(),
        trackHeight: 3,
      ),
    );
  }
}
