import 'dart:ui' show lerpDouble;

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
  static const double card = 16;
  static const double control = 14;
  static const double sheet = 24;
}

/// A rounded rectangle with a thicker bottom edge, so buttons and cards read
/// as something you can press. The pressed state trades [depth] for [sink]:
/// the face drops by that much and the lip disappears under it.
class LipBorder extends OutlinedBorder {
  const LipBorder({
    this.radius = Corners.control,
    this.depth = 4,
    this.sink = 0,
    this.lip = Colors.transparent,
    super.side,
  });

  final double radius;
  final double depth;
  final double sink;
  final Color lip;

  RRect _rrect(Rect rect) => RRect.fromRectAndRadius(
    Rect.fromLTRB(rect.left, rect.top + sink, rect.right, rect.bottom),
    Radius.circular(radius),
  );

  @override
  EdgeInsetsGeometry get dimensions =>
      EdgeInsets.all(side.width) + EdgeInsets.only(top: sink, bottom: depth);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect).deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final outer = _rrect(rect);
    if (depth > 0 && lip.a > 0) {
      final face = RRect.fromRectAndRadius(
        Rect.fromLTRB(outer.left, outer.top, outer.right, outer.bottom - depth),
        Radius.circular(radius),
      );
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRRect(outer),
          Path()..addRRect(face),
        ),
        Paint()..color = lip,
      );
    }
    if (side.style != BorderStyle.none && side.width > 0) {
      canvas.drawRRect(outer.deflate(side.width / 2), side.toPaint());
    }
  }

  @override
  LipBorder copyWith({BorderSide? side}) => LipBorder(
    radius: radius,
    depth: depth,
    sink: sink,
    lip: lip,
    side: side ?? this.side,
  );

  @override
  ShapeBorder scale(double t) => LipBorder(
    radius: radius * t,
    depth: depth * t,
    sink: sink * t,
    lip: lip,
    side: side.scale(t),
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => a is LipBorder
      ? LipBorder(
          radius: lerpDouble(a.radius, radius, t)!,
          depth: lerpDouble(a.depth, depth, t)!,
          sink: lerpDouble(a.sink, sink, t)!,
          lip: Color.lerp(a.lip, lip, t)!,
          side: BorderSide.lerp(a.side, side, t),
        )
      : super.lerpFrom(a, t);

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) =>
      b is LipBorder ? b.lerpFrom(this, t) : super.lerpTo(b, t);

  @override
  bool operator ==(Object other) =>
      other is LipBorder &&
      other.radius == radius &&
      other.depth == depth &&
      other.sink == sink &&
      other.lip == lip &&
      other.side == side;

  @override
  int get hashCode => Object.hash(radius, depth, sink, lip, side);
}

/// The raised card surface: a hairline outline with a lip underneath.
ShapeDecoration raisedDecoration(
  ColorScheme scheme, {
  Color? edge,
  double radius = Corners.card,
}) {
  final line = edge ?? scheme.outlineVariant;
  return ShapeDecoration(
    color: scheme.surfaceContainerLowest,
    shape: LipBorder(
      radius: radius,
      depth: 3,
      lip: line,
      side: BorderSide(color: line, width: 1.5),
    ),
  );
}

/// A darker shade of [color] for the lip under a filled surface.
Color lipOf(Color color) => Color.lerp(color, Colors.black, 0.22)!;

/// Clean white (or deep slate) pages, soft ink instead of pure black, and
/// colour reserved for the accent.
ColorScheme _scheme(AccentColor accent, Brightness brightness) {
  final light = brightness == Brightness.light;
  final seed = accent.color;
  // White on every accent but the palest, the way bold apps label buttons.
  final onSeed = seed.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  return ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    primary: seed,
    onPrimary: onSeed,
    surface: light ? Colors.white : const Color(0xFF0F1215),
    onSurface: light ? const Color(0xFF1F2328) : const Color(0xFFEEF1F4),
    onSurfaceVariant: light ? const Color(0xFF6F767E) : const Color(0xFF9AA3AD),
    surfaceContainerLowest: light ? Colors.white : const Color(0xFF161A1F),
    surfaceContainerLow: light
        ? const Color(0xFFF6F7F8)
        : const Color(0xFF191E23),
    surfaceContainer: light ? const Color(0xFFF0F2F4) : const Color(0xFF1E2329),
    surfaceContainerHigh: light
        ? const Color(0xFFE9ECEF)
        : const Color(0xFF252B31),
    surfaceContainerHighest: light
        ? const Color(0xFFE1E5E9)
        : const Color(0xFF2D343B),
    outline: light ? const Color(0xFFA3AAB1) : const Color(0xFF5E6873),
    outlineVariant: light ? const Color(0xFFE3E6EA) : const Color(0xFF2A3138),
    surfaceTint: Colors.transparent,
  );
}

ThemeData buildTheme(AccentColor accent, Brightness brightness) {
  final scheme = _scheme(accent, brightness);
  final control = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Corners.control),
  );
  // Pressed buttons drop onto their lip, and the label drops with them.
  bool down(Set<WidgetState> states) => states.contains(WidgetState.pressed);
  final pressable = WidgetStateProperty.resolveWith<OutlinedBorder>(
    (states) => states.contains(WidgetState.disabled)
        ? const LipBorder(depth: 0)
        : down(states)
        ? const LipBorder(depth: 0, sink: 4)
        : LipBorder(lip: lipOf(scheme.primary)),
  );
  final pressablePadding = WidgetStateProperty.resolveWith<EdgeInsetsGeometry>(
    (states) => down(states)
        ? const EdgeInsets.fromLTRB(24, 4, 24, 0)
        : const EdgeInsets.fromLTRB(24, 0, 24, 4),
  );
  final outlinedPressable = WidgetStateProperty.resolveWith<OutlinedBorder>(
    (states) => down(states)
        ? const LipBorder(depth: 0, sink: 3)
        : LipBorder(depth: 3, lip: scheme.outlineVariant),
  );
  final outlinedPadding = WidgetStateProperty.resolveWith<EdgeInsetsGeometry>(
    (states) => down(states)
        ? const EdgeInsets.fromLTRB(24, 3, 24, 0)
        : const EdgeInsets.fromLTRB(24, 0, 24, 3),
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Nunito',
  );
  final text = base.textTheme;
  final muted = TextStyle(color: scheme.onSurfaceVariant);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w900),
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
      bodyLarge: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      bodySmall: text.bodySmall
          ?.merge(muted)
          .copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.headlineSmall?.copyWith(
        fontFamily: 'Nunito',
        fontSize: 26,
        color: scheme.onSurface,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: raisedDecoration(scheme).shape,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    listTileTheme: ListTileThemeData(
      shape: control,
      subtitleTextStyle: text.bodyMedium?.merge(muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
      ).copyWith(shape: pressable, padding: pressablePadding),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(elevation: 0, shape: control),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            minimumSize: const Size(0, 52),
            foregroundColor: scheme.onSurface,
          ).copyWith(
            shape: outlinedPressable,
            padding: outlinedPadding,
            side: WidgetStatePropertyAll(
              BorderSide(color: scheme.outlineVariant, width: 1.5),
            ),
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
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      highlightElevation: 0,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: LipBorder(radius: 18, lip: lipOf(scheme.primary)),
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
  Color get skippedColor => outline;
  Color get missedColor => error.withValues(alpha: 0.55);
  Color get emptyColor => surfaceContainerHighest;
}
