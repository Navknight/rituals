import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rituals/app/theme.dart';
import 'package:rituals/services/streak_service.dart';

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _dayKey(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

/// Colour for one day cell, shared by [HeatmapCalendar] and [MonthCalendar].
Color dayStatusColor(
  DayStatus status,
  double progress,
  ColorScheme scheme,
  Color accent,
) {
  switch (status) {
    case DayStatus.done:
      return accent.withValues(alpha: math.max(progress, 0.35));
    case DayStatus.partial:
      return accent.withValues(alpha: 0.3);
    case DayStatus.skipped:
      return scheme.skippedColor.withValues(alpha: 0.25);
    case DayStatus.missed:
      return scheme.missedColor;
    case DayStatus.notDue:
    case DayStatus.outOfRange:
      return scheme.emptyColor;
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Corners.card),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: accent ?? scheme.primary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 420;
        final columns = narrow ? 2 : children.length;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children)
              SizedBox(
                width: (constraints.maxWidth - (columns - 1) * 12) / columns,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class HeatmapCalendar extends StatelessWidget {
  const HeatmapCalendar({
    super.key,
    required this.days,
    required this.accent,
    this.weeks = 26,
    this.today,
    this.onTapDay,
  });

  final Map<String, DayResult> days;
  final Color accent;
  final int weeks;
  final DateTime? today;
  final void Function(DayResult)? onTapDay;

  static const double _cell = 13;
  static const double _gap = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = today ?? DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final endOfWeek = todayMidnight.add(
      Duration(days: DateTime.daysPerWeek - todayMidnight.weekday),
    );
    final start = endOfWeek.subtract(Duration(days: weeks * 7 - 1));

    final columns = <List<DateTime>>[];
    for (var w = 0; w < weeks; w++) {
      final columnStart = start.add(Duration(days: w * 7));
      columns.add(
        List.generate(7, (i) => columnStart.add(Duration(days: i))),
      );
    }

    final monthLabels = <int, String>{};
    var lastMonth = -1;
    for (var w = 0; w < columns.length; w++) {
      final month = columns[w].first.month;
      if (month != lastMonth) {
        monthLabels[w] = _monthNames[month - 1].substring(0, 3);
        lastMonth = month;
      }
    }

    return SizedBox(
      height: 7 * (_cell + _gap) + 20,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  for (var i = 0; i < 7; i++)
                    SizedBox(
                      height: _cell + _gap,
                      child: (i % 2 == 1)
                          ? Text(
                              _weekdayShort[i].substring(0, 1),
                              style: TextStyle(
                                fontSize: 9,
                                color: scheme.onSurfaceVariant,
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            ),
            for (var w = 0; w < columns.length; w++)
              Padding(
                padding: const EdgeInsets.only(right: _gap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 20,
                      width: _cell,
                      child: monthLabels.containsKey(w)
                          ? Text(
                              monthLabels[w]!,
                              style: TextStyle(
                                fontSize: 9,
                                color: scheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.visible,
                              maxLines: 1,
                              softWrap: false,
                            )
                          : null,
                    ),
                    for (final day in columns[w])
                      Padding(
                        padding: const EdgeInsets.only(bottom: _gap),
                        child: _HeatCell(
                          day: day,
                          result: days[_dayKey(day)],
                          accent: accent,
                          isFuture: day.isAfter(todayMidnight),
                          onTap: onTapDay,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.day,
    required this.result,
    required this.accent,
    required this.isFuture,
    required this.onTap,
  });

  final DateTime day;
  final DayResult? result;
  final Color accent;
  final bool isFuture;
  final void Function(DayResult)? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isFuture
        ? Colors.transparent
        : result == null
            ? scheme.emptyColor
            : dayStatusColor(result!.status, result!.progress, scheme, accent);

    final cell = Container(
      width: HeatmapCalendar._cell,
      height: HeatmapCalendar._cell,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );

    if (isFuture || result == null || onTap == null) return cell;
    return GestureDetector(
      onTap: () => onTap!(result!),
      child: cell,
    );
  }
}

class ScoreChart extends StatelessWidget {
  const ScoreChart({super.key, required this.history, required this.accent});

  final List<double> history;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (history.length < 2) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'Not enough data yet',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final spots = [
      for (var i = 0; i < history.length; i++)
        FlSpot(i.toDouble(), history[i]),
    ];

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 1,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 0.25,
            getDrawingHorizontalLine: (value) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 0.25,
                reservedSize: 38,
                getTitlesWidget: (value, meta) => Text(
                  '${(value * 100).round()}%',
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      '${(s.y * 100).round()}%',
                      TextStyle(color: scheme.onInverseSurface),
                    ),
                  )
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: accent,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: 0.35),
                    accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WeekdayBars extends StatelessWidget {
  const WeekdayBars({super.key, required this.rates, required this.accent});

  final Map<int, double> rates;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (rates.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'Not enough data yet',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: 1,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 0.25,
            getDrawingHorizontalLine: (value) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${(rod.toY * 100).round()}%',
                TextStyle(color: scheme.onInverseSurface),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index > 6) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _weekdayShort[index],
                      style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var weekday = 1; weekday <= 7; weekday++)
              BarChartGroupData(
                x: weekday - 1,
                barRods: [
                  BarChartRodData(
                    toY: rates[weekday] ?? 0,
                    color: accent,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.days,
    required this.accent,
    required this.onPrev,
    required this.onNext,
    this.onTapDay,
  });

  final DateTime month;
  final Map<String, DayResult> days;
  final Color accent;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final void Function(DateTime)? onTapDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final today = DateTime(now.year, now.month, now.day);

    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstDay.weekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_monthNames[month.month - 1]} ${month.year}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Row(
              children: [
                IconButton(
                  onPressed: onPrev,
                  icon: const Icon(Icons.chevron_left),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: isCurrentMonth ? null : onNext,
                  icon: const Icon(Icons.chevron_right),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final label in _weekdayShort)
              Expanded(
                child: Center(
                  child: Text(
                    label.substring(0, 1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < rows; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final cellIndex = row * 7 + col;
                        final dayNum = cellIndex - leadingBlanks + 1;
                        if (dayNum < 1 || dayNum > daysInMonth) {
                          return const SizedBox(height: 36);
                        }
                        final date = DateTime(month.year, month.month, dayNum);
                        final result = days[_dayKey(date)];
                        final isToday = date == today;
                        final color = result == null
                            ? scheme.emptyColor
                            : dayStatusColor(
                                result.status, result.progress, scheme, accent);
                        return Padding(
                          padding: const EdgeInsets.all(2),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: GestureDetector(
                              onTap: onTapDay == null ? null : () => onTapDay!(date),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(8),
                                  border: isToday
                                      ? Border.all(color: accent, width: 2)
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '$dayNum',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
