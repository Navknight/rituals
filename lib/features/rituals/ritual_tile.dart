import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rituals/app/theme.dart';
import 'package:rituals/features/rituals/ritual_controller.dart';
import 'package:rituals/models/ritual.dart';

/// A ritual on the Today list.
///
/// Tapping the ring logs progress, swiping reveals skip and detail actions,
/// and the ring itself doubles as the progress readout for quantity and timer
/// rituals.
class RitualTile extends StatelessWidget {
  const RitualTile({
    super.key,
    required this.ritual,
    required this.progress,
    required this.dueToday,
    required this.onToggle,
    required this.onSkip,
    required this.onOpen,
    required this.onAdd,
    required this.onAdjust,
    this.trailing,
  });

  final Ritual ritual;
  final DayProgress progress;
  final bool dueToday;
  final VoidCallback onToggle;
  final VoidCallback onSkip;
  final VoidCallback onOpen;

  /// Adds one unit to a quantity ritual, or opens the timer sheet.
  final VoidCallback onAdd;

  /// Opens the sheet that sets today's total, so progress can go down too.
  final VoidCallback onAdjust;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = Color(ritual.colorValue);
    final done = progress.isDone;
    final skipped = progress.skipped;

    return Slidable(
      key: ValueKey(ritual.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => onSkip(),
            icon: skipped ? LucideIcons.undo2 : LucideIcons.calendarOff,
            label: skipped ? 'Unskip' : 'Skip',
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            foregroundColor: theme.colorScheme.onSurface,
            borderRadius: BorderRadius.circular(Corners.card),
          ),
          SlidableAction(
            onPressed: (_) => onOpen(),
            icon: LucideIcons.chartNoAxesColumn,
            label: 'Stats',
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            borderRadius: BorderRadius.circular(Corners.card),
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        color: done
            ? accent.withValues(alpha: 0.10)
            : theme.colorScheme.surfaceContainerLow,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(Corners.card),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              children: [
                _ProgressRing(
                  ritual: ritual,
                  progress: progress,
                  accent: accent,
                  onTap: onToggle,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ritual.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: skipped
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: skipped || !dueToday
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
                if (ritual.type != RitualType.check && !skipped)
                  // Long press corrects the running total. Without it a count
                  // ritual could only ever go up.
                  GestureDetector(
                    onLongPress: onAdjust,
                    child: IconButton(
                      onPressed: done ? onAdjust : onAdd,
                      icon: Icon(
                        done
                            ? LucideIcons.pencil
                            : ritual.type == RitualType.timer
                                ? LucideIcons.timer
                                : LucideIcons.plus,
                      ),
                      tooltip: done
                          ? 'Edit amount'
                          : ritual.type == RitualType.timer
                              ? 'Start timer'
                              : 'Add one, hold to edit',
                      style: IconButton.styleFrom(foregroundColor: accent),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    if (progress.skipped) return 'Skipped today';
    if (!dueToday) return 'Rest day · ${ritual.scheduleLabel}';
    if (progress.awaitingPhoto) return 'Needs a photo to count';

    switch (ritual.type) {
      case RitualType.check:
        if (progress.isDone) return 'Done today';
        return ritual.requirePhoto
            ? '${ritual.scheduleLabel} · photo proof'
            : ritual.scheduleLabel;
      case RitualType.quantity:
        return '${trimNumber(progress.value)} of ${ritual.targetLabel}';
      case RitualType.timer:
        return '${trimNumber(progress.value)} of ${trimNumber(ritual.target)} min';
    }
  }

}

/// The tappable ring: a checkbox for check rituals, a progress dial otherwise.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.ritual,
    required this.progress,
    required this.accent,
    required this.onTap,
  });

  final Ritual ritual;
  final DayProgress progress;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = progress.isDone;
    final skipped = progress.skipped;

    return Semantics(
      button: true,
      label: done ? 'Mark ${ritual.title} undone' : 'Complete ${ritual.title}',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: skipped ? 0 : progress.fraction),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 3.5,
                    strokeCap: StrokeCap.round,
                    color: accent,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: skipped
                    ? Icon(
                        LucideIcons.minus,
                        key: const ValueKey('skip'),
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : done
                        ? Icon(
                            LucideIcons.check,
                            key: const ValueKey('done'),
                            color: accent,
                            size: 26,
                          )
                        : progress.awaitingPhoto
                            ? Icon(
                                LucideIcons.camera,
                                key: const ValueKey('needsPhoto'),
                                color: accent,
                                size: 22,
                              )
                        : Text(
                            ritual.emoji,
                            key: const ValueKey('emoji'),
                            style: const TextStyle(fontSize: 22),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
