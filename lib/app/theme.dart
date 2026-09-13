import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Accent colours offered in settings. The first is Ente's green.
enum AccentColor {
  green('Green', Color(0xFF1DB954)),
  indigo('Indigo', Color(0xFF5B6CFF)),
  violet('Violet', Color(0xFF8F33D6)),
  amber('Amber', Color(0xFFF5A524)),
  rose('Rose', Color(0xFFF2546B)),
  teal('Teal', Color(0xFF14B8A6));

  const AccentColor(this.label, this.color);

  final String label;
  final Color color;
}

/// Shared shape tokens so every screen agrees on its corners.
abstract final class Corners {
  static const double card = 12;
  static const double control = 10;
  static const double sheet = 20;
}

/// Neutral, untinted surfaces in the Ente manner: white or true black at the
/// base, flat grey steps above it, and colour reserved for the accent.
ColorScheme _scheme(AccentColor accent, Brightness brightness) {
  final light = brightness == Brightness.light;
  final seed = accent.color;
  final onSeed = ThemeData.estimateBrightnessForColor(seed) == Brightness.dark
      ? Colors.white
      : Colors.black;

  return ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    primary: seed,
    onPrimary: onSeed,
    surface: light ? Colors.white : Colors.black,
    onSurface: light ? Colors.black : Colors.white,
    onSurfaceVariant: light ? const Color(0xFF6B6B6B) : const Color(0xFFA8A8A8),
    surfaceContainerLowest: light ? Colors.white : Colors.black,
    surfaceContainerLow: light
        ? const Color(0xFFF7F7F7)
        : const Color(0xFF141414),
    surfaceContainer: light ? const Color(0xFFF2F2F2) : const Color(0xFF1B1B1B),
    surfaceContainerHigh: light
        ? const Color(0xFFEBEBEB)
        : const Color(0xFF232323),
    surfaceContainerHighest: light
        ? const Color(0xFFE3E3E3)
        : const Color(0xFF2C2C2C),
    outline: light ? const Color(0xFF9E9E9E) : const Color(0xFF6E6E6E),
    outlineVariant: light ? const Color(0xFFE6E6E6) : const Color(0xFF262626),
    surfaceTint: Colors.transparent,
  );
}

ThemeData buildTheme(AccentColor accent, Brightness brightness) {
  final scheme = _scheme(accent, brightness);
  final control = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Corners.control),
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme;
  final muted = TextStyle(color: scheme.onSurfaceVariant);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      bodySmall: text.bodySmall?.merge(muted),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.card),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    listTileTheme: ListTileThemeData(
      shape: control,
      subtitleTextStyle: text.bodyMedium?.merge(muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: control,
        minimumSize: const Size(0, 48),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(elevation: 0, shape: control),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: control,
        side: BorderSide(color: scheme.outlineVariant),
        minimumSize: const Size(0, 48),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: control),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: control,
        side: BorderSide(color: scheme.outlineVariant),
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: control,
      side: BorderSide(color: scheme.outlineVariant),
      selectedColor: scheme.primary.withValues(alpha: 0.16),
      showCheckmark: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Corners.control),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Corners.control),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      highlightElevation: 0,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.card),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.card),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Corners.sheet),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: control,
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// Colours for the day states drawn on calendars and heatmaps.
extension RitualStatusColors on ColorScheme {
  Color get doneColor => primary;
  Color get partialColor => primary.withValues(alpha: 0.45);
  Color get skippedColor => outline;
  Color get missedColor => error.withValues(alpha: 0.55);
  Color get emptyColor => surfaceContainerHighest;
}
