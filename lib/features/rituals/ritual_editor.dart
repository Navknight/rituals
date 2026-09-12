import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rituals/app/theme.dart';
import 'package:rituals/core/providers.dart';
import 'package:rituals/models/ritual.dart';

/// Accent colours offered when creating or editing a ritual.
const kRitualColors = <int>[
  0xFF1DB954,
  0xFF3B82F6,
  0xFF8B5CF6,
  0xFFEC4899,
  0xFFF59E0B,
  0xFFEF4444,
  0xFF14B8A6,
  0xFF6366F1,
];

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

Future<void> showRitualEditor(
  BuildContext context,
  WidgetRef ref, {
  required String groupId,
  Ritual? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Corners.sheet)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _RitualEditorSheet(groupId: groupId, existing: existing),
      );
    },
  );
}

class _RitualEditorSheet extends ConsumerStatefulWidget {
  const _RitualEditorSheet({required this.groupId, this.existing});

  final String groupId;
  final Ritual? existing;

  @override
  ConsumerState<_RitualEditorSheet> createState() => _RitualEditorSheetState();
}

class _RitualEditorSheetState extends ConsumerState<_RitualEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _unitController;
  late final TextEditingController _targetController;

  late String _emoji;
  late RitualType _type;
  late ScheduleType _scheduleType;
  late List<int> _scheduleDays;
  late int _timesPerWeek;
  late int _intervalDays;
  late String? _reminderTime;
  late bool _requirePhoto;
  late int _colorValue;
  bool _saving = false;
  String? _titleError;
  String? _scheduleError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ritual = widget.existing;
    _titleController = TextEditingController(text: ritual?.title ?? '');
    _descriptionController =
        TextEditingController(text: ritual?.description ?? '');
    _unitController = TextEditingController(text: ritual?.unit ?? '');
    _targetController =
        TextEditingController(text: _formatTarget(ritual?.target ?? 1));
    _emoji = ritual?.emoji ?? '🎯';
    _type = ritual?.type ?? RitualType.check;
    _scheduleType = ritual?.scheduleType ?? ScheduleType.weekdays;
    _scheduleDays =
        List<int>.from(ritual?.scheduleDays ?? const [1, 2, 3, 4, 5, 6, 7]);
    _timesPerWeek = ritual?.timesPerWeek ?? 3;
    _intervalDays = ritual?.intervalDays ?? 2;
    _reminderTime = ritual?.reminderTime;
    _requirePhoto = ritual?.requirePhoto ?? true;
    _colorValue = ritual?.colorValue ?? kRitualColors.first;
  }

  static String _formatTarget(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toString();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickEmoji() async {
    final colorScheme = Theme.of(context).colorScheme;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(Corners.sheet)),
      ),
      builder: (sheetContext) {
        return SizedBox(
          height: 420,
          child: EmojiPicker(
            onEmojiSelected: (category, emoji) {
              Navigator.of(sheetContext).pop(emoji.emoji);
            },
            config: Config(
              height: 380,
              emojiViewConfig: const EmojiViewConfig(columns: 8),
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _emoji = picked);
    }
  }

  Future<void> _pickReminder() async {
    TimeOfDay initial = TimeOfDay.now();
    if (_reminderTime != null) {
      final parts = _reminderTime!.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          initial = TimeOfDay(hour: hour, minute: minute);
        }
      }
    }
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      setState(() => _reminderTime = '$hour:$minute');
    }
  }

  void _toggleWeekday(int day) {
    setState(() {
      if (_scheduleDays.contains(day)) {
        _scheduleDays.remove(day);
      } else {
        _scheduleDays.add(day);
      }
      _scheduleError = null;
    });
  }

  Future<void> _confirmDelete() async {
    final ritual = widget.existing;
    if (ritual == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete ritual'),
          content: Text('Delete "${ritual.title}" and all its logs? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final navigator = Navigator.of(context);
    await ref
        .read(ritualServiceProvider)
        .deleteRitual(widget.groupId, ritual.id);
    navigator.pop();
  }

  Future<void> _toggleArchive() async {
    final ritual = widget.existing;
    if (ritual == null) return;
    final navigator = Navigator.of(context);
    await ref.read(ritualServiceProvider).setArchived(
          widget.groupId,
          ritual.id,
          !ritual.archived,
        );
    navigator.pop();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    setState(() {
      _titleError = title.isEmpty ? 'Give it a name' : null;
      _scheduleError = _scheduleType == ScheduleType.weekdays &&
              _scheduleDays.isEmpty
          ? 'Pick at least one day'
          : null;
    });
    if (_titleError != null || _scheduleError != null) return;

    final target = switch (_type) {
      RitualType.check => 1.0,
      RitualType.quantity => double.tryParse(_targetController.text) ?? 1,
      RitualType.timer => double.tryParse(_targetController.text) ?? 20,
    };

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final ritualService = ref.read(ritualServiceProvider);

    try {
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          title: title,
          emoji: _emoji,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          clearDescription: _descriptionController.text.trim().isEmpty,
          type: _type,
          target: target,
          unit: _type == RitualType.quantity ? _unitController.text.trim() : '',
          scheduleType: _scheduleType,
          scheduleDays: _scheduleDays,
          timesPerWeek: _timesPerWeek,
          intervalDays: _intervalDays,
          reminderTime: _reminderTime,
          reminderOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
          clearReminder: _reminderTime == null,
          requirePhoto: _requirePhoto,
          colorValue: _colorValue,
        );
        await ritualService.updateRitual(widget.groupId, updated);
      } else {
        final uid = ref.read(currentUidProvider) ?? '';
        final ritual = Ritual(
          id: '',
          title: title,
          emoji: _emoji,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          type: _type,
          target: target,
          unit: _type == RitualType.quantity ? _unitController.text.trim() : '',
          scheduleType: _scheduleType,
          scheduleDays: _scheduleDays,
          timesPerWeek: _timesPerWeek,
          intervalDays: _intervalDays,
          reminderTime: _reminderTime,
          reminderOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
          requirePhoto: _requirePhoto,
          colorValue: _colorValue,
          createdBy: uid,
          createdAt: DateTime.now(),
        );
        await ritualService.createRitual(widget.groupId, ritual);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      expand: false,
      builder: (sheetContext, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                _isEditing ? 'Edit ritual' : 'New ritual',
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _pickEmoji,
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: colorScheme.secondaryContainer,
                      child: Text(_emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      autofocus: !_isEditing,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        errorText: _titleError,
                      ),
                      onChanged: (_) {
                        if (_titleError != null) {
                          setState(() => _titleError = null);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Text('Type', style: textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<RitualType>(
                segments: const [
                  ButtonSegment(
                    value: RitualType.check,
                    label: Text('Check'),
                    icon: Icon(LucideIcons.check),
                  ),
                  ButtonSegment(
                    value: RitualType.quantity,
                    label: Text('Count'),
                    icon: Icon(LucideIcons.hash),
                  ),
                  ButtonSegment(
                    value: RitualType.timer,
                    label: Text('Timer'),
                    icon: Icon(LucideIcons.timer),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) {
                  setState(() => _type = selection.first);
                },
              ),
              if (_type == RitualType.quantity) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _targetController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Target'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          hintText: 'glasses, pages',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (_type == RitualType.timer) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target minutes'),
                ),
              ],
              const SizedBox(height: 24),
              Text('Schedule', style: textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<ScheduleType>(
                segments: const [
                  ButtonSegment(
                    value: ScheduleType.weekdays,
                    label: Text('Days'),
                    icon: Icon(LucideIcons.calendarDays),
                  ),
                  ButtonSegment(
                    value: ScheduleType.timesPerWeek,
                    label: Text('Weekly'),
                    icon: Icon(LucideIcons.repeat),
                  ),
                  ButtonSegment(
                    value: ScheduleType.everyNDays,
                    label: Text('Interval'),
                    icon: Icon(LucideIcons.calendarClock),
                  ),
                ],
                selected: {_scheduleType},
                onSelectionChanged: (selection) {
                  setState(() {
                    _scheduleType = selection.first;
                    _scheduleError = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_scheduleType == ScheduleType.weekdays) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (index) {
                    final day = index + 1;
                    return FilterChip(
                      label: Text(_weekdayLabels[index]),
                      selected: _scheduleDays.contains(day),
                      onSelected: (_) => _toggleWeekday(day),
                    );
                  }),
                ),
                if (_scheduleError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _scheduleError!,
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.error),
                  ),
                ],
              ] else if (_scheduleType == ScheduleType.timesPerWeek) ...[
                Text('$_timesPerWeek times per week', style: textTheme.bodyMedium),
                Slider(
                  value: _timesPerWeek.toDouble(),
                  min: 1,
                  max: 7,
                  divisions: 6,
                  label: '$_timesPerWeek',
                  onChanged: (value) {
                    setState(() => _timesPerWeek = value.round());
                  },
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _intervalDays == 1
                            ? 'Every day'
                            : 'Every $_intervalDays days',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.minus),
                      onPressed: _intervalDays > 1
                          ? () => setState(() => _intervalDays--)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.plus),
                      onPressed: _intervalDays < 30
                          ? () => setState(() => _intervalDays++)
                          : null,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Text('Reminder', style: textTheme.labelLarge),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(Corners.control),
                onTap: _pickReminder,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Corners.control),
                    border: Border.all(color: colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.bell, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_reminderTime ?? 'No reminder'),
                      ),
                      if (_reminderTime != null)
                        IconButton(
                          icon: const Icon(LucideIcons.x),
                          onPressed: () => setState(() => _reminderTime = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Photo proof'),
                subtitle: Text(
                  _requirePhoto
                      ? 'A day only counts once you post a photo.'
                      : 'A tap is enough to mark this done.',
                ),
                secondary: const Icon(LucideIcons.camera),
                value: _requirePhoto,
                onChanged: (value) => setState(() => _requirePhoto = value),
              ),
              const SizedBox(height: 16),
              Text('Accent colour', style: textTheme.labelLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: kRitualColors.map((value) {
                  final selected = value == _colorValue;
                  return GestureDetector(
                    onTap: () => setState(() => _colorValue = value),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(value),
                        border: selected
                            ? Border.all(color: colorScheme.onSurface, width: 2)
                            : null,
                      ),
                      child: selected
                          ? const Icon(LucideIcons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              if (_isEditing) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _toggleArchive,
                        icon: Icon(
                          widget.existing!.archived
                              ? LucideIcons.archiveRestore
                              : LucideIcons.archive,
                        ),
                        label: Text(widget.existing!.archived ? 'Unarchive' : 'Archive'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _confirmDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(color: colorScheme.error),
                        ),
                        icon: const Icon(LucideIcons.trash2),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Save changes' : 'Create ritual'),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<double?> showLogAmountSheet(
  BuildContext context,
  Ritual ritual,
  dynamic currentProgress,
) {
  final double value = (currentProgress?.value as num?)?.toDouble() ?? 0;
  final double target = (currentProgress?.target as num?)?.toDouble() ?? ritual.target;
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Corners.sheet)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: _LogAmountSheet(ritual: ritual, value: value, target: target),
      );
    },
  );
}

class _LogAmountSheet extends StatefulWidget {
  const _LogAmountSheet({
    required this.ritual,
    required this.value,
    required this.target,
  });

  final Ritual ritual;
  final double value;
  final double target;

  @override
  State<_LogAmountSheet> createState() => _LogAmountSheetState();
}

class _LogAmountSheetState extends State<_LogAmountSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<double> get _quickAmounts {
    return widget.ritual.type == RitualType.timer
        ? const [5, 10, 15, 30, 60]
        : const [1, 2, 5];
  }

  void _submit(double amount) {
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final remaining = (widget.target - widget.value).clamp(0, double.infinity);
    final unitLabel = widget.ritual.type == RitualType.timer ? 'min' : widget.ritual.unit;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Log ${widget.ritual.title}', style: textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            unitLabel.isEmpty
                ? 'Remaining: ${_trim(remaining.toDouble())}'
                : 'Remaining: ${_trim(remaining.toDouble())} $unitLabel',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickAmounts.map((amount) {
              final label = widget.ritual.type == RitualType.timer
                  ? '+${_trim(amount)} min'
                  : '+${_trim(amount)}';
              return ActionChip(
                label: Text(label),
                onPressed: () => _submit(amount),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: unitLabel.isEmpty ? null : unitLabel,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(_controller.text);
              if (amount == null || amount <= 0) return;
              _submit(amount);
            },
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Log'),
          ),
        ],
      ),
    );
  }
}

String _trim(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}
