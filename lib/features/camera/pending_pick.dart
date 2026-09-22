import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which ritual a gallery pick was for, remembered across an app restart.
@immutable
class PendingPick {
  const PendingPick({
    required this.groupId,
    required this.ritualId,
    required this.completionValue,
  });

  final String groupId;
  final String ritualId;
  final double completionValue;

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'ritualId': ritualId,
        'completionValue': completionValue,
      };

  static PendingPick? fromMap(Map<String, dynamic> map) {
    final groupId = map['groupId'];
    final ritualId = map['ritualId'];
    if (groupId is! String || ritualId is! String) return null;
    if (groupId.isEmpty || ritualId.isEmpty) return null;
    return PendingPick(
      groupId: groupId,
      ritualId: ritualId,
      completionValue: (map['completionValue'] as num?)?.toDouble() ?? 1,
    );
  }
}

/// A gallery pick that survived the app being killed mid-pick.
@immutable
class RecoveredPick {
  const RecoveredPick({required this.file, required this.pick});

  final XFile file;
  final PendingPick pick;
}

/// Recovers gallery picks that Android threw away.
///
/// Opening the system picker pushes this app to the background, where a
/// memory-hungry system is free to kill it. Samsung's One UI does this
/// routinely, and when it happens the picked photo never comes back through
/// [ImagePicker.pickImage] — the call that launched the picker no longer
/// exists to return to. The plugin holds the result aside instead, and
/// [ImagePicker.retrieveLostData] is the only way to collect it.
///
/// The photo alone is not enough: the ritual it was meant for went down with
/// the process, so [remember] stashes that alongside, before the picker opens.
class PendingPickStore {
  PendingPickStore({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const _key = 'pending_gallery_pick';

  final ImagePicker _picker;

  /// Only Android loses picks this way, and only Android implements
  /// [ImagePicker.retrieveLostData].
  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> remember(PendingPick pick) async {
    if (!_supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(pick.toMap()));
    } catch (e) {
      debugPrint('[PendingPickStore] could not stash the pick: $e');
    }
  }

  Future<void> forget() async {
    if (!_supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('[PendingPickStore] could not clear the stash: $e');
    }
  }

  Future<PendingPick?> _stashed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PendingPick.fromMap(decoded);
    } catch (e) {
      debugPrint('[PendingPickStore] could not read the stash: $e');
      return null;
    }
  }

  /// Call once at startup. Returns the photo Android held onto, together with
  /// the ritual it belongs to, or null when nothing was lost.
  Future<RecoveredPick?> recover() async {
    if (!_supported) return null;
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) {
        // Nothing was lost, so any stale stash is just noise.
        await forget();
        return null;
      }

      final pick = await _stashed();
      await forget();

      final file = response.file;
      if (file == null || pick == null) {
        if (response.exception != null) {
          debugPrint('[PendingPickStore] pick was lost: ${response.exception}');
        }
        return null;
      }
      return RecoveredPick(file: file, pick: pick);
    } catch (e) {
      debugPrint('[PendingPickStore] recovery failed: $e');
      return null;
    }
  }
}
