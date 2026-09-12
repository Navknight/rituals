import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rituals/core/providers.dart';
import 'package:rituals/features/stats/stat_widgets.dart';
import 'package:rituals/features/streaks/ritual_detail_screen.dart';
import 'package:rituals/models/ritual.dart';
import 'package:rituals/models/ritual_entry.dart';
import 'package:rituals/services/streak_service.dart';

class RitualSummary {
  final Ritual ritual;
  final StreakInfo info;

  const RitualSummary(this.ritual, this.info);
}

final spaceSummaryProvider =
    FutureProvider.family<List<RitualSummary>, String>((ref, groupId) async {
  final rituals = await ref.watch(ritualsProvider(groupId).future);
  final service = ref.watch(ritualServiceProvider);
  final streaks = ref.watch(streakServiceProvider);

  final summaries = <RitualSummary>[];
  for (final ritual in rituals.where((r) => !r.archived)) {
    final entries = await service.fetchRitualEntries(groupId, ritual.id);
    summaries.add(RitualSummary(ritual, streaks.analyse(
      ritual: ritual,
      entries: entries,
    )));
  }
  summaries.sort((a, b) => b.info.score.compareTo(a.info.score));
  return summaries;
});

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(spaceSummaryProvider(groupId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load progress: $e',
              textAlign: TextAlign.center),
        ),
      ),
      data: (summaries) {
        if (summaries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.chartNoAxesColumn,
                      size: 52, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('Nothing to chart yet',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Add a ritual and log a few days. Your streaks and '
                    'consistency show up here.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final avgScore = summaries.fold<double>(
              0,
              (sum, s) => sum + s.info.score,
            ) /
            summaries.length;
        final totalDone = summaries.fold<int>(
          0,
          (sum, s) => sum + s.info.totalCompletions,
        );
        final bestStreak = summaries.fold<int>(
          0,
          (best, s) =>
              s.info.currentStreak > best ? s.info.currentStreak : best,
        );
        final perfectDays = _perfectDays(summaries);

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(spaceSummaryProvider(groupId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              StatRow(children: [
                StatTile(
                  label: 'Consistency',
                  value: '${(avgScore * 100).round()}%',
                  icon: LucideIcons.trendingUp,
                ),
                StatTile(
                  label: 'Best streak',
                  value: '$bestStreak',
                  hint: bestStreak == 1 ? 'day' : 'days',
                  icon: LucideIcons.flame,
                ),
              ]),
              const SizedBox(height: 10),
              StatRow(children: [
                StatTile(
                  label: 'Perfect days',
                  value: '$perfectDays',
                  hint: 'last 30 days',
                  icon: LucideIcons.circleCheck,
                ),
                StatTile(
                  label: 'Times logged',
                  value: '$totalDone',
                  icon: LucideIcons.listChecks,
                ),
              ]),
              const SizedBox(height: 26),
              Text(
                'BY RITUAL',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...summaries.map((s) => _SummaryCard(
                    summary: s,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RitualDetailScreen(
                          groupId: groupId,
                          ritual: s.ritual,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  int _perfectDays(List<RitualSummary> summaries) {
    final today = DateTime.now();
    var count = 0;
    for (var i = 0; i < 30; i++) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      final key = RitualEntry.dayKey(day);
      var due = 0;
      var done = 0;
      for (final s in summaries) {
        if (!s.ritual.isDueOn(day)) continue;
        final result = s.info.days[key];
        if (result == null || result.status == DayStatus.skipped) continue;
        due++;
        if (result.status == DayStatus.done) done++;
      }
      if (due > 0 && due == done) count++;
    }
    return count;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.onTap});

  final RitualSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = Color(summary.ritual.colorValue);
    final info = summary.info;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(summary.ritual.emoji,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      summary.ritual.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(LucideIcons.flame, size: 15, color: accent),
                  const SizedBox(width: 3),
                  Text(
                    '${info.currentStreak}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: info.score,
                  minHeight: 6,
                  color: accent,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${(info.score * 100).round()}% consistency  ·  '
                '${(info.completionRate * 100).round()}% kept  ·  '
                '${info.totalCompletions} logged',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
