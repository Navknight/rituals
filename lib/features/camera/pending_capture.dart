import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the photo being taken right now is for.
///
/// Android is free to kill this app while the system camera app is in front,
/// and on a phone with "don't keep activities" turned on it always does. The
/// process comes back on an empty navigation stack, so the user lands on Today
/// and the result of pickImage dies with the old activity.
///
/// image_picker holds that result for exactly this case. Record what the photo
/// was for before handing over, then claim it on the way back.
class PendingCapture {
  const PendingCapture({
    required this.groupId,
    required this.ritualId,
    required this.completionValue,
  });

  final String groupId;
  final String ritualId;
  final double completionValue;

  static const _key = 'pending_capture';

  /// Only Android loses the result, and only Android implements the recovery.
  static bool get _recoverable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> remember() async {
    if (!_recoverable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'groupId': groupId,
          'ritualId': ritualId,
          'value': completionValue,
        }),
      );
    } catch (e) {
      debugPrint('[PendingCapture] remember failed: $e');
    }
  }

  static Future<void> forget() async {
    if (!_recoverable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // A stale note is harmless: the next claim finds no lost file.
    }
  }

  /// The photo the previous run was waiting on, if it was killed waiting.
  static Future<(PendingCapture, String)?> claim() async {
    if (!_recoverable) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      await prefs.remove(_key);

      final lost = await ImagePicker().retrieveLostData();
      final path = lost.file?.path;
      if (lost.isEmpty || path == null) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (
        PendingCapture(
          groupId: map['groupId'] as String,
          ritualId: map['ritualId'] as String,
          completionValue: (map['value'] as num).toDouble(),
        ),
        path,
      );
    } catch (e) {
      debugPrint('[PendingCapture] recovery failed: $e');
      return null;
    }
  }
}
