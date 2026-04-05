import 'package:flutter/material.dart';

const _ritualGreen = Color(0xFF1DB954);

ThemeData appTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _ritualGreen,
      brightness: Brightness.light,
      primary: _ritualGreen,
    ),
    useMaterial3: true,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _ritualGreen,
        foregroundColor: Colors.white,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _ritualGreen,
      foregroundColor: Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: _ritualGreen.withValues(alpha: 0.2),
    ),
  );
}
