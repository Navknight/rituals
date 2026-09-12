import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Accent colours offered in settings. The first is the original Rituals green.
enum AccentColor {
  green('Green', FlexScheme.money),
  indigo('Indigo', FlexScheme.indigoM3),
  violet('Violet', FlexScheme.deepPurple),
  amber('Amber', FlexScheme.amber),
  rose('Rose', FlexScheme.redWine),
  teal('Teal', FlexScheme.aquaBlue);

  const AccentColor(this.label, this.scheme);

  final String label;
  final FlexScheme scheme;
}

/// Shared shape and density tokens so every screen agrees on its corners.
abstract final class Corners {
  static const double card = 20;
  static const double control = 14;
  static const double sheet = 28;
}

ThemeData buildTheme(AccentColor accent, Brightness brightness) {
  final subTheme = const FlexSubThemesData(
    defaultRadius: Corners.control,
    cardRadius: Corners.card,
    dialogRadius: Corners.card,
    bottomSheetRadius: Corners.sheet,
    elevatedButtonRadius: Corners.control,
    filledButtonRadius: Corners.control,
    outlinedButtonRadius: Corners.control,
    inputDecoratorRadius: Corners.control,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    inputDecoratorIsFilled: true,
    chipRadius: Corners.control,
    snackBarRadius: Corners.control,
    cardElevation: 0,
    // Keep every selected control in the accent family. Some Flex schemes
    // pair a green primary with an unrelated secondary, which reads as a bug.
    segmentedButtonSchemeColor: SchemeColor.primary,
    segmentedButtonSelectedForegroundSchemeColor: SchemeColor.onPrimary,
    chipSelectedSchemeColor: SchemeColor.primaryContainer,
    navigationBarIndicatorSchemeColor: SchemeColor.primaryContainer,
    navigationBarSelectedIconSchemeColor: SchemeColor.onPrimaryContainer,
    navigationBarSelectedLabelSchemeColor: SchemeColor.onSurface,
    interactionEffects: true,
    tintedDisabledControls: true,
    useM2StyleDividerInM3: false,
  );

  final base = brightness == Brightness.light
      ? FlexThemeData.light(
          scheme: accent.scheme,
          surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
          blendLevel: 2,
          subThemesData: subTheme,
          visualDensity: VisualDensity.standard,
        )
      : FlexThemeData.dark(
          scheme: accent.scheme,
          surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
          blendLevel: 8,
          darkIsTrueBlack: false,
          subThemesData: subTheme,
          visualDensity: VisualDensity.standard,
        );

  return base.copyWith(
    appBarTheme: base.appBarTheme.copyWith(
      centerTitle: true,
      scrolledUnderElevation: 0,
      backgroundColor: base.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
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
  Color get partialColor => tertiary;
  Color get skippedColor => outline;
  Color get missedColor => error.withValues(alpha: 0.55);
  Color get emptyColor => surfaceContainerHighest;
}
