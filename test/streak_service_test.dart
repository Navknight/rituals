import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rituals/models/ritual.dart';
import 'package:rituals/models/ritual_entry.dart';
import 'package:rituals/services/streak_service.dart';

final _today = DateTime(2026, 6, 15);

Ritual _ritual({
  RitualType type = RitualType.check,
  double target = 1,
  ScheduleType scheduleType = ScheduleType.weekdays,
  List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  int timesPerWeek = 3,
  int intervalDays = 2,
  DateTime? createdAt,
}) {
  return Ritual(
    id: 'r1',
    title: 'Test',
    emoji: '🎯',
    type: type,
    target: target,
    scheduleType: scheduleType,
    scheduleDays: days,
    timesPerWeek: timesPerWeek,
    intervalDays: intervalDays,
    createdBy: 'u1',
    createdAt: createdAt ?? _today.subtract(const Duration(days: 60)),
  );
}

RitualEntry _entry(DateTime day, {double value = 1, bool skipped = false}) {
  return RitualEntry(
    id: RitualEntry.dayKey(day),
    userId: 'u1',
    day: RitualEntry.dayKey(day),
    value: value,
    skipped: skipped,
    createdAt: day,
  );
}

List<RitualEntry> _lastDays(int count, {double value = 1, int from = 0}) {
  return List.generate(
    count,
    (i) => _entry(_today.subtract(Duration(days: from + i)), value: value),
  );
}

void main() {
  final service = StreakService();

  StreakInfo run(Ritual ritual, List<RitualEntry> entries) =>
      service.analyse(ritual: ritual, entries: entries, today: _today);

  group('streaks', () {
    test('counts consecutive completed days', () {
      final info = run(_ritual(), _lastDays(5));
      expect(info.currentStreak, 5);
      expect(info.longestStreakOverall, 5);
      expect(info.totalCompletions, 5);
    });

    test('an unfinished today does not break the streak', () {
      final info = run(_ritual(), _lastDays(4, from: 1));
      expect(info.currentStreak, 4);
    });

    test('a missed day ends the streak', () {
      final entries = [
        ..._lastDays(2),
        ..._lastDays(3, from: 3),
      ];
      final info = run(_ritual(), entries);
      expect(info.currentStreak, 2);
      expect(info.longestStreakOverall, 3);
    });

    test('a skipped day holds the streak without extending it', () {
      final entries = [
        ..._lastDays(2),
        _entry(_today.subtract(const Duration(days: 2)), skipped: true),
        ..._lastDays(3, from: 3),
      ];
      final info = run(_ritual(), entries);
      expect(info.currentStreak, 5);
    });

    test('rest days on a weekday schedule do not break the streak', () {
      // Mondays only. 2026-06-15 is a Monday.
      final ritual = _ritual(days: const [1]);
      final entries = [
        _entry(_today),
        _entry(_today.subtract(const Duration(days: 7))),
        _entry(_today.subtract(const Duration(days: 14))),
      ];
      final info = run(ritual, entries);
      expect(info.currentStreak, 3);
    });

    test('an every-N-days ritual is only due on its interval', () {
      final ritual = _ritual(
        scheduleType: ScheduleType.everyNDays,
        intervalDays: 3,
        createdAt: _today.subtract(const Duration(days: 9)),
      );
      expect(ritual.isDueOn(_today), isTrue);
      expect(ritual.isDueOn(_today.subtract(const Duration(days: 1))), isFalse);
      expect(ritual.isDueOn(_today.subtract(const Duration(days: 3))), isTrue);
    });
  });

  group('quantity rituals', () {
    test('partial progress does not count as done', () {
      final ritual = _ritual(type: RitualType.quantity, target: 8);
      final info = run(ritual, [_entry(_today, value: 5)]);
      expect(info.resultFor(_today).status, DayStatus.partial);
      expect(info.currentStreak, 0);
      expect(info.resultFor(_today).progress, closeTo(0.625, 0.001));
    });

    test('reaching the target counts as done', () {
      final ritual = _ritual(type: RitualType.quantity, target: 8);
      final info = run(ritual, [_entry(_today, value: 8)]);
      expect(info.resultFor(_today).status, DayStatus.done);
      expect(info.currentStreak, 1);
    });

    test('several logs on one day add up', () {
      final ritual = _ritual(type: RitualType.quantity, target: 3);
      final day = RitualEntry.dayKey(_today);
      final entries = [
        RitualEntry(
            id: 'a', userId: 'u1', day: day, value: 1, createdAt: _today),
        RitualEntry(
            id: 'b', userId: 'u1', day: day, value: 2, createdAt: _today),
      ];
      expect(run(ritual, entries).resultFor(_today).status, DayStatus.done);
    });
  });

  group('habit score', () {
    test('is zero with no history', () {
      expect(run(_ritual(), const []).score, 0);
    });

    test('a perfect daily month lands near 80 percent', () {
      final info = run(_ritual(), _lastDays(30));
      expect(info.score, greaterThan(0.75));
      expect(info.score, lessThan(0.85));
    });

    test('rises with consistency and never exceeds one', () {
      final short = run(_ritual(), _lastDays(7)).score;
      final long = run(_ritual(), _lastDays(60)).score;
      expect(long, greaterThan(short));
      expect(long, lessThanOrEqualTo(1.0));
    });

    test('decays after a lapse', () {
      final kept = run(_ritual(), _lastDays(30)).score;
      final lapsed = run(_ritual(), _lastDays(30, from: 14)).score;
      expect(lapsed, lessThan(kept));
    });

    test('matches the documented moving average', () {
      final next = StreakService.habitScore(
        previous: 0.5,
        value: 1,
        frequencyInDays: 1,
      );
      // multiplier = 0.5 ^ (1 / 13)
      expect(next, closeTo(0.5 * 0.94822 + 1 * 0.05178, 0.0005));
    });

    test('a less frequent ritual is not punished for its rest days', () {
      final daily = _ritual();
      final thrice = _ritual(
        scheduleType: ScheduleType.timesPerWeek,
        timesPerWeek: 3,
      );
      expect(thrice.frequencyInDays, closeTo(7 / 3, 0.001));
      expect(daily.frequencyInDays, 1);
    });
  });

  group('rates', () {
    test('completion rate counts only due days', () {
      // Weekdays only, kept every weekday for two weeks.
      final ritual = _ritual(
        days: const [1, 2, 3, 4, 5],
        createdAt: _today.subtract(const Duration(days: 13)),
      );
      final entries = <RitualEntry>[];
      for (var i = 0; i < 14; i++) {
        final day = _today.subtract(Duration(days: i));
        if (day.weekday <= 5) entries.add(_entry(day));
      }
      expect(run(ritual, entries).completionRate, 1.0);
    });

    test('skipped days are left out of the rate', () {
      final ritual =
          _ritual(createdAt: _today.subtract(const Duration(days: 4)));
      final entries = [
        ..._lastDays(4),
        _entry(_today.subtract(const Duration(days: 4)), skipped: true),
      ];
      expect(run(ritual, entries).completionRate, 1.0);
    });

    test('weekday rates report each day separately', () {
      final ritual =
          _ritual(createdAt: _today.subtract(const Duration(days: 20)));
      final info = run(ritual, _lastDays(21));
      expect(info.weekdayRates.length, 7);
      for (final rate in info.weekdayRates.values) {
        expect(rate, 1.0);
      }
    });
  });

  group('day keys', () {
    test('round trip', () {
      final key = RitualEntry.dayKey(DateTime(2026, 1, 9));
      expect(key, '2026-01-09');
      expect(RitualEntry.parseDay(key), DateTime(2026, 1, 9));
    });
  });

  group('models', () {
    test('a ritual survives a Firestore round trip', () {
      final ritual = _ritual(type: RitualType.timer, target: 20);
      final restored = Ritual.fromMap({
        ...ritual.toMap(),
        'createdAt': Timestamp.fromDate(ritual.createdAt),
      });
      expect(restored.type, RitualType.timer);
      expect(restored.target, 20);
      expect(restored.scheduleDays, ritual.scheduleDays);
    });

    test('an old ritual without the new fields still parses', () {
      final restored = Ritual.fromMap({
        'id': 'old',
        'title': 'Legacy',
        'emoji': '🌱',
        'scheduleDays': [1, 3, 5],
        'createdBy': 'u1',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      expect(restored.type, RitualType.check);
      expect(restored.scheduleType, ScheduleType.weekdays);
      expect(restored.requirePhoto, isFalse);
      expect(restored.target, 1);
    });

    test('an old entry without a day key falls back to its timestamp', () {
      final restored = RitualEntry.fromMap({
        'id': 'e1',
        'userId': 'u1',
        'photoUrl': 'https://example.test/a.jpg',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 4, 22, 30)),
      });
      expect(restored.day, '2026-03-04');
      expect(restored.value, 1);
      expect(restored.hasPhoto, isTrue);
    });
  });
}
