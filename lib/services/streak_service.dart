import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class StreakInfo {
  final int currentStreak;
  final int longestStreakOverall;
  final int longestStreakThisMonth;
  final Set<int> completedDayKeys; // millisecondsSinceEpoch of midnight

  const StreakInfo({
    required this.currentStreak,
    required this.longestStreakOverall,
    required this.longestStreakThisMonth,
    required this.completedDayKeys,
  });

  bool hasCompleted(DateTime day) {
    final key = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    return completedDayKeys.contains(key);
  }
}

class StreakService {
  final _firestore = FirebaseFirestore.instance;

  /// Calculate streak info for a ritual based on its entries
  Future<StreakInfo> calculateStreak({
    required String groupId,
    required String ritualId,
    required List<int> scheduledDays,
  }) async {
    // Fetch all entries for this ritual
    final snapshot = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('rituals')
        .doc(ritualId)
        .collection('entries')
        .orderBy('createdAt')
        .get();

    // Build set of completed day keys (midnight timestamps)
    final completedDayKeys = <int>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp).toDate();
      final midnight = DateTime(createdAt.year, createdAt.month, createdAt.day);
      completedDayKeys.add(midnight.millisecondsSinceEpoch);
    }

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    final currentStreak = _currentStreak(
      completedDayKeys,
      scheduledDays,
      todayMidnight,
    );
    final longestOverall = _longestStreak(
      completedDayKeys,
      scheduledDays,
      todayMidnight,
    );

    final monthStart = DateTime(now.year, now.month, 1);
    final longestMonth = _longestStreakInRange(
      completedDayKeys,
      scheduledDays,
      startDay: monthStart,
      endDay: todayMidnight,
    );

    return StreakInfo(
      currentStreak: currentStreak,
      longestStreakOverall: longestOverall,
      longestStreakThisMonth: longestMonth,
      completedDayKeys: completedDayKeys,
    );
  }

  int _currentStreak(
    Set<int> dayKeys,
    List<int> scheduledDays,
    DateTime todayMidnight,
  ) {
    if (dayKeys.isEmpty) return 0;

    int current = 0;
    // Walk backwards from today
    for (var day = todayMidnight;
        day.isAfter(todayMidnight.subtract(const Duration(days: 365)));
        day = day.subtract(const Duration(days: 1))) {
      if (!_isScheduledDay(scheduledDays, day.weekday)) continue;

      final key = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      if (dayKeys.contains(key)) {
        current += 1;
      } else if (day == todayMidnight) {
        // Today hasn't been completed yet — don't break, user still has time
        continue;
      } else {
        break;
      }
    }
    return current;
  }

  int _longestStreak(
    Set<int> dayKeys,
    List<int> scheduledDays,
    DateTime todayMidnight,
  ) {
    if (dayKeys.isEmpty) return 0;

    final startMs = dayKeys.reduce(min);
    final startDay = DateTime.fromMillisecondsSinceEpoch(startMs);

    int longest = 0;
    int rolling = 0;
    for (var day = startDay;
        !day.isAfter(todayMidnight);
        day = day.add(const Duration(days: 1))) {
      if (!_isScheduledDay(scheduledDays, day.weekday)) continue;

      final key = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      if (dayKeys.contains(key)) {
        rolling += 1;
        longest = max(longest, rolling);
      } else {
        rolling = 0;
      }
    }
    return longest;
  }

  int _longestStreakInRange(
    Set<int> dayKeys,
    List<int> scheduledDays, {
    required DateTime startDay,
    required DateTime endDay,
  }) {
    if (dayKeys.isEmpty) return 0;

    int longest = 0;
    int rolling = 0;
    for (var day = startDay;
        !day.isAfter(endDay);
        day = day.add(const Duration(days: 1))) {
      if (!_isScheduledDay(scheduledDays, day.weekday)) continue;

      final key = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      if (dayKeys.contains(key)) {
        rolling += 1;
        longest = max(longest, rolling);
      } else {
        rolling = 0;
      }
    }
    return longest;
  }

  bool _isScheduledDay(List<int> scheduledDays, int weekday) {
    return scheduledDays.contains(weekday);
  }
}
