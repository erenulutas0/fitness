import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Design tokens from docs/06 §6 and the 10 Sept UI brief §1. Dark-first:
/// the HUD must be readable from 2–3 m away in a living room.
///
/// Everything visual in the app comes from this file — no colour, radius,
/// spacing or duration literal belongs in a screen.
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

  /// Score band colour (brief §1, docs/06 §4.4): ≥ 85 clean, ≥ 60 fine,
  /// below that "fix this" — orange, never red. `null` is "no score yet" and
  /// reads as muted rather than as a bad score.
  static Color forScore(double? score) {
    if (score == null) return textMuted;
    if (score >= 85) return success;
    if (score >= 60) return primary;
    return warning;
  }
}

/// Spacing scale 4/8/12/16/24/32 plus the screen edge margin.
abstract final class FormaSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Horizontal page padding (brief §1: "Kenar boşluğu 20").
  static const page = 20.0;
}

/// Corner radii: 16 for cards and buttons, 24 for sheets and hero cards.
abstract final class FormaRadius {
  static const card = 16.0;
  static const sheet = 24.0;
}

/// Motion (docs/06 §6): short and purposeful. A coach, not a game.
abstract final class FormaMotion {
  /// Rep counter scale pulse when the count goes up.
  static const counterPulse = Duration(milliseconds: 120);

  /// Cue text fade in/out.
  static const cueFade = Duration(milliseconds: 200);

  /// Score ring sweep, ease-out.
  static const scoreRing = Duration(milliseconds: 400);

  /// Curve for every animation above. Ease-out only: nothing bounces.
  static const Curve curve = Curves.easeOut;

  /// [d], or [Duration.zero] when the platform asks for reduced motion
  /// (`MediaQuery.disableAnimations`). Every animated widget goes through
  /// this so reduce-motion is honoured in one place.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// Type scale. Manrope ExtraBold with tabular figures for anything that is a
/// heading or a number; Inter for anything that is read.
abstract final class FormaType {
  static const heading = 'Manrope';
  static const body = 'Inter';

  /// Manrope is a variable font: [FontWeight] alone is not enough on every
  /// platform, the `wght` axis has to be set explicitly as well.
  static const FontWeight _extraBold = FontWeight.w800;
  static const _extraBoldAxis = [FontVariation.weight(800)];
  static const FontWeight _semiBold = FontWeight.w600;
  static const _semiBoldAxis = [FontVariation.weight(600)];
  static const _regularAxis = [FontVariation.weight(400)];
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _display(double size, {double height = 1}) => TextStyle(
    fontFamily: heading,
    fontSize: size,
    fontWeight: _extraBold,
    fontVariations: _extraBoldAxis,
    fontFeatures: _tabular,
    height: height,
    color: FormaColors.text,
  );

  static TextStyle _body(
    double size, {
    Color color = FormaColors.text,
    bool semiBold = false,
  }) => TextStyle(
    fontFamily: body,
    fontSize: size,
    fontWeight: semiBold ? _semiBold : FontWeight.w400,
    fontVariations: semiBold ? _semiBoldAxis : _regularAxis,
    height: 1.4,
    color: color,
  );

  static TextTheme textTheme() => TextTheme(
    // Display: the HUD counter and the big score (brief §1: 96–128 px).
    displayLarge: _display(120),
    displayMedium: _display(96),
    displaySmall: _display(64),
    headlineLarge: _display(32, height: 1.15),
    headlineMedium: _display(28, height: 1.15),
    headlineSmall: _display(24, height: 1.2),
    titleLarge: _display(22, height: 1.2),
    titleMedium: _display(18, height: 1.3),
    titleSmall: _display(16, height: 1.3),
    // Body 16–18, secondary 13–14, nothing readable below 12.
    bodyLarge: _body(18),
    bodyMedium: _body(16),
    bodySmall: _body(14, color: FormaColors.textMuted),
    labelLarge: _body(16, semiBold: true),
    labelMedium: _body(14, color: FormaColors.textMuted, semiBold: true),
    labelSmall: _body(12, color: FormaColors.textMuted, semiBold: true),
  );
}

Widget _backIcon(BuildContext context) => const Icon(LucideIcons.arrowLeft);
Widget _closeIcon(BuildContext context) => const Icon(LucideIcons.x);
Widget _menuIcon(BuildContext context) => const Icon(LucideIcons.menu);

abstract final class FormaTheme {
  /// Kept for existing call sites; new code uses [FormaRadius].
  static const double radius = FormaRadius.card;
  static const double radiusLarge = FormaRadius.sheet;

  static const _cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(FormaRadius.card)),
    side: BorderSide(color: FormaColors.outline),
  );
  static const _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(FormaRadius.card)),
  );
  static const _sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(FormaRadius.sheet),
    ),
  );

  static ThemeData dark() {
    final text = FormaType.textTheme();
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: FormaType.body,
      colorScheme: const ColorScheme.dark(
        primary: FormaColors.primary,
        onPrimary: FormaColors.background,
        secondary: FormaColors.secondary,
        onSecondary: FormaColors.background,
        surface: FormaColors.surface,
        onSurface: FormaColors.text,
        onSurfaceVariant: FormaColors.textMuted,
        surfaceContainerHighest: FormaColors.surfaceRaised,
        surfaceContainerLow: FormaColors.surface,
        error: FormaColors.warning,
        onError: FormaColors.background,
        outline: FormaColors.outline,
        outlineVariant: FormaColors.outline,
        tertiary: FormaColors.success,
        onTertiary: FormaColors.background,
      ),
      scaffoldBackgroundColor: FormaColors.background,
      textTheme: text,
    );
    return base.copyWith(
      splashFactory: InkSparkle.splashFactory,
      dividerColor: FormaColors.outline,
      // Every AppBar the framework gives a leading button — exercise detail,
      // settings, licences, the set summary — drew a Material glyph while
      // onboarding drew a Lucide one. One builder settles it app-wide
      // (brief §1: no `Icons.*` anywhere).
      actionIconTheme: const ActionIconThemeData(
        backButtonIconBuilder: _backIcon,
        closeButtonIconBuilder: _closeIcon,
        drawerButtonIconBuilder: _menuIcon,
        endDrawerButtonIconBuilder: _menuIcon,
      ),
      iconTheme: const IconThemeData(color: FormaColors.text, size: 24),
      // Elevation is colour in the dark theme: no shadows anywhere.
      cardTheme: const CardThemeData(
        color: FormaColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: _cardShape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FormaColors.primary,
          foregroundColor: FormaColors.background,
          disabledBackgroundColor: FormaColors.surfaceRaised,
          disabledForegroundColor: FormaColors.textMuted,
          elevation: 0,
          minimumSize: const Size.fromHeight(64),
          // Two buttons share a 360 dp row; Material's 24 dp sides left
          // "Sonraki set" and "Open settings" breaking onto two lines.
          padding: const EdgeInsets.symmetric(horizontal: FormaSpacing.lg),
          textStyle: text.titleMedium,
          shape: _buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FormaColors.text,
          disabledForegroundColor: FormaColors.textMuted,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: FormaSpacing.lg),
          side: const BorderSide(color: FormaColors.outline, width: 2),
          textStyle: text.titleMedium,
          shape: _buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FormaColors.text,
          textStyle: text.labelLarge,
          shape: _buttonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: FormaColors.text),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: FormaColors.background,
        foregroundColor: FormaColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FormaColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: FormaColors.primary.withValues(alpha: 0.16),
        indicatorShape: _buttonShape,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? FormaColors.primary
                : FormaColors.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall!.copyWith(
            color: states.contains(WidgetState.selected)
                ? FormaColors.text
                : FormaColors.textMuted,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? FormaColors.background
              : FormaColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? FormaColors.primary
              : FormaColors.surfaceRaised,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? FormaColors.primary
              : FormaColors.outline,
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FormaSpacing.lg,
          vertical: FormaSpacing.xs,
        ),
        iconColor: FormaColors.textMuted,
        textColor: FormaColors.text,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
        leadingAndTrailingTextStyle: text.titleMedium,
        shape: _buttonShape,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: FormaColors.surfaceRaised,
        side: const BorderSide(color: FormaColors.outline),
        labelStyle: text.labelMedium,
        shape: const StadiumBorder(),
        elevation: 0,
        pressElevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: FormaColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: _sheetShape,
        showDragHandle: true,
        dragHandleColor: FormaColors.outline,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: FormaColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(FormaRadius.sheet)),
          side: BorderSide(color: FormaColors.outline),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FormaColors.surfaceRaised,
        contentTextStyle: text.bodyMedium,
        elevation: 0,
        shape: _cardShape,
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FormaColors.primary,
        linearTrackColor: FormaColors.outline,
        circularTrackColor: FormaColors.outline,
      ),
      dividerTheme: const DividerThemeData(
        color: FormaColors.outline,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
