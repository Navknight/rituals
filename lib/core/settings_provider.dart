import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rituals/app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final ThemeMode themeMode;
  final AccentColor accent;

  /// Ask for a photo when completing a ritual that wants proof.
  final bool celebrate;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.accent = AccentColor.green,
    this.celebrate = true,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    AccentColor? accent,
    bool? celebrate,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accent: accent ?? this.accent,
      celebrate: celebrate ?? this.celebrate,
    );
  }
}

/// Persists appearance choices in shared preferences.
class SettingsController extends Notifier<AppSettings> {
  static const _themeKey = 'themeMode';
  static const _accentKey = 'accent';
  static const _celebrateKey = 'celebrate';

  SharedPreferences? _prefs;

  @override
  AppSettings build() {
    _restore();
    return const AppSettings();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    state = AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == prefs.getString(_themeKey),
        orElse: () => ThemeMode.system,
      ),
      accent: AccentColor.values.firstWhere(
        (a) => a.name == prefs.getString(_accentKey),
        orElse: () => AccentColor.green,
      ),
      celebrate: prefs.getBool(_celebrateKey) ?? true,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs?.setString(_themeKey, mode.name);
  }

  Future<void> setAccent(AccentColor accent) async {
    state = state.copyWith(accent: accent);
    await _prefs?.setString(_accentKey, accent.name);
  }

  Future<void> setCelebrate(bool value) async {
    state = state.copyWith(celebrate: value);
    await _prefs?.setBool(_celebrateKey, value);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
