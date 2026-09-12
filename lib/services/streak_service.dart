import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rituals/models/ritual.dart';
import 'package:rituals/models/ritual_entry.dart';

/// How a single day turned out for a ritual.
enum DayStatus {
  /// Target met.
  done,

  /// Some progress, but short of the target.
  partial,

  /// Deliberately skipped. Neutral: holds the streak without extending it.
  skipped,

  /// Due and nothing logged.
  missed,

  /// Not expected on this day.
  notDue,

  /// Before the ritual existed, or in the future.
  outOfRange,
}

class DayResult {
  final DateTime day;
  final DayStatus status;

  /// Progress toward the target, clamped to 0..1.
  final double progress;

  /// Raw logged amount before clamping.
  final double value;

  const DayResult({
    required this.day,
    required this.status,
    required this.progress,
    required this.value,
  });

  bool get counts => status == DayStatus.done;
}

/// Everything the stats screens need, computed in one pass over the entries.
class StreakInfo {
  final int currentStreak;
  final int longestStreakOverall;
  final int longestStreakThisMonth;

  /// Loop-style habit strength, 0..1. See [StreakService.habitScore].
  final double score;

  /// Fraction of due days that were completed, 0..1.
  final double completionRate;

  /// Days completed, ever.
  final int totalCompletions;

  /// Completion rate per weekday (1 = Monday ... 7 = Sunday), 0..1.
  final Map<int, double> weekdayRates;

  /// Score after each of the last 90 days, oldest first, for the trend chart.
  final List<double> scoreHistory;

  /// Per-day outcome, keyed by `yyyy-MM-dd`, for the calendar and heatmap.
  final Map<String, DayResult> days;

  const StreakInfo({
    required this.currentStreak,
    required this.longestStreakOverall,
    required this.longestStreakThisMonth,
    required this.score,
    required this.completionRate,
    required this.totalCompletions,
    required this.weekdayRates,
    required this.scoreHistory,
    required this.days,
  });

  static const empty = StreakInfo(
    currentStreak: 0,
    longestStreakOverall: 0,
    longestStreakThisMonth: 0,
    score: 0,
    completionRate: 0,
    totalCompletions: 0,
    weekdayRates: {},
    scoreHistory: [],
    days: {},
  );

  DayResult resultFor(DateTime day) =>
      days[RitualEntry.dayKey(day)] ??
      DayResult(
        day: day,
        status: DayStatus.outOfRange,
        progress: 0,
        value: 0,
      );

  bool hasCompleted(DateTime day) => resultFor(day).counts;

  /// The weekday the ritual is kept most often, or null without enough data.
  int? get strongestWeekday => _extremeWeekday(highest: true);

  /// The weekday the ritual slips most often, or null without enough data.
  int? get weakestWeekday => _extremeWeekday(highest: false);

  int? _extremeWeekday({required bool highest}) {
    if (weekdayRates.length < 2) return null;
    int? best;
    double? bestRate;
    for (final entry in weekdayRates.entries) {
      if (bestRate == null ||
          (highest ? entry.value > bestRate : entry.value < bestRate)) {
        bestRate = entry.value;
        best = entry.key;
      }
    }
    return best;
  }
}

class StreakService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Days of score history kept for the trend chart.
  static const int historyDays = 90;

  /// Loop Habit Tracker's decay constant. Chosen so a perfectly kept daily
  /// ritual scores about 80% after a month and 96% after two.
  static const double _scoreHalfLife = 13.0;

  Future<StreakInfo> loadStreak({
    required String groupId,
    required Ritual ritual,
    String? userId,
  }) async {
    final snapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('rituals')
        .doc(ritual.id)
        .collection('entries')
        .orderBy('createdAt')
        .get();

    var entries =
        snapshot.docs.map((doc) => RitualEntry.fromMap(doc.data())).toList();
    if (userId != null) {
      entries = entries.where((e) => e.userId == userId).toList();
    }

    return analyse(ritual: ritual, entries: entries);
  }

  /// Collapses entries to one result per day and derives every statistic.
  ///
  /// Pure, so it can be unit tested without Firestore.
  StreakInfo analyse({
    required Ritual ritual,
    required List<RitualEntry> entries,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    // Several entries can land on the same day (a quantity ritual logged in
    // sips, or a photo added after a check). Sum their values; a day is
    // skipped only if nothing was actually logged.
    final totals = <String, double>{};
    final skips = <String>{};
    for (final entry in entries) {
      if (entry.skipped) {
        skips.add(entry.day);
        continue;
      }
      totals[entry.day] = (totals[entry.day] ?? 0) + entry.value;
    }
    skips.removeWhere((day) => (totals[day] ?? 0) > 0);

    final target = ritual.target <= 0 ? 1.0 : ritual.target;
    final firstDay = _firstDay(ritual, totals.keys, skips);

    final days = <String, DayResult>{};
    final scoreHistory = <double>[];
    final weekdayDue = <int, int>{};
    final weekdayDone = <int, int>{};

    var score = 0.0;
    var dueDays = 0;
    var doneDays = 0;
    var totalCompletions = 0;
    var longestOverall = 0;
    var rolling = 0;
    var longestThisMonth = 0;
    var rollingThisMonth = 0;

    final monthStart = DateTime(now.year, now.month, 1);
    final multiplier = pow(0.5, ritual.frequencyInDays / _scoreHalfLife)
        .toDouble();
    final historyStart =
        todayMidnight.subtract(const Duration(days: historyDays - 1));

    for (var day = firstDay;
        !day.isAfter(todayMidnight);
        day = day.add(const Duration(days: 1))) {
      final key = RitualEntry.dayKey(day);
      final value = totals[key] ?? 0;
      final progress = (value / target).clamp(0.0, 1.0);
      final due = ritual.isDueOn(day);

      final DayStatus status;
      if (skips.contains(key)) {
        status = DayStatus.skipped;
      } else if (progress >= 1) {
        status = DayStatus.done;
      } else if (value > 0) {
        status = DayStatus.partial;
      } else if (due) {
        status = DayStatus.missed;
      } else {
        status = DayStatus.notDue;
      }

      days[key] = DayResult(
        day: day,
        status: status,
        progress: progress,
        value: value,
      );

      if (status == DayStatus.done) totalCompletions++;

      // Skipped days sit out of every rate and of the score decay.
      if (status != DayStatus.skipped) {
        if (due) {
          dueDays++;
          weekdayDue[day.weekday] = (weekdayDue[day.weekday] ?? 0) + 1;
          if (status == DayStatus.done) {
            doneDays++;
            weekdayDone[day.weekday] = (weekdayDone[day.weekday] ?? 0) + 1;
          }
        }

        // Today is still open, so an unfinished target must not drag the
        // score down yet.
        final isOpenToday = day == todayMidnight && progress < 1;
        if (!isOpenToday) {
          score = score * multiplier + progress * (1 - multiplier);
        }
      }

      // A streak counts consecutive completions of days that were due,
      // stepping over rest days and skips without breaking.
      if (status == DayStatus.done) {
        rolling++;
        longestOverall = max(longestOverall, rolling);
        if (!day.isBefore(monthStart)) {
          rollingThisMonth++;
          longestThisMonth = max(longestThisMonth, rollingThisMonth);
        }
      } else if (status == DayStatus.missed) {
        rolling = 0;
        rollingThisMonth = 0;
      } else if (day == todayMidnight) {
        // Today not done yet is not a miss.
      } else if (due && status == DayStatus.partial) {
        rolling = 0;
        rollingThisMonth = 0;
      }

      if (!day.isBefore(historyStart)) scoreHistory.add(score);
    }

    final weekdayRates = <int, double>{};
    for (final entry in weekdayDue.entries) {
      if (entry.value == 0) continue;
      weekdayRates[entry.key] = (weekdayDone[entry.key] ?? 0) / entry.value;
    }

    return StreakInfo(
      currentStreak: _currentStreak(days, ritual, todayMidnight),
      longestStreakOverall: longestOverall,
      longestStreakThisMonth: longestThisMonth,
      score: score.clamp(0.0, 1.0),
      completionRate: dueDays == 0 ? 0 : doneDays / dueDays,
      totalCompletions: totalCompletions,
      weekdayRates: weekdayRates,
      scoreHistory: scoreHistory,
      days: days,
    );
  }

  /// Walks backwards from today over days the ritual was due, stopping at the
  /// first miss. Rest days and skips are stepped over.
  int _currentStreak(
    Map<String, DayResult> days,
    Ritual ritual,
    DateTime todayMidnight,
  ) {
    var streak = 0;
    for (var day = todayMidnight;
        day.isAfter(todayMidnight.subtract(const Duration(days: 730)));
        day = day.subtract(const Duration(days: 1))) {
      final result = days[RitualEntry.dayKey(day)];
      if (result == null) break;

      switch (result.status) {
        case DayStatus.done:
          streak++;
        case DayStatus.skipped:
        case DayStatus.notDue:
          break;
        case DayStatus.partial:
        case DayStatus.missed:
          // Today still has time left on the clock.
          if (day == todayMidnight) break;
          return streak;
        case DayStatus.outOfRange:
          return streak;
      }
    }
    return streak;
  }

  DateTime _firstDay(
    Ritual ritual,
    Iterable<String> loggedDays,
    Set<String> skippedDays,
  ) {
    var first = ritual.startDay;
    for (final key in [...loggedDays, ...skippedDays]) {
      final day = RitualEntry.parseDay(key);
      if (day.isBefore(first)) first = day;
    }
    return first;
  }

  /// Loop Habit Tracker's exponential moving average, exposed for tests.
  ///
  ///   multiplier = 0.5 ^ (frequencyInDays / 13)
  ///   score      = previous * multiplier + value * (1 - multiplier)
  static double habitScore({
    required double previous,
    required double value,
    required double frequencyInDays,
  }) {
    final multiplier =
        pow(0.5, frequencyInDays / _scoreHalfLife).toDouble();
    return previous * multiplier + value * (1 - multiplier);
  }
}
