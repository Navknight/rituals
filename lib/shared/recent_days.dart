import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rituals/models/ritual.dart';
import 'package:rituals/models/ritual_entry.dart';
import 'package:rituals/services/streak_service.dart';
import 'package:rituals/shared/entry_photo.dart';

/// Amber of the streak bolt, shared by the chip, the hero and the calendar.
const streakBolt = Color(0xFFFFBC03);

/// The last few days of a ritual as a row of tilted photo prints, after Ente's
/// ritual cards. A day with proof shows its newest photo, a done day without
/// one a filled bolt tile, today still open a camera slot, and anything else a
/// dashed outline.
class RecentDaysStrip extends StatelessWidget {
  const RecentDaysStrip({
    super.key,
    required this.groupId,
    required this.ritual,
    required this.entries,
    required this.days,
    this.count = 5,
    this.onTapToday,
    this.onTapPhoto,
  });

  final String groupId;
  final Ritual ritual;
  final List<RitualEntry> entries;
  final Map<String, DayResult> days;
  final int count;
  final VoidCallback? onTapToday;
  final void Function(RitualEntry entry)? onTapPhoto;

  // Ente's tilt pattern, in radians.
  static const _tilts = [-0.05, 0.10, -0.08, 0.08];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final photosByDay = <String, List<RitualEntry>>{};
    for (final e in entries) {
      if (e.hasPhoto) photosByDay.putIfAbsent(e.day, () => []).add(e);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final width = (constraints.maxWidth - spacing * (count - 1)) / count;
        return Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i != 0) const SizedBox(width: spacing),
              _day(
                context,
                DateTime(today.year, today.month, today.day - (count - 1 - i)),
                i,
                width,
                today,
                photosByDay,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _day(
    BuildContext context,
    DateTime day,
    int index,
    double width,
    DateTime today,
    Map<String, List<RitualEntry>> photosByDay,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final key = RitualEntry.dayKey(day);
    final status = days[key]?.status;
    final photos = (photosByDay[key] ?? const <RitualEntry>[]).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final isToday = day == today;
    final height = width * 1.34;
    final accent = Color(ritual.colorValue);

    final Widget tile;
    if (photos.isNotEmpty) {
      tile = _Print(
        width: width,
        height: height,
        tilt: _tilts[index % _tilts.length],
        count: photos.length,
        onTap: onTapPhoto == null ? null : () => onTapPhoto!(photos.first),
        child: EntryPhoto(
          entry: photos.first,
          groupId: groupId,
          cacheWidth: 240,
        ),
      );
    } else if (status == DayStatus.done) {
      tile = _Print(
        width: width,
        height: height,
        tilt: _tilts[index % _tilts.length],
        child: ColoredBox(
          color: accent,
          child: const Icon(LucideIcons.zap, color: Colors.white, size: 20),
        ),
      );
    } else if (isToday && status != DayStatus.skipped) {
      tile = _Dashed(
        width: width,
        height: height,
        color: accent,
        onTap: onTapToday,
        child: Icon(LucideIcons.camera, size: 20, color: accent),
      );
    } else {
      final muted = status == DayStatus.notDue ||
          status == DayStatus.outOfRange ||
          status == null;
      tile = _Dashed(
        width: width,
        height: height,
        color: muted ? scheme.outlineVariant : scheme.outline,
        child: status == DayStatus.skipped
            ? Icon(LucideIcons.minus, size: 16, color: scheme.outline)
            : null,
      );
    }

    return Semantics(
      label: '${_weekday(day)} ${day.day}',
      child: Column(
        children: [
          tile,
          const SizedBox(height: 8),
          Text(
            '${_weekday(day)}\n${day.day}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.15,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
              color: isToday ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static String _weekday(DateTime day) =>
      const ['M', 'Tu', 'W', 'Th', 'F', 'Sa', 'Su'][day.weekday - 1];
}

/// A photo print: white border, soft drop shadow, slight tilt.
class _Print extends StatelessWidget {
  const _Print({
    required this.width,
    required this.height,
    required this.tilt,
    required this.child,
    this.count = 0,
    this.onTap,
  });

  final double width;
  final double height;
  final double tilt;
  final Widget child;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Transform.rotate(
                angle: tilt,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3F000000),
                        blurRadius: 5.3,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox.expand(child: child),
                  ),
                ),
              ),
            ),
            if (count > 1)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1DB954),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Dashed extends StatelessWidget {
  const _Dashed({
    required this.width,
    required this.height,
    required this.color,
    this.child,
    this.onTap,
  });

  final double width;
  final double height;
  final Color color;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashPainter(color),
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(0.6),
        const Radius.circular(8),
      ));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Streak count with the amber bolt, as on Ente's ritual cards.
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$streak',
            style: TextStyle(
              fontSize: 13,
              height: 1,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(LucideIcons.zap, size: 14, color: streakBolt),
        ],
      ),
    );
  }
}
