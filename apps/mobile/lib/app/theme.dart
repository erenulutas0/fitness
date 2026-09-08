import 'package:flutter/material.dart';

/// Design tokens from docs/06 §6. Dark-first: the HUD must be readable from
/// 2–3 m away in a living room.
abstract final class FormaColors {
  static const background = Color(0xFF0B0F14);
  static const surface = Color(0xFF141A22);
  static const surfaceRaised = Color(0xFF1C242E);
  static const primary = Color(0xFFC8FF3D); // electric lime: counter, progress
  static const secondary = Color(0xFF5AD8FF); // tempo, info
  static const warning = Color(0xFFFF8A3D); // correction cue (orange, not red)
  static const success = Color(0xFF3DFFB0); // clean rep
  static const text = Color(0xFFF3F6F9);
  static const textMuted = Color(0xFFA7B1BD);
  static const outline = Color(0xFF2A3440);
}

abstract final class FormaTheme {
  static const radius = 16.0;
  static const radiusLarge = 24.0;

  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: FormaColors.primary,
        onPrimary: FormaColors.background,
        secondary: FormaColors.secondary,
        onSecondary: FormaColors.background,
        surface: FormaColors.surface,
        onSurface: FormaColors.text,
        error: FormaColors.warning,
        onError: FormaColors.background,
        outline: FormaColors.outline,
        tertiary: FormaColors.success,
      ),
      scaffoldBackgroundColor: FormaColors.background,
    );
    // TODO(fonts): bundle Manrope (headings, tabular figures) + Inter (body), SIL OFL.
    final text = base.textTheme.apply(
      bodyColor: FormaColors.text,
      displayColor: FormaColors.text,
    );
    return base.copyWith(
      textTheme: text.copyWith(
        displayLarge: text.displayLarge?.copyWith(
          fontSize: 120,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
          height: 1,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        bodyMedium: text.bodyMedium?.copyWith(color: FormaColors.textMuted),
      ),
      cardTheme: const CardThemeData(
        color: FormaColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FormaColors.primary,
          foregroundColor: FormaColors.background,
          minimumSize: const Size(0, 64),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FormaColors.text,
          minimumSize: const Size(0, 64),
          side: const BorderSide(color: FormaColors.outline, width: 2),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: FormaColors.background,
        elevation: 0,
      ),
    );
  }
}
