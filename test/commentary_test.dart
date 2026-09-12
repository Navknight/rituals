import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rituals/features/commentary/commentary.dart';
import 'package:rituals/features/commentary/lines.dart';
import 'package:rituals/features/commentary/tone.dart';

void main() {
  final profane = RegExp(
    r'\b(fuck\w*|shit\w*|arse\w*|ass|damn|hell|bastard|crap|bollocks|piss\w*)\b',
    caseSensitive: false,
  );

  group('tone', () {
    test('off says nothing', () {
      final line = Commentary().lineFor(
        Moment.dayEmpty,
        tone: CommentaryTone.off,
        allowProfanity: true,
      );
      expect(line, isNull);
    });

    test('every tone and moment has a line', () {
      for (final tone in CommentaryTone.values) {
        if (tone == CommentaryTone.off) continue;
        for (final moment in Moment.values) {
          final line = Commentary().lineFor(
            moment,
            tone: tone,
            allowProfanity: true,
          );
          expect(line, isNotNull, reason: '$tone / $moment has no line');
          expect(line, isNotEmpty);
        }
      }
    });

    test('kind and dry tones never swear, whatever the flag', () {
      for (final tone in [CommentaryTone.kind, CommentaryTone.dry]) {
        for (final lines in commentaryLines[tone]!.values) {
          for (final line in lines) {
            expect(profane.hasMatch(line), isFalse,
                reason: '$tone line swears: $line');
          }
        }
      }
    });
  });

  group('profanity', () {
    test('is withheld until it is asked for', () {
      final commentary = Commentary(random: Random(7));
      for (var i = 0; i < 300; i++) {
        final line = commentary.lineFor(
          Moment.values[i % Moment.values.length],
          tone: CommentaryTone.brutal,
          allowProfanity: false,
        );
        expect(line, isNotNull);
        expect(profane.hasMatch(line!), isFalse, reason: 'leaked: $line');
      }
    });

    test('brutal still has something to say with profanity off', () {
      for (final moment in Moment.values) {
        final line = Commentary().lineFor(
          moment,
          tone: CommentaryTone.brutal,
          allowProfanity: false,
        );
        expect(line, isNotNull, reason: '$moment goes silent');
      }
    });
  });

  group('placeholders', () {
    test('are always filled in', () {
      final commentary = Commentary(random: Random(3));
      const context = CommentaryContext(
        streak: 12,
        doneToday: 2,
        dueToday: 5,
        score: 0.62,
        daysSinceLastDone: 9,
        ritualTitle: 'Reading',
      );
      for (var i = 0; i < 400; i++) {
        for (final tone in CommentaryTone.values) {
          if (tone == CommentaryTone.off) continue;
          final line = commentary.lineFor(
            Moment.values[i % Moment.values.length],
            tone: tone,
            allowProfanity: true,
            context: context,
          );
          expect(line, isNotNull);
          expect(line, isNot(contains('{')), reason: 'unfilled: $line');
        }
      }
    });

    test('substitutes the real values', () {
      final line = Commentary().lineFor(
        Moment.streakMilestone,
        tone: CommentaryTone.kind,
        allowProfanity: false,
        context: const CommentaryContext(streak: 30),
      );
      expect(line, contains('30'));
    });
  });

  group('repetition', () {
    test('does not repeat while fresh lines remain', () {
      final commentary = Commentary(random: Random(11));
      final seen = <String>{};
      final pool = commentaryLines[CommentaryTone.dry]![Moment.completed]!;
      for (var i = 0; i < pool.length; i++) {
        final line = commentary.lineFor(
          Moment.completed,
          tone: CommentaryTone.dry,
          allowProfanity: false,
        );
        expect(seen.add(line!), isTrue, reason: 'repeated early: $line');
      }
    });
  });

  group('moment choice', () {
    test('reads the day correctly', () {
      expect(
        Commentary.momentForDay(const CommentaryContext(dueToday: 0)),
        Moment.nothingScheduled,
      );
      expect(
        Commentary.momentForDay(
          const CommentaryContext(dueToday: 3, doneToday: 0),
        ),
        Moment.dayEmpty,
      );
      expect(
        Commentary.momentForDay(
          const CommentaryContext(dueToday: 3, doneToday: 1),
        ),
        Moment.dayPartial,
      );
      expect(
        Commentary.momentForDay(
          const CommentaryContext(dueToday: 3, doneToday: 3),
        ),
        Moment.dayPerfect,
      );
    });

    test('milestones are the ones worth celebrating', () {
      expect(Commentary.isMilestone(7), isTrue);
      expect(Commentary.isMilestone(30), isTrue);
      expect(Commentary.isMilestone(8), isFalse);
    });
  });
}
