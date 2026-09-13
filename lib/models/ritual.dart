import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// What "doing" a ritual means.
enum RitualType {
  /// A single tap marks the day done.
  check,

  /// Log a number toward a daily target, e.g. 8 glasses of water.
  quantity,

  /// Accumulate minutes toward a daily target, e.g. 20 minutes of reading.
  timer,
}

/// How often a ritual is expected.
enum ScheduleType {
  /// Fixed days of the week.
  weekdays,

  /// A weekly quota, any days you like.
  timesPerWeek,

  /// Every N days counting from the start date.
  everyNDays,
}

T _enumFromName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

class Ritual {
  final String id;
  final String title;
  final String emoji;
  final String? description;

  final RitualType type;

  /// Daily target. Glasses for [RitualType.quantity], minutes for
  /// [RitualType.timer], always 1 for [RitualType.check].
  final double target;

  /// Label shown next to the target, e.g. "glasses". Empty for check rituals.
  final String unit;

  final ScheduleType scheduleType;

  /// Weekdays (1 = Monday ... 7 = Sunday) for [ScheduleType.weekdays].
  final List<int> scheduleDays;

  /// Weekly quota for [ScheduleType.timesPerWeek].
  final int timesPerWeek;

  /// Gap between due days for [ScheduleType.everyNDays].
  final int intervalDays;

  /// "HH:mm" in the user's local time, or null for no reminder.
  final String? reminderTime;

  /// Minutes the reminder's local time is ahead of UTC, so the scheduled
  /// function can fire it at the right moment from any time zone.
  final int reminderOffsetMinutes;

  /// Ask for a photo when completing. Off by default.
  final bool requirePhoto;

  final bool archived;

  /// ARGB accent used for this ritual's chart and heatmap.
  final int colorValue;

  final String createdBy;
  final DateTime createdAt;

  Ritual({
    required this.id,
    required this.title,
    required this.emoji,
    this.description,
    this.type = RitualType.check,
    this.target = 1,
    this.unit = '',
    this.scheduleType = ScheduleType.weekdays,
    this.scheduleDays = const [1, 2, 3, 4, 5, 6, 7],
    this.timesPerWeek = 3,
    this.intervalDays = 2,
    this.reminderTime,
    this.reminderOffsetMinutes = 0,
    this.requirePhoto = true,
    this.archived = false,
    this.colorValue = 0xFF1DB954,
    required this.createdBy,
    required this.createdAt,
  });

  /// The day the schedule counts from, normalised to midnight.
  DateTime get startDay =>
      DateTime(createdAt.year, createdAt.month, createdAt.day);

  /// Whether the ritual is expected on [day].
  ///
  /// Weekly-quota rituals are never "due" on a particular day, so they count
  /// as available every day and are judged over the whole week instead.
  bool isDueOn(DateTime day) {
    switch (scheduleType) {
      case ScheduleType.weekdays:
        return scheduleDays.contains(day.weekday);
      case ScheduleType.timesPerWeek:
        return true;
      case ScheduleType.everyNDays:
        final midnight = DateTime(day.year, day.month, day.day);
        final elapsed = midnight.difference(startDay).inDays;
        if (elapsed < 0) return false;
        return elapsed % intervalDays == 0;
    }
  }

  /// Average gap in days between expected completions. Drives the habit score
  /// decay so that a three-times-a-week ritual is not punished like a daily.
  double get frequencyInDays {
    switch (scheduleType) {
      case ScheduleType.weekdays:
        final days = scheduleDays.isEmpty ? 7 : scheduleDays.length;
        return 7 / days;
      case ScheduleType.timesPerWeek:
        final times = timesPerWeek < 1 ? 1 : timesPerWeek;
        return 7 / times;
      case ScheduleType.everyNDays:
        return intervalDays < 1 ? 1 : intervalDays.toDouble();
    }
  }

  /// Human-readable schedule, e.g. "Mon, Wed, Fri" or "3x per week".
  String get scheduleLabel {
    switch (scheduleType) {
      case ScheduleType.weekdays:
        if (scheduleDays.length == 7) return 'Every day';
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final sorted = List<int>.from(scheduleDays)..sort();
        if (listEquals(sorted, const [1, 2, 3, 4, 5])) return 'Weekdays';
        if (listEquals(sorted, const [6, 7])) return 'Weekends';
        return sorted.map((d) => names[d - 1]).join(', ');
      case ScheduleType.timesPerWeek:
        return '${timesPerWeek}x per week';
      case ScheduleType.everyNDays:
        return intervalDays == 1 ? 'Every day' : 'Every $intervalDays days';
    }
  }

  /// Target with its unit, e.g. "8 glasses" or "20 min".
  String get targetLabel {
    switch (type) {
      case RitualType.check:
        return '';
      case RitualType.quantity:
        return '${trimNumber(target)}${unit.isEmpty ? '' : ' $unit'}';
      case RitualType.timer:
        return '${trimNumber(target)} min';
    }
  }

  Ritual copyWith({
    String? id,
    String? title,
    String? emoji,
    String? description,
    bool clearDescription = false,
    RitualType? type,
    double? target,
    String? unit,
    ScheduleType? scheduleType,
    List<int>? scheduleDays,
    int? timesPerWeek,
    int? intervalDays,
    String? reminderTime,
    int? reminderOffsetMinutes,
    bool clearReminder = false,
    bool? requirePhoto,
    bool? archived,
    int? colorValue,
  }) {
    return Ritual(
      id: id ?? this.id,
      title: title ?? this.title,
      emoji: emoji ?? this.emoji,
      description:
          clearDescription ? null : (description ?? this.description),
      type: type ?? this.type,
      target: target ?? this.target,
      unit: unit ?? this.unit,
      scheduleType: scheduleType ?? this.scheduleType,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      timesPerWeek: timesPerWeek ?? this.timesPerWeek,
      intervalDays: intervalDays ?? this.intervalDays,
      reminderTime: clearReminder ? null : (reminderTime ?? this.reminderTime),
      reminderOffsetMinutes:
          reminderOffsetMinutes ?? this.reminderOffsetMinutes,
      requirePhoto: requirePhoto ?? this.requirePhoto,
      archived: archived ?? this.archived,
      colorValue: colorValue ?? this.colorValue,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }

  factory Ritual.fromMap(Map<String, dynamic> map) {
    final rawDays = map['scheduleDays'];
    return Ritual(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled',
      emoji: map['emoji'] as String? ?? '🎯',
      description: map['description'] as String?,
      type: _enumFromName(RitualType.values, map['type'], RitualType.check),
      target: (map['target'] as num?)?.toDouble() ?? 1,
      unit: map['unit'] as String? ?? '',
      scheduleType: _enumFromName(
        ScheduleType.values,
        map['scheduleType'],
        ScheduleType.weekdays,
      ),
      scheduleDays: rawDays is List
          ? rawDays.map((d) => (d as num).toInt()).toList()
          : const [1, 2, 3, 4, 5, 6, 7],
      timesPerWeek: (map['timesPerWeek'] as num?)?.toInt() ?? 3,
      intervalDays: (map['intervalDays'] as num?)?.toInt() ?? 2,
      reminderTime: map['reminderTime'] as String?,
      reminderOffsetMinutes:
          (map['reminderOffsetMinutes'] as num?)?.toInt() ?? 0,
      requirePhoto: map['requirePhoto'] as bool? ?? true,
      archived: map['archived'] as bool? ?? false,
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF1DB954,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'emoji': emoji,
      'description': description,
      'type': type.name,
      'target': target,
      'unit': unit,
      'scheduleType': scheduleType.name,
      'scheduleDays': scheduleDays,
      'timesPerWeek': timesPerWeek,
      'intervalDays': intervalDays,
      'reminderTime': reminderTime,
      'reminderOffsetMinutes': reminderOffsetMinutes,
      'requirePhoto': requirePhoto,
      'archived': archived,
      'colorValue': colorValue,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Formats a target or logged amount without a trailing `.0`.
String trimNumber(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}
