import 'dart:math';

import 'package:rituals/features/commentary/lines.dart';
import 'package:rituals/features/commentary/tone.dart';

/// The situations the app has something to say about.
enum Moment {
  dayEmpty,
  dayPartial,
  dayPerfect,
  nothingScheduled,
  completed,
  streakMilestone,
  skipped,
  undone,
  firstRitual,
  streakBroken,
  longLapse,
  strongScore,
  weakScore,
  reminder,
}

/// What the app knows when it speaks.
class CommentaryContext {
  final int streak;
  final int doneToday;
  final int dueToday;
  final double score;

  /// Days since the ritual was last kept, or null when it never has been.
  final int? daysSinceLastDone;

  final String? ritualTitle;
  final int hour;

  const CommentaryContext({
    this.streak = 0,
    this.doneToday = 0,
    this.dueToday = 0,
    this.score = 0,
    this.daysSinceLastDone,
    this.ritualTitle,
    this.hour = 12,
  });
}

/// Picks a line for a moment, in the chosen tone.
///
/// Everything is a hand-written line chosen on device: no network call, no
/// model, nothing to pay for, and nothing that can say something the author
/// did not write.
class Commentary {
  Commentary({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Recently used lines, so the same joke does not land twice in a row.
  final _recent = <String>[];
  static const _recentMemory = 12;

  String? lineFor(
    Moment moment, {
    required CommentaryTone tone,
    required bool allowProfanity,
    CommentaryContext context = const CommentaryContext(),
  }) {
    if (tone == CommentaryTone.off) return null;

    var pool = commentaryLines[tone]?[moment] ?? const <String>[];
    if (!allowProfanity) {
      pool = pool.where((line) => !_profane.hasMatch(line)).toList();
    }
    if (pool.isEmpty && tone != CommentaryTone.kind) {
      // Fall back to a gentler line rather than saying nothing.
      pool = commentaryLines[CommentaryTone.kind]?[moment] ?? const [];
    }
    if (pool.isEmpty) return null;

    final fresh = pool.where((line) => !_recent.contains(line)).toList();
    final choices = fresh.isEmpty ? pool : fresh;
    final line = choices[_random.nextInt(choices.length)];

    _recent.add(line);
    if (_recent.length > _recentMemory) _recent.removeAt(0);

    return _fill(line, context);
  }

  String _fill(String line, CommentaryContext c) {
    return line
        .replaceAll('{streak}', '${c.streak}')
        .replaceAll('{done}', '${c.doneToday}')
        .replaceAll('{due}', '${c.dueToday}')
        .replaceAll('{left}', '${(c.dueToday - c.doneToday).clamp(0, 999)}')
        .replaceAll('{score}', '${(c.score * 100).round()}')
        .replaceAll('{days}', '${c.daysSinceLastDone ?? 0}')
        .replaceAll('{ritual}', c.ritualTitle ?? 'it');
  }

  /// Words that only appear when the user has asked for them.
  static final _profane = RegExp(
    r'\b(fuck\w*|shit\w*|arse\w*|ass|damn|hell|bastard|crap|bollocks|piss\w*)\b',
    caseSensitive: false,
  );

  /// Chooses the moment that best describes the day.
  static Moment momentForDay(CommentaryContext c) {
    if (c.dueToday == 0) return Moment.nothingScheduled;
    if (c.doneToday >= c.dueToday) return Moment.dayPerfect;
    if (c.doneToday > 0) return Moment.dayPartial;
    return Moment.dayEmpty;
  }

  /// Streak lengths worth calling out.
  static const milestones = {3, 7, 14, 21, 30, 50, 66, 75, 100, 150, 200, 365};

  static bool isMilestone(int streak) => milestones.contains(streak);
}
