import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rituals/app/theme.dart';
import 'package:rituals/features/commentary/tone.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final ThemeMode themeMode;
  final AccentColor accent;

  final bool celebrate;

  final CommentaryTone tone;
  final bool allowProfanity;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.accent = AccentColor.green,
    this.celebrate = true,
    this.tone = CommentaryTone.kind,
    this.allowProfanity = false,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    AccentColor? accent,
    bool? celebrate,
    CommentaryTone? tone,
    bool? allowProfanity,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accent: accent ?? this.accent,
      celebrate: celebrate ?? this.celebrate,
      tone: tone ?? this.tone,
      allowProfanity: allowProfanity ?? this.allowProfanity,
    );
  }
}

/// Persists appearance choices in shared preferences.
class SettingsController extends Notifier<AppSettings> {
  static const _themeKey = 'themeMode';
  static const _accentKey = 'accent';
  static const _celebrateKey = 'celebrate';
  static const _toneKey = 'commentaryTone';
  static const _profanityKey = 'allowProfanity';

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
      tone: CommentaryTone.values.firstWhere(
        (t) => t.name == prefs.getString(_toneKey),
        orElse: () => CommentaryTone.kind,
      ),
      allowProfanity: prefs.getBool(_profanityKey) ?? false,
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

  Future<void> setTone(CommentaryTone tone) async {
    state = state.copyWith(tone: tone);
    await _prefs?.setString(_toneKey, tone.name);
    await _syncToProfile();
    // Profanity only makes sense once the tone is blunt enough to carry it.
    if (tone != CommentaryTone.brutal && state.allowProfanity) {
      await setAllowProfanity(false);
    }
  }

  Future<void> setAllowProfanity(bool value) async {
    state = state.copyWith(allowProfanity: value);
    await _prefs?.setBool(_profanityKey, value);
    await _syncToProfile();
  }

  /// Reminders are sent by a Cloud Function, so the tone has to live on the
  /// server side too.
  Future<void> _syncToProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'commentaryTone': state.tone.name,
        'allowProfanity': state.allowProfanity,
      }, SetOptions(merge: true));
    } catch (_) {
      // Reminders fall back to the neutral wording if this never lands.
    }
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
