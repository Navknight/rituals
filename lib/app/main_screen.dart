import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rituals/features/home/home_screen.dart';
import 'package:rituals/features/groups/group_tab.dart';
import 'package:rituals/features/groups/group_provider.dart';
import 'package:rituals/models/group.dart';
import 'package:rituals/services/notification_service.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key, required this.groupIds});
  final List<String> groupIds;

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentTab = 0;
  late String _selectedGroupId;
  final Map<String, Group> _groupCache = {};
  bool _loadingGroups = true;
  bool _showNotifBanner = false;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.groupIds.first;
    _loadGroups();
    if (kIsWeb) _checkNotificationPermission();
  }

  Future<void> _loadGroups() async {
    final service = ref.read(groupServiceProvider);
    for (final id in widget.groupIds) {
      final group = await service.getGroup(id);
      if (group != null) _groupCache[id] = group;
    }
    if (mounted) setState(() => _loadingGroups = false);
  }

  Future<void> _checkNotificationPermission() async {
    final needs = await NotificationService().needsWebPermissionPrompt();
    if (mounted) setState(() => _showNotifBanner = needs);
  }

  Future<void> _enableNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final granted = await NotificationService().requestWebPermission(uid);
    if (mounted) {
      setState(() => _showNotifBanner = false);
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications blocked. Enable them in browser settings.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(
        children: [
          // Notification permission banner (web/iOS PWA only)
          if (_showNotifBanner)
            MaterialBanner(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              content: const Text('Enable notifications to get alerts when your group shares photos.'),
              leading: Icon(Icons.notifications_outlined, color: theme.colorScheme.primary),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _showNotifBanner = false),
                  child: const Text('Not now'),
                ),
                FilledButton(
                  onPressed: _enableNotifications,
                  child: const Text('Enable'),
                ),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                // Rituals tab
                Column(
                  children: [
                    if (widget.groupIds.length > 1 && !_loadingGroups)
                      _GroupSwitcher(
                        groups: _groupCache,
                        selectedGroupId: _selectedGroupId,
                        onChanged: (id) => setState(() => _selectedGroupId = id),
                      ),
                    Expanded(
                      child: HomeScreen(
                        key: ValueKey(_selectedGroupId),
                        groupId: _selectedGroupId,
                      ),
                    ),
                  ],
                ),
                // Group tab
                Column(
                  children: [
                    if (widget.groupIds.length > 1 && !_loadingGroups)
                      _GroupSwitcher(
                        groups: _groupCache,
                        selectedGroupId: _selectedGroupId,
                        onChanged: (id) => setState(() => _selectedGroupId = id),
                      ),
                    Expanded(
                      child: GroupTab(
                        key: ValueKey('group_$_selectedGroupId'),
                        groupId: _selectedGroupId,
                        onGroupChanged: _loadGroups,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) => setState(() => _currentTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.self_improvement_outlined),
            selectedIcon: Icon(Icons.self_improvement),
            label: 'Rituals',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Group',
          ),
        ],
      ),
    );
  }
}

class _GroupSwitcher extends StatelessWidget {
  const _GroupSwitcher({
    required this.groups,
    required this.selectedGroupId,
    required this.onChanged,
  });

  final Map<String, Group> groups;
  final String selectedGroupId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Icon(Icons.group, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              value: selectedGroupId,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              style: theme.textTheme.titleMedium,
              items: groups.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value.name),
                );
              }).toList(),
              onChanged: (id) {
                if (id != null) onChanged(id);
              },
            ),
          ),
        ],
      ),
    );
  }
}
