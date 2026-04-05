import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rituals/features/streaks/ritual_detail_screen.dart';
import 'package:rituals/features/rituals/ritual_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ritualsAsync = ref.watch(ritualsProvider(groupId));

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ritualsAsync.when(
            data: (rituals) {
              final now = DateTime.now();
              final todayRituals = rituals
                  .where((r) => r.isScheduledForDay(now.weekday))
                  .toList();
              final otherRituals = rituals
                  .where((r) => !r.isScheduledForDay(now.weekday))
                  .toList();
              return ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 100),
                children: [
                  if (todayRituals.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'Today',
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
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RitualDetailScreen(
                                groupId: groupId,
                                ritual: ritual,
                              ),
                            ),
                          ),
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
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RitualDetailScreen(
                                groupId: groupId,
                                ritual: ritual,
                              ),
                            ),
                          ),
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
                          Text('No rituals yet',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to create your first ritual',
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
            error: (e, _) => Center(child: Text('Error: $e')),
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
}
