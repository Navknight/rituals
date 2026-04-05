import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rituals/services/streak_service.dart';

class HeatmapCard extends StatelessWidget {
  const HeatmapCard({
    super.key,
    required this.title,
    required this.emoji,
    required this.scheduledDays,
    required this.streakInfo,
    this.daysToShow = 365,
  });

  final String title;
  final String emoji;
  final List<int> scheduledDays;
  final StreakInfo? streakInfo;
  final int daysToShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedKeys = streakInfo?.completedDayKeys ?? const <int>{};
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final startDay = todayMidnight.subtract(Duration(days: max(0, daysToShow - 1)));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            '$emoji $title',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Heatmap grid
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: _HeatmapGrid(
              scheduledDays: scheduledDays,
              completedDayKeys: completedKeys,
              startDay: startDay,
              endDay: todayMidnight,
            ),
          ),

          // Streak stats
          if (streakInfo != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                  label: 'Current',
                  value: streakInfo!.currentStreak.toString(),
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  label: 'Month',
                  value: streakInfo!.longestStreakThisMonth.toString(),
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  label: 'All-time',
                  value: streakInfo!.longestStreakOverall.toString(),
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({
    required this.scheduledDays,
    required this.completedDayKeys,
    required this.startDay,
    required this.endDay,
  });

  final List<int> scheduledDays;
  final Set<int> completedDayKeys;
  final DateTime startDay;
  final DateTime endDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthFormatter = DateFormat.MMM(Localizations.localeOf(context).toString());

    const cell = 12.0;
    const spacing = 3.0;

    // Align to week boundaries (Monday start)
    final gridStart = _startOfWeek(startDay);
    final gridEnd = _endOfWeek(endDay);
    final weeks = _weekStarts(gridStart, gridEnd);
    final monthLabels = _monthLabelsForWeeks(monthFormatter, weeks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month labels
        SizedBox(
          height: 16,
          child: Row(
            children: List.generate(weeks.length, (index) {
              final label = monthLabels[index];
              return SizedBox(
                width: cell + spacing,
                child: label == null
                    ? const SizedBox.shrink()
                    : Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              );
            }),
          ),
        ),
        // Grid
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weekday labels
            SizedBox(
              width: 18,
              child: Column(
                children: [
                  _weekdayLabel(context, 'M', cell),
                  SizedBox(height: cell + spacing),
                  _weekdayLabel(context, 'W', cell),
                  SizedBox(height: cell + spacing),
                  _weekdayLabel(context, 'F', cell),
                ],
              ),
            ),
            // Week columns
            Row(
              children: weeks.map((weekStart) {
                return Padding(
                  padding: const EdgeInsets.only(right: spacing),
                  child: Column(
                    children: List.generate(7, (dayOffset) {
                      final day = weekStart.add(Duration(days: dayOffset));
                      final inRange = !day.isBefore(startDay) && !day.isAfter(endDay);
                      final weekday = day.weekday; // 1=Mon, 7=Sun
                      final scheduled = scheduledDays.contains(weekday);
                      final key =
                          DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
                      final completed = completedDayKeys.contains(key);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: spacing),
                        child: Container(
                          width: cell,
                          height: cell,
                          decoration: BoxDecoration(
                            color: _cellColor(
                              theme: theme,
                              inRange: inRange,
                              scheduled: scheduled,
                              completed: completed,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _weekdayLabel(BuildContext context, String label, double cellHeight) {
    return SizedBox(
      width: 18,
      height: cellHeight,
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }

  Color _cellColor({
    required ThemeData theme,
    required bool inRange,
    required bool scheduled,
    required bool completed,
  }) {
    if (!inRange) return Colors.transparent;
    if (completed) return const Color(0xFF1DB954); // Green like Ente/GitHub
    if (scheduled) return theme.colorScheme.surfaceContainerHighest;
    return theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.35);
  }

  DateTime _startOfWeek(DateTime day) {
    final weekday = day.weekday; // 1=Mon
    return DateTime(day.year, day.month, day.day - (weekday - 1));
  }

  DateTime _endOfWeek(DateTime day) {
    final weekday = day.weekday;
    return DateTime(day.year, day.month, day.day + (7 - weekday));
  }

  List<DateTime> _weekStarts(DateTime start, DateTime endInclusive) {
    final weeks = <DateTime>[];
    for (var day = start;
        !day.isAfter(endInclusive);
        day = day.add(const Duration(days: 7))) {
      weeks.add(day);
    }
    return weeks;
  }

  List<String?> _monthLabelsForWeeks(DateFormat formatter, List<DateTime> weeks) {
    final labels = <String?>[];
    int? lastMonth;
    for (final weekStart in weeks) {
      if (weekStart.day <= 7 && weekStart.month != lastMonth) {
        labels.add(formatter.format(weekStart));
        lastMonth = weekStart.month;
      } else {
        labels.add(null);
      }
    }
    return labels;
  }
}
