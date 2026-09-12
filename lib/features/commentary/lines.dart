import 'package:rituals/features/commentary/commentary.dart';
import 'package:rituals/features/commentary/tone.dart';

/// Hand-written lines, grouped by tone and moment.
///
/// Placeholders: {streak} {done} {due} {left} {score} {days} {ritual}.
const Map<CommentaryTone, Map<Moment, List<String>>> commentaryLines = {
  CommentaryTone.kind: {
    Moment.dayEmpty: [
      'Nothing logged yet. There is still plenty of day left.',
      '{due} waiting. Start with the easiest one.',
      'A clean slate. Pick one and begin.',
      'You do not have to feel like it. You just have to start.',
    ],
    Moment.dayPartial: [
      '{done} of {due} done. Keep going.',
      'Good start. {left} to go.',
      'You are already moving. That was the hard part.',
      'Halfway counts. Finish when you can.',
    ],
    Moment.dayPerfect: [
      'Everything done. Enjoy the rest of the day.',
      'All {due} of them. That is a complete day.',
      'Nothing left to do. Well played.',
      'Perfect day. Those add up faster than you think.',
    ],
    Moment.nothingScheduled: [
      'Nothing scheduled today. Rest is part of it.',
      'A day off. Take it properly.',
      'No rituals due. Enjoy the gap.',
    ],
    Moment.completed: [
      'Logged. That is one more than yesterday.',
      'Done. Small things, repeated.',
      'Nice. {ritual} is in the books.',
      'That counts. It always counts.',
    ],
    Moment.streakMilestone: [
      '{streak} days. That is a real habit now.',
      '{streak} in a row. Look at that.',
      '{streak} days of showing up. Genuinely impressive.',
    ],
    Moment.skipped: [
      'Skipped. Your streak is safe.',
      'Rest day taken. No damage done.',
      'Skipping on purpose is not the same as missing.',
    ],
    Moment.undone: [
      'Undone. No harm.',
      'Taken back off the list.',
    ],
    Moment.firstRitual: [
      'One ritual is the right number to start with.',
      'Good. Now do it tomorrow.',
    ],
    Moment.streakBroken: [
      'The streak ended. Start a new one today.',
      'One missed day is one missed day. Not a verdict.',
      'Back to zero on the counter, not on the habit.',
    ],
    Moment.longLapse: [
      'It has been {days} days. Today is a fine day to return.',
      '{days} days away. Nobody is keeping score but you.',
      'Coming back after {days} days is harder than starting. Do it anyway.',
    ],
    Moment.strongScore: [
      '{score}% consistency. That is steady work.',
      'Holding at {score}%. Quietly excellent.',
    ],
    Moment.weakScore: [
      '{score}% so far. Every log moves it up.',
      'Low numbers now. They respond quickly.',
    ],
    Moment.reminder: [
      'Time for {ritual}.',
      '{ritual} is waiting whenever you are.',
      'A small window for {ritual}.',
    ],
  },
  CommentaryTone.dry: {
    Moment.dayEmpty: [
      '{due} scheduled. Zero done. The day is watching.',
      'Nothing logged. Bold strategy.',
      'Still at zero. The rituals are not going to do themselves.',
      'You opened the app. Technically that is not the habit.',
    ],
    Moment.dayPartial: [
      '{done} of {due}. Suspiciously close to enough.',
      '{left} left. You know which one you are avoiding.',
      'Partial credit. Universities give it, streaks do not.',
      'Good progress, assuming you finish.',
    ],
    Moment.dayPerfect: [
      'All {due} done. Now you have nothing to feel guilty about. Unsettling.',
      'Perfect day. Do not let it go to your head.',
      'Everything logged. The app has no notes.',
      'Finished. You may now scroll guilt free.',
    ],
    Moment.nothingScheduled: [
      'Nothing due. Suspicious, but enjoy it.',
      'No rituals today. Try not to get used to it.',
      'A scheduled day off. You planned this.',
    ],
    Moment.completed: [
      'Logged. The bar was on the floor and you cleared it.',
      'Done. Your future self pretends this was easy.',
      '{ritual} complete. Barely a story, but it counts.',
      'One more tally. Thrilling stuff.',
    ],
    Moment.streakMilestone: [
      '{streak} days. At this point it would be embarrassing to stop.',
      '{streak} in a row. The sunk cost is working in your favour.',
      '{streak} days. You have accidentally become consistent.',
    ],
    Moment.skipped: [
      'Skipped. Deliberately. We are calling it strategy.',
      'Rest day. The streak survives on a technicality.',
      'Skipped. Your streak thanks you for the paperwork.',
    ],
    Moment.undone: [
      'Unlogged. We will pretend that never happened.',
      'Taken back. The records have been adjusted.',
    ],
    Moment.firstRitual: [
      'One ritual. Ambitious restraint.',
      'A single habit. Let us see how long this lasts.',
    ],
    Moment.streakBroken: [
      'Streak gone. It was nice while it lasted.',
      'Back to zero. The counter has no memory and no mercy.',
      'That streak is now a fond anecdote.',
    ],
    Moment.longLapse: [
      '{days} days. The app kept your seat warm.',
      'Gone {days} days. We assumed the worst. Welcome back.',
      '{days} days off. Impressive commitment to not committing.',
    ],
    Moment.strongScore: [
      '{score}% consistency. Annoyingly reliable.',
      'Sitting at {score}%. Almost like you meant to.',
    ],
    Moment.weakScore: [
      '{score}%. There is room. So much room.',
      '{score}% consistency. The graph is being polite about it.',
    ],
    Moment.reminder: [
      '{ritual}. Now would be the time.',
      '{ritual} is due. No pressure, obviously.',
      'Reminder: {ritual}. You did ask for this.',
    ],
  },
  CommentaryTone.brutal: {
    Moment.dayEmpty: [
      'Zero of {due}. Absolutely nothing. A masterclass.',
      'Nothing done. The rituals are just decorative now.',
      'You set {due} of these yourself. Past you had such hope.',
      'Still zero. Opening the app is not cardio.',
      'Nothing logged. Damn. Even the app is embarrassed for you.',
      'Zero. You made this list sober and everything.',
    ],
    Moment.dayPartial: [
      '{done} of {due}. Half a person. Keep going.',
      '{left} left, and we both know which one.',
      'Partial. The word does a lot of heavy lifting today.',
      'You did the easy ones first, did you not. Shameless.',
      '{done} down. Do not stop now, you are nearly a functional adult.',
    ],
    Moment.dayPerfect: [
      'All {due}. Who the hell are you and what have you done with yesterday.',
      'Perfect day. Do not get smug, tomorrow exists.',
      'Everything done. I had money on you failing. I lost it.',
      'Flawless. Disgusting. Do it again tomorrow.',
      'All of them. Honestly, damn.',
    ],
    Moment.nothingScheduled: [
      'Nothing due. You cannot fail at nothing. Enjoy the loophole.',
      'No rituals today. Even you cannot ruin this.',
      'Empty schedule. A rare day where doing nothing is correct.',
    ],
    Moment.completed: [
      'Logged. Barely counts, but so does everything else.',
      'Done. Try to look less surprised.',
      '{ritual}. One tap. It nearly killed you.',
      'Finished. The bar was underground and you cleared it.',
      'Done. Damn right.',
    ],
    Moment.streakMilestone: [
      '{streak} days. Stopping now would be genuinely pathetic.',
      '{streak} in a row. You have too much to lose. Good.',
      '{streak} days. At this point the habit has you.',
      '{streak}. Hell of a run. Do not blow it.',
    ],
    Moment.skipped: [
      'Skipped. Called it a rest day. We all heard you.',
      'Skipped on purpose. The streak lives, your dignity is negotiable.',
      'Rest day. Sure. Let us go with that.',
    ],
    Moment.undone: [
      'Unlogged. Cheating yourself is a bold hobby.',
      'Taken back. Nobody saw. Except me.',
    ],
    Moment.firstRitual: [
      'One ritual. Start small, in case you disappoint yourself.',
      'A single habit. The bar is on the floor. Do not trip.',
    ],
    Moment.streakBroken: [
      'Streak dead. You had one job, repeatedly.',
      'Back to zero. Hurts, does it not. Use that.',
      'Gone. Build another one. They are cheap and you have time.',
      'Damn. All that, undone by one ordinary Tuesday.',
    ],
    Moment.longLapse: [
      '{days} days. The dust on this thing is structural.',
      'Gone {days} days. I was going to send flowers.',
      '{days} days off. Welcome back, coward. Sit down and log it.',
      '{days} days. Hell of a break. Ready to be unbearable about it again?',
    ],
    Moment.strongScore: [
      '{score}% consistency. Irritatingly good. Keep it up.',
      '{score}%. Fine. You have earned the smugness.',
    ],
    Moment.weakScore: [
      '{score}%. That is not a habit, that is a rumour.',
      '{score}% consistency. The chart is a crime scene.',
      '{score}%. Damn. The only way from here is up.',
    ],
    Moment.reminder: [
      '{ritual}. Now. Before you talk yourself out of it.',
      '{ritual} is due and your excuses are getting worse.',
      'Get up. {ritual}. It takes less time than the guilt.',
    ],
  },
};
