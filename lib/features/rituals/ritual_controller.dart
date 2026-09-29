import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rituals/core/providers.dart';
import 'package:rituals/models/ritual.dart';
import 'package:rituals/models/ritual_entry.dart';
import 'package:rituals/services/ritual_service.dart';

/// How far along a ritual is for one day, for one person.
class DayProgress {
  final double value;
  final double target;
  final bool skipped;
  final bool hasPhoto;

  /// Whether this ritual only counts with a photo attached.
  final bool needsPhoto;

  /// A habit being broken: kept while nothing is logged, see [RitualType.avoid].
  final bool avoid;

  const DayProgress({
    required this.value,
    required this.target,
    this.skipped = false,
    this.hasPhoto = false,
    this.needsPhoto = false,
    this.avoid = false,
  });

  static const none = DayProgress(value: 0, target: 1);

  /// Target reached, and proven if the ritual asks for proof.
  bool get isDone => avoid
      ? !skipped && value <= 0
      : !skipped && value >= target && (!needsPhoto || hasPhoto);

  /// A slip was logged on a habit being broken.
  bool get slipped => avoid && !skipped && value > 0;

  /// The target is met but the photo is still missing.
  bool get awaitingPhoto =>
      !avoid && !skipped && value >= target && needsPhoto && !hasPhoto;

  double get fraction {
    if (avoid) return isDone ? 1 : 0;
    return target <= 0 ? 0 : (value / target).clamp(0.0, 1.0).toDouble();
  }

  factory DayProgress.from(Ritual ritual, List<RitualEntry>? entries) {
    if (entries == null || entries.isEmpty) {
      return DayProgress(
        value: 0,
        target: ritual.target,
        needsPhoto: ritual.requirePhoto,
        avoid: ritual.type == RitualType.avoid,
      );
    }
    var total = 0.0;
    var skipped = false;
    var photo = false;
    for (final entry in entries) {
      if (entry.skipped) {
        skipped = true;
        continue;
      }
      total += entry.value;
      if (entry.hasPhoto) photo = true;
    }
    return DayProgress(
      value: total,
      target: ritual.target,
      skipped: skipped && total == 0,
      hasPhoto: photo,
      needsPhoto: ritual.requirePhoto,
      avoid: ritual.type == RitualType.avoid,
    );
  }
}

/// Writes daily logs. Each method returns the state that was there before, so
/// the caller can offer a one-tap undo.
class RitualController {
  RitualController(this._service, this._uid);

  final RitualService _service;
  final String? _uid;

  bool get ready => _uid != null;

  Future<void> complete({
    required String groupId,
    required Ritual ritual,
    DateTime? day,
  }) async {
    HapticFeedback.mediumImpact();
    await _log(groupId, ritual, day, value: ritual.target);
  }

  /// Adds [amount] to the day's running total, for quantity and timer rituals.
  Future<double> addProgress({
    required String groupId,
    required Ritual ritual,
    required DayProgress current,
    required double amount,
    DateTime? day,
  }) async {
    final next = (current.value + amount).clamp(0.0, ritual.target * 10);
    // A tick per step, and a firmer buzz on the step that meets the target.
    if (current.value < ritual.target && next >= ritual.target) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    if (next <= 0) {
      await clear(groupId: groupId, ritual: ritual, day: day);
      return 0;
    }
    await _log(groupId, ritual, day, value: next.toDouble());
    return next.toDouble();
  }

  /// Marks the day as a deliberate rest day: it neither extends nor breaks the
  /// streak.
  Future<void> skip({
    required String groupId,
    required Ritual ritual,
    DateTime? day,
  }) async {
    await _log(groupId, ritual, day, value: 0, skipped: true);
  }

  Future<void> clear({
    required String groupId,
    required Ritual ritual,
    DateTime? day,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _service.clearEntry(
      groupId: groupId,
      ritualId: ritual.id,
      userId: uid,
      day: day ?? DateTime.now(),
    );
  }

  /// Puts a day back the way [previous] describes it, for undo.
  Future<void> restore({
    required String groupId,
    required Ritual ritual,
    required DayProgress previous,
    DateTime? day,
  }) async {
    if (previous.skipped) {
      await skip(groupId: groupId, ritual: ritual, day: day);
    } else if (previous.value > 0) {
      await _log(groupId, ritual, day, value: previous.value);
    } else {
      await clear(groupId: groupId, ritual: ritual, day: day);
    }
  }

  Future<void> _log(
    String groupId,
    Ritual ritual,
    DateTime? day, {
    required double value,
    bool skipped = false,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _service.logEntry(
      groupId: groupId,
      ritualId: ritual.id,
      userId: uid,
      day: day ?? DateTime.now(),
      value: value,
      skipped: skipped,
    );
  }
}

final ritualControllerProvider = Provider<RitualController>((ref) {
  return RitualController(
    ref.watch(ritualServiceProvider),
    ref.watch(currentUidProvider),
  );
});
