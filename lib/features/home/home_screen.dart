import 'package:flutter/material.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rituals/core/providers.dart';
import 'package:rituals/core/settings_provider.dart';
import 'package:rituals/features/commentary/commentary.dart';
import 'package:rituals/features/rituals/ritual_controller.dart';
import 'package:rituals/features/rituals/ritual_editor.dart';
import 'package:rituals/features/camera/camera_screen.dart';
import 'package:rituals/features/rituals/ritual_tile.dart';
import 'package:rituals/features/streaks/ritual_detail_screen.dart';
import 'package:rituals/models/ritual.dart';
import 'package:rituals/models/ritual_entry.dart';

enum RitualFilter { today, all, archived }

class RitualFilterController extends Notifier<RitualFilter> {
  @override
  RitualFilter build() => RitualFilter.today;

  void set(RitualFilter value) => state = value;
}

final ritualFilterProvider =
    NotifierProvider<RitualFilterController, RitualFilter>(
  RitualFilterController.new,
);

/// The daily list. Everything can be logged from here without opening a
/// ritual: tap the ring to complete, swipe for skip, plus button to add
/// progress.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ritualsAsync = ref.watch(ritualsProvider(groupId));
    final entriesAsync = ref.watch(todayEntriesProvider(groupId));
    final filter = ref.watch(ritualFilterProvider);

    return ritualsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(ritualsProvider(groupId)),
      ),
      data: (allRituals) {
        final entries = entriesAsync.value ?? const {};
        final today = DateTime.now();

        final active = allRituals.where((r) => !r.archived).toList();
        final archived = allRituals.where((r) => r.archived).toList();

        if (allRituals.isEmpty) {
          return _EmptyState(groupId: groupId);
        }

        final due = active.where((r) => r.isDueOn(today)).toList();
        final rest = active.where((r) => !r.isDueOn(today)).toList();

        final doneCount = due
            .where((r) => DayProgress.from(r, entries[r.id]).isDone)
            .length;

        final sections = <Widget>[];

        if (filter != RitualFilter.archived) {
          final settings = ref.watch(settingsProvider);
          final dayContext = CommentaryContext(
            doneToday: doneCount,
            dueToday: due.length,
            hour: today.hour,
          );
          sections.add(
            _DayHeader(
              date: today,
              done: doneCount,
              total: due.length,
              remark: ref.read(commentaryProvider).lineFor(
                    Commentary.momentForDay(dayContext),
                    tone: settings.tone,
                    allowProfanity: settings.allowProfanity,
                    context: dayContext,
                  ),
            ),
          );
        }

        switch (filter) {
          case RitualFilter.today:
            sections.addAll(
              _section(context, ref, 'Today', due, entries, dueToday: true),
            );
            if (rest.isNotEmpty) {
              sections.addAll(
                _section(context, ref, 'Not due today', rest, entries,
                    dueToday: false),
              );
            }
          case RitualFilter.all:
            sections.addAll(
              _section(context, ref, 'All rituals', active, entries,
                  dueToday: true),
            );
          case RitualFilter.archived:
            if (archived.isEmpty) {
              sections.add(
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Text(
                    'Nothing archived.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            } else {
              sections.addAll(
                _section(context, ref, 'Archived', archived, entries,
                    dueToday: false),
              );
            }
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ritualsProvider(groupId));
            ref.invalidate(todayEntriesProvider(groupId));
          },
          child: ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 120),
            children: [
              _FilterBar(
                filter: filter,
                archivedCount: archived.length,
                onChanged: (value) =>
                    ref.read(ritualFilterProvider.notifier).set(value),
              ),
              ...sections,
            ],
          ),
        );
      },
    );
  }

  List<Widget> _section(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<Ritual> rituals,
    Map<String, List<RitualEntry>> entries, {
    required bool dueToday,
  }) {
    if (rituals.isEmpty) return const [];
    final theme = Theme.of(context);

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      ...rituals.map((ritual) {
        final progress = DayProgress.from(ritual, entries[ritual.id]);
        return RitualTile(
          ritual: ritual,
          progress: progress,
          dueToday: dueToday && ritual.isDueOn(DateTime.now()),
          onToggle: () => _toggle(context, ref, ritual, progress),
          onSkip: () => _skip(context, ref, ritual, progress),
          onAdd: () => _add(context, ref, ritual, progress),
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RitualDetailScreen(
                groupId: groupId,
                ritual: ritual,
              ),
            ),
          ),
        );
      }),
    ];
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    Ritual ritual,
    DayProgress progress,
  ) async {
    final controller = ref.read(ritualControllerProvider);
    if (!controller.ready) return;

    if (progress.isDone || progress.skipped) {
      await controller.clear(groupId: groupId, ritual: ritual);
      if (context.mounted) {
        _undoBar(
          context,
          ref,
          ritual,
          progress,
          _remark(ref, Moment.undone, ritual: ritual) ??
              'Cleared ${ritual.title}',
        );
      }
      return;
    }

    // A ritual that asks for proof is not done until the photo lands, so the
    // tap opens the camera rather than ticking a box.
    if (ritual.requirePhoto) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CameraScreen(
            groupId: groupId,
            ritualId: ritual.id,
            completionValue: ritual.target,
          ),
        ),
      );
      return;
    }

    await controller.complete(groupId: groupId, ritual: ritual);
    if (!context.mounted) return;

    // The streak including today, so a milestone is announced as it happens.
    final entries = ref.read(spaceEntriesProvider(groupId)).value?[ritual.id];
    final streak = ref.read(streakServiceProvider).analyse(
          ritual: ritual,
          entries: [
            ...?entries?.where((e) => e.day != RitualEntry.dayKey(DateTime.now())),
            RitualEntry(
              id: 'pending',
              userId: '',
              ritualId: ritual.id,
              day: RitualEntry.dayKey(DateTime.now()),
              value: ritual.target,
              createdAt: DateTime.now(),
            ),
          ],
        ).currentStreak;

    final settings = ref.read(settingsProvider);
    if (settings.celebrate) {
      Confetti.launch(
        context,
        options: ConfettiOptions(
          particleCount: 40,
          spread: 65,
          y: 0.6,
          colors: [Color(ritual.colorValue), Theme.of(context).colorScheme.tertiary],
        ),
      );
    }
    _undoBar(
      context,
      ref,
      ritual,
      progress,
      _remark(
            ref,
            Commentary.isMilestone(streak)
                ? Moment.streakMilestone
                : Moment.completed,
            ritual: ritual,
            streak: streak,
          ) ??
          '${ritual.title} done',
    );
  }

  /// A line for the moment, or null when commentary is off.
  String? _remark(
    WidgetRef ref,
    Moment moment, {
    Ritual? ritual,
    int streak = 0,
  }) {
    final settings = ref.read(settingsProvider);
    return ref.read(commentaryProvider).lineFor(
          moment,
          tone: settings.tone,
          allowProfanity: settings.allowProfanity,
          context: CommentaryContext(
            streak: streak,
            ritualTitle: ritual?.title,
            hour: DateTime.now().hour,
          ),
        );
  }

  Future<void> _skip(
    BuildContext context,
    WidgetRef ref,
    Ritual ritual,
    DayProgress progress,
  ) async {
    final controller = ref.read(ritualControllerProvider);
    if (!controller.ready) return;

    if (progress.skipped) {
      await controller.clear(groupId: groupId, ritual: ritual);
    } else {
      await controller.skip(groupId: groupId, ritual: ritual);
    }
    if (context.mounted) {
      _undoBar(
        context,
        ref,
        ritual,
        progress,
        progress.skipped
            ? '${ritual.title} back on the schedule'
            : _remark(ref, Moment.skipped, ritual: ritual) ??
                'Skipped ${ritual.title}. Streak held.',
      );
    }
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    Ritual ritual,
    DayProgress progress,
  ) async {
    final controller = ref.read(ritualControllerProvider);
    if (!controller.ready) return;

    if (ritual.type == RitualType.timer) {
      final minutes = await showLogAmountSheet(context, ritual, progress);
      if (minutes == null) return;
      await controller.addProgress(
        groupId: groupId,
        ritual: ritual,
        current: progress,
        amount: minutes,
      );
    } else {
      await controller.addProgress(
        groupId: groupId,
        ritual: ritual,
        current: progress,
        amount: 1,
      );
    }
    if (context.mounted) {
      _undoBar(context, ref, ritual, progress, 'Logged ${ritual.title}');
    }
  }

  void _undoBar(
    BuildContext context,
    WidgetRef ref,
    Ritual ritual,
    DayProgress previous,
    String message,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => ref.read(ritualControllerProvider).restore(
                groupId: groupId,
                ritual: ritual,
                previous: previous,
              ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.date,
    required this.done,
    required this.total,
    this.remark,
  });

  final DateTime date;
  final int done;
  final int total;
  final String? remark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = total == 0 ? 0.0 : done / total;
    final allDone = total > 0 && done == total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _weekdayName(date.weekday),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            total == 0 ? 'Nothing scheduled today' : '$done of $total done',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: allDone
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: allDone ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (remark != null) ...[
            const SizedBox(height: 6),
            Text(
              remark!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
          if (total > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ],
      ),
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
    return names[(weekday - 1) % 7];
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.archivedCount,
    required this.onChanged,
  });

  final RitualFilter filter;
  final int archivedCount;
  final ValueChanged<RitualFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SegmentedButton<RitualFilter>(
        segments: [
          const ButtonSegment(
            value: RitualFilter.today,
            label: Text('Today'),
          ),
          const ButtonSegment(
            value: RitualFilter.all,
            label: Text('All'),
          ),
          if (archivedCount > 0)
            const ButtonSegment(
              value: RitualFilter.archived,
              label: Text('Archived'),
            ),
        ],
        selected: {filter},
        showSelectedIcon: false,
        onSelectionChanged: (values) => onChanged(values.first),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.sprout,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Start with one',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a habit small enough that you cannot talk yourself out '
              'of it. You can always add more later.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => showRitualEditor(context, ref, groupId: groupId),
              icon: const Icon(LucideIcons.plus, size: 20),
              label: const Text('Add a ritual'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.triangleAlert,
              size: 44,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text('Could not load rituals', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
