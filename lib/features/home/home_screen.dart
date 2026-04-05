import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rituals/features/auth/auth_provider.dart';
import 'package:rituals/features/streaks/ritual_detail_screen.dart';
import 'package:rituals/features/rituals/ritual_provider.dart';
import 'package:rituals/models/ritual.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final titleController = TextEditingController();
  final emojiController = TextEditingController();
  final scheduleDays = List<int>.empty(growable: true);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ritualsAsync = ref.watch(ritualsProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rituals'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRitualDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Ritual'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ritualsAsync.when(
              data: (rituals) {
                final todayRituals = rituals
                    .where(
                        (r) => r.isScheduledForDay(DateTime.now().weekday))
                    .toList();
                final otherRituals = rituals
                    .where(
                        (r) => !r.isScheduledForDay(DateTime.now().weekday))
                    .toList();
                return ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  children: [
                    if (todayRituals.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          "Today",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...todayRituals.map(
                        (ritual) => Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: Text(ritual.emoji,
                                style: const TextStyle(fontSize: 28)),
                            title: Text(ritual.title,
                                style: theme.textTheme.titleMedium),
                            trailing: Icon(Icons.chevron_right,
                                color: theme.colorScheme.onSurfaceVariant),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RitualDetailScreen(
                                    groupId: widget.groupId,
                                    ritual: ritual,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    if (otherRituals.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Text(
                          'Upcoming',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      ...otherRituals.map(
                        (ritual) => Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: Text(ritual.emoji,
                                style: const TextStyle(fontSize: 28)),
                            title: Text(ritual.title),
                            subtitle: Text(
                              _formatDays(ritual.scheduleDays),
                              style: theme.textTheme.bodySmall,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RitualDetailScreen(
                                    groupId: widget.groupId,
                                    ritual: ritual,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    if (rituals.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          children: [
                            Icon(Icons.self_improvement,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text(
                              'No rituals yet',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the button below to create your first ritual',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDays(List<int> days) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = List<int>.from(days)..sort();
    return sorted.map((d) => names[d - 1]).join(', ');
  }

  void _showCreateRitualDialog(BuildContext context) {
    titleController.clear();
    emojiController.clear();
    scheduleDays.clear();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Ritual'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Ritual Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emojiController,
                  decoration: const InputDecoration(
                    labelText: 'Emoji',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Schedule',
                      style: Theme.of(context).textTheme.labelLarge),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(7, (index) {
                    final day = [
                      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
                    ][index];
                    return FilterChip(
                      label: Text(day),
                      selected: scheduleDays.contains(index + 1),
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            scheduleDays.add(index + 1);
                          } else {
                            scheduleDays.remove(index + 1);
                          }
                        });
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final user = ref.read(authStateProvider).value;
                if (user == null) return;
                if (titleController.text.trim().isEmpty) return;
                if (scheduleDays.isEmpty) return;
                final ritual = Ritual(
                  id: '',
                  title: titleController.text.trim(),
                  emoji: emojiController.text.trim().isEmpty
                      ? '🎯'
                      : emojiController.text.trim(),
                  scheduleDays: scheduleDays,
                  createdBy: user.uid,
                  createdAt: DateTime.now(),
                );
                await ref
                    .read(ritualServiceProvider)
                    .createRitual(widget.groupId, ritual);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
