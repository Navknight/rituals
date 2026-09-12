import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rituals/features/rituals/ritual_controller.dart';
import 'package:rituals/features/rituals/ritual_editor.dart';
import 'package:rituals/models/ritual.dart';

/// Runs a live timer for [ritual] and returns the minutes elapsed to add to
/// today's total, or null if nothing should be logged.
Future<double?> showRitualTimer(
  BuildContext context,
  Ritual ritual,
  DayProgress progress,
) {
  return Navigator.of(context).push<double>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _RitualTimerScreen(ritual: ritual, progress: progress),
    ),
  );
}

class _RitualTimerScreen extends StatefulWidget {
  const _RitualTimerScreen({required this.ritual, required this.progress});

  final Ritual ritual;
  final DayProgress progress;

  @override
  State<_RitualTimerScreen> createState() => _RitualTimerScreenState();
}

class _RitualTimerScreenState extends State<_RitualTimerScreen> {
  Timer? _ticker;
  DateTime? _startedAt;
  Duration _accumulated = Duration.zero;
  bool _running = false;
  bool _targetAnnounced = false;

  Duration get _elapsed {
    final startedAt = _startedAt;
    if (_running && startedAt != null) {
      return _accumulated + DateTime.now().difference(startedAt);
    }
    return _accumulated;
  }

  double get _elapsedMinutes => _elapsed.inMilliseconds / 60000;

  double get _totalMinutes => widget.progress.value + _elapsedMinutes;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _running = true;
      _startedAt = DateTime.now();
      _ticker ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() {});
        _checkTarget();
      });
    });
  }

  void _pause() {
    setState(() {
      _accumulated = _elapsed;
      _startedAt = null;
      _running = false;
    });
  }

  void _checkTarget() {
    if (_targetAnnounced) return;
    if (widget.ritual.target > 0 && _totalMinutes >= widget.ritual.target) {
      _targetAnnounced = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _done() {
    Navigator.of(context).pop(_elapsedMinutes > 0 ? _elapsedMinutes : null);
  }

  Future<void> _handleBack() async {
    final elapsedMinutes = _elapsedMinutes;
    if (elapsedMinutes <= 0) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Discard ${_trim(elapsedMinutes)} min?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep running'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _enterManually() async {
    final navigator = Navigator.of(context);
    final result = await showLogAmountSheet(context, widget.ritual, widget.progress);
    navigator.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ritual = widget.ritual;
    final accent = Color(ritual.colorValue);
    final target = ritual.target;
    final fraction =
        target <= 0 ? 0.0 : (_totalMinutes / target).clamp(0.0, 1.0);
    final reached = target > 0 && _totalMinutes >= target;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${ritual.emoji} ${ritual.title}'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handleBack,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 260,
                          height: 260,
                          child: CircularProgressIndicator(
                            value: fraction,
                            strokeWidth: 10,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(accent),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatDuration(_elapsed),
                              style: textTheme.displaySmall?.copyWith(
                                fontFeatures: const [FontFeature.tabularFigures()],
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_trim(_totalMinutes)} of ${_trim(target)} min',
                              style: textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (reached) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Target reached',
                                style: textTheme.labelLarge?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (!_running)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _start,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(_accumulated == Duration.zero ? 'Start' : 'Resume'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pause,
                          icon: const Icon(Icons.pause),
                          label: const Text('Pause'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _elapsedMinutes > 0 ? _done : null,
                        icon: const Icon(Icons.check),
                        label: const Text('Done'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: reached ? accent : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _enterManually,
                  child: const Text('Enter minutes instead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
  }
  return '$mm:$ss';
}

String _trim(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}
