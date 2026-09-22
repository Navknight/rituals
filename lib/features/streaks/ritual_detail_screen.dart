import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rituals/app/theme.dart';
import 'package:rituals/core/providers.dart';
import 'package:rituals/core/settings_provider.dart';
import 'package:rituals/features/commentary/commentary.dart';
import 'package:rituals/features/camera/camera_screen.dart';
import 'package:rituals/features/rituals/ritual_controller.dart';
import 'package:rituals/features/rituals/ritual_editor.dart';
import 'package:rituals/features/stats/stat_widgets.dart';
import 'package:rituals/models/ritual.dart';
import 'package:rituals/shared/broken_photo.dart';
import 'package:rituals/models/ritual_entry.dart';
import 'package:rituals/models/user_profiles.dart';
import 'package:rituals/shared/user_avatar.dart';
import 'package:rituals/services/streak_service.dart';

class RitualDetailScreen extends ConsumerStatefulWidget {
  const RitualDetailScreen({
    super.key,
    required this.groupId,
    required this.ritual,
  });

  final String groupId;
  final Ritual ritual;

  @override
  ConsumerState<RitualDetailScreen> createState() => _RitualDetailScreenState();
}

class _RitualDetailScreenState extends ConsumerState<RitualDetailScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final ritual = widget.ritual;
    final entriesAsync = ref.watch(
      ritualEntriesProvider(RitualRef(widget.groupId, ritual.id)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${ritual.emoji} ${ritual.title}'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.pencil),
            tooltip: 'Edit',
            onPressed: () => showRitualEditor(
              context,
              ref,
              groupId: widget.groupId,
              existing: ritual,
            ),
          ),
          if (!ritual.requirePhoto)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'photo') _openCamera(context);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'photo', child: Text('Add a photo')),
              ],
            ),
        ],
      ),
      floatingActionButton: ritual.requirePhoto
          ? FloatingActionButton(
              onPressed: () => _openCamera(context),
              child: const Icon(LucideIcons.camera),
            )
          : null,
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load this ritual.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (entries) => _RitualDetailBody(
          groupId: widget.groupId,
          ritual: ritual,
          entries: entries,
          visibleMonth: _visibleMonth,
          onPrevMonth: () => setState(() {
            _visibleMonth = DateTime(
              _visibleMonth.year,
              _visibleMonth.month - 1,
            );
          }),
          onNextMonth: () {
            final now = DateTime.now();
            final next = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
            if (!next.isAfter(DateTime(now.year, now.month))) {
              setState(() => _visibleMonth = next);
            }
          },
        ),
      ),
    );
  }

  void _openCamera(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            CameraScreen(groupId: widget.groupId, ritual: widget.ritual),
      ),
    );
  }
}

class _RitualDetailBody extends ConsumerWidget {
  const _RitualDetailBody({
    required this.groupId,
    required this.ritual,
    required this.entries,
    required this.visibleMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  final String groupId;
  final Ritual ritual;
  final List<RitualEntry> entries;
  final DateTime visibleMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Color(ritual.colorValue);
    final info = ref
        .read(streakServiceProvider)
        .analyse(ritual: ritual, entries: entries);
    final todayKey = RitualEntry.dayKey(DateTime.now());
    final todayEntries = entries.where((e) => e.day == todayKey).toList();
    final today = DayProgress.from(ritual, todayEntries);
    final hasPhotos = entries.any((e) => e.hasPhoto);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StreakHero(streak: info.currentStreak, ritual: ritual),
              _Remark(ritual: ritual, info: info),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _TodayAction(
                  groupId: groupId,
                  ritual: ritual,
                  today: today,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StatRow(
                  children: [
                    StatTile(
                      label: 'Score',
                      value: '${(info.score * 100).round()}%',
                      icon: LucideIcons.gauge,
                      accent: accent,
                    ),
                    StatTile(
                      label: 'Completion',
                      value: '${(info.completionRate * 100).round()}%',
                      icon: LucideIcons.target,
                      accent: accent,
                    ),
                    StatTile(
                      label: 'Current streak',
                      value: '${info.currentStreak}',
                      icon: LucideIcons.flame,
                      accent: accent,
                    ),
                    StatTile(
                      label: 'Best streak',
                      value: '${info.longestStreakOverall}',
                      icon: LucideIcons.trophy,
                      accent: accent,
                    ),
                    StatTile(
                      label: 'Total done',
                      value: '${info.totalCompletions}',
                      icon: LucideIcons.check,
                      accent: accent,
                    ),
                    StatTile(
                      label: 'Best this month',
                      value: '${info.longestStreakThisMonth}',
                      icon: LucideIcons.calendarCheck,
                      accent: accent,
                    ),
                  ],
                ),
              ),
              _Section(
                title: 'Consistency',
                child: HeatmapCalendar(days: info.days, accent: accent),
              ),
              _Section(
                title: 'Trend',
                child: ScoreChart(history: info.scoreHistory, accent: accent),
              ),
              _Section(
                title: 'By weekday',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WeekdayBars(rates: info.weekdayRates, accent: accent),
                    if (info.strongestWeekday != null &&
                        info.weakestWeekday != null &&
                        info.strongestWeekday != info.weakestWeekday) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Strongest on ${_weekdayName(info.strongestWeekday!)}, '
                        'weakest on ${_weekdayName(info.weakestWeekday!)}.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _Section(
                title: 'Calendar',
                child: MonthCalendar(
                  month: visibleMonth,
                  days: info.days,
                  accent: accent,
                  onPrev: onPrevMonth,
                  onNext: onNextMonth,
                ),
              ),
              if (hasPhotos)
                _Section(
                  title: 'Photos',
                  child: _PhotosStrip(groupId: groupId, entries: entries),
                ),
              _MembersSection(
                groupId: groupId,
                ritual: ritual,
                entries: entries,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  static String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday - 1];
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// One line of commentary about how this ritual is actually going.
class _Remark extends ConsumerWidget {
  const _Remark({required this.ritual, required this.info});

  final Ritual ritual;
  final StreakInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    final lastDone = _daysSinceLastDone();
    final Moment moment;
    if (info.totalCompletions == 0) {
      moment = Moment.firstRitual;
    } else if (lastDone != null && lastDone >= 7) {
      moment = Moment.longLapse;
    } else if (info.currentStreak == 0 && info.longestStreakOverall >= 3) {
      moment = Moment.streakBroken;
    } else if (info.score >= 0.7) {
      moment = Moment.strongScore;
    } else if (info.score < 0.35) {
      moment = Moment.weakScore;
    } else {
      return const SizedBox.shrink();
    }

    final line = ref
        .read(commentaryProvider)
        .lineFor(
          moment,
          tone: settings.tone,
          allowProfanity: settings.allowProfanity,
          context: CommentaryContext(
            streak: info.currentStreak,
            score: info.score,
            daysSinceLastDone: lastDone,
            ritualTitle: ritual.title,
          ),
        );
    if (line == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          line,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  int? _daysSinceLastDone() {
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    for (var i = 0; i <= 120; i++) {
      final day = midnight.subtract(Duration(days: i));
      if (info.days[RitualEntry.dayKey(day)]?.status == DayStatus.done) {
        return i;
      }
    }
    return null;
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.streak, required this.ritual});

  final int streak;
  final Ritual ritual;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Color(ritual.colorValue);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(LucideIcons.flame, size: 36, color: accent),
              const SizedBox(width: 8),
              Text(
                '$streak',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'day streak',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            ritual.scheduleLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TodayAction extends ConsumerStatefulWidget {
  const _TodayAction({
    required this.groupId,
    required this.ritual,
    required this.today,
  });

  final String groupId;
  final Ritual ritual;
  final DayProgress today;

  @override
  ConsumerState<_TodayAction> createState() => _TodayActionState();
}

class _TodayActionState extends ConsumerState<_TodayAction> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ritual = widget.ritual;
    final today = widget.today;
    final controller = ref.read(ritualControllerProvider);
    final accent = Color(ritual.colorValue);

    if (ritual.type == RitualType.check) {
      return Column(
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: today.isDone ? accent : null,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _busy
                ? null
                : () => _run(() async {
                    if (today.isDone) {
                      await controller.clear(
                        groupId: widget.groupId,
                        ritual: ritual,
                      );
                    } else if (ritual.requirePhoto) {
                      // Proof is the completion for these rituals.
                      if (!mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CameraScreen(
                            groupId: widget.groupId,
                            ritual: ritual,
                            completionValue: ritual.target,
                          ),
                        ),
                      );
                    } else {
                      await controller.complete(
                        groupId: widget.groupId,
                        ritual: ritual,
                      );
                    }
                  }),
            icon: Icon(
              today.isDone
                  ? LucideIcons.checkCheck
                  : ritual.requirePhoto
                      ? LucideIcons.camera
                      : LucideIcons.check,
            ),
            label: Text(
              today.isDone
                  ? 'Done today'
                  : ritual.requirePhoto
                      ? (today.awaitingPhoto ? 'Add the photo' : 'Take a photo')
                      : 'Mark done',
            ),
          ),
          if (!today.isDone && !today.skipped)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => controller.skip(
                        groupId: widget.groupId,
                        ritual: ritual,
                      ),
                    ),
              child: const Text('Skip today'),
            ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: today.isDone ? accent : null,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        if (ritual.type == RitualType.timer) {
                          final amount = await showLogAmountSheet(
                            context,
                            ritual,
                            today,
                          );
                          if (amount != null) {
                            await controller.addProgress(
                              groupId: widget.groupId,
                              ritual: ritual,
                              current: today,
                              amount: amount,
                            );
                          }
                        } else {
                          await controller.addProgress(
                            groupId: widget.groupId,
                            ritual: ritual,
                            current: today,
                            amount: 1,
                          );
                        }
                      }),
                icon: Icon(
                  today.isDone ? LucideIcons.checkCheck : LucideIcons.plus,
                ),
                label: Text(
                  today.isDone
                      ? 'Done today'
                      : '${today.value.round()}/${ritual.target.round()} ${ritual.unit}'
                            .trim(),
                ),
              ),
            ),
          ],
        ),
        if (!today.isDone && !today.skipped)
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(
                    () => controller.skip(
                      groupId: widget.groupId,
                      ritual: ritual,
                    ),
                  ),
            child: const Text('Skip today'),
          ),
      ],
    );
  }
}

class _PhotosStrip extends ConsumerWidget {
  const _PhotosStrip({required this.groupId, required this.entries});

  final String groupId;
  final List<RitualEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoEntries = entries.where((e) => e.hasPhoto).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photoEntries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entry = photoEntries[index];
          return GestureDetector(
            onTap: () => _openPhoto(context, ref, entry),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                entry.photoUrl!,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    width: 96,
                    height: 96,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stack) => BrokenPhoto(
                  groupId: groupId,
                  entry: entry,
                  size: 96,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openPhoto(BuildContext context, WidgetRef ref, RitualEntry entry) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Consumer(
          builder: (context, ref, _) {
            final membersAsync = ref.watch(memberProfilesProvider(groupId));
            final poster = membersAsync.value?[entry.userId];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: InteractiveViewer(
                    child: Image.network(
                      entry.photoUrl!,
                      errorBuilder: (context, error, stack) => BrokenPhoto(
                        groupId: groupId,
                        entry: entry,
                        iconSize: 48,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      UserAvatar(
                        name: poster?.displayName ?? '',
                        photoUrl: poster?.photoUrl,
                        radius: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              poster?.displayName ?? 'Someone',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (entry.caption != null &&
                                entry.caption!.isNotEmpty)
                              Text(
                                entry.caption!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MembersSection extends ConsumerWidget {
  const _MembersSection({
    required this.groupId,
    required this.ritual,
    required this.entries,
  });

  final String groupId;
  final Ritual ritual;
  final List<RitualEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupProvider(groupId));
    final group = groupAsync.value;
    if (group == null || group.isPersonal) return const SizedBox.shrink();

    final membersAsync = ref.watch(memberProfilesProvider(groupId));
    final members = membersAsync.value;
    if (members == null) return const SizedBox.shrink();

    final todayKey = RitualEntry.dayKey(DateTime.now());
    final loggedToday = entries
        .where((e) => e.day == todayKey && !e.skipped)
        .map((e) => e.userId)
        .toSet();
    final myUid = ref.watch(currentUidProvider);

    return _Section(
      title: 'Members',
      child: Column(
        children: [
          for (final uid in group.memberIds)
            _MemberRow(
              profile: members[uid],
              uid: uid,
              hasLoggedToday: loggedToday.contains(uid),
              canNudge: uid != myUid,
              onNudge: () =>
                  _nudge(context, ref, uid, members[uid]?.displayName),
            ),
        ],
      ),
    );
  }

  Future<void> _nudge(
    BuildContext context,
    WidgetRef ref,
    String toUid,
    String? toName,
  ) async {
    final myUid = ref.read(currentUidProvider);
    if (myUid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('rituals')
          .doc(ritual.id)
          .collection('nudges')
          .add({
            'fromUid': myUid,
            'toUid': toUid,
            'ritualTitle': ritual.title,
            'sentAt': FieldValue.serverTimestamp(),
          });
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Nudged ${toName ?? 'them'}')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not send nudge: $error')));
      }
    }
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.profile,
    required this.uid,
    required this.hasLoggedToday,
    required this.canNudge,
    required this.onNudge,
  });

  final UserProfile? profile;
  final String uid;
  final bool hasLoggedToday;
  final bool canNudge;
  final VoidCallback onNudge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = profile?.displayName ?? 'Member';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          UserAvatar(name: name, photoUrl: profile?.photoUrl, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (hasLoggedToday)
            Icon(LucideIcons.check, size: 18, color: scheme.doneColor)
          else if (canNudge)
            TextButton(onPressed: onNudge, child: const Text('Nudge'))
          else
            Text(
              'Not yet',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
