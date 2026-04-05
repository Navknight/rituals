import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rituals/features/auth/auth_provider.dart';
import 'package:rituals/features/home/home_screen.dart';
import 'package:rituals/features/groups/group_tab.dart';
import 'package:rituals/features/groups/group_provider.dart';
import 'package:rituals/features/rituals/ritual_provider.dart';
import 'package:rituals/features/streaks/ritual_detail_screen.dart';
import 'package:rituals/models/group.dart';
import 'package:rituals/models/ritual.dart';
import 'package:rituals/services/notification_service.dart';
import 'package:rituals/services/restore_service.dart';

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
  StreamSubscription<RemoteMessage>? _fcmSub;

  // Create ritual dialog state
  final _titleController = TextEditingController();
  final _emojiController = TextEditingController();
  final _scheduleDays = <int>[];
  TimeOfDay? _reminderTime;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.groupIds.first;
    _loadGroups();
    _checkNotificationPermission();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) RestoreService().processPendingRequests(widget.groupIds);
    });
    _initNotificationHandlers();
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
            content: Text(
                'Notifications blocked. Enable them in browser settings.'),
          ),
        );
      }
    }
  }

  void _initNotificationHandlers() {
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleNotificationTap(message.data);
    });
    _fcmSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message.data);
    });
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final groupId = data['groupId'] as String?;
    final ritualId = data['ritualId'] as String?;
    if (groupId == null || !widget.groupIds.contains(groupId)) return;
    setState(() {
      _selectedGroupId = groupId;
      _currentTab = 0;
    });
    if (ritualId != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _navigateToRitual(groupId, ritualId);
      });
    }
  }

  Future<void> _navigateToRitual(String groupId, String ritualId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('rituals')
          .doc(ritualId)
          .get();
      if (!doc.exists || !mounted) return;
      final ritual = Ritual.fromMap(doc.data()!);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RitualDetailScreen(groupId: groupId, ritual: ritual),
      ));
    } catch (e) {
      debugPrint('[MainScreen] _navigateToRitual failed: $e');
    }
  }

  void _showGroupPicker() {
    if (widget.groupIds.length <= 1) return;
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Switch Group', style: theme.textTheme.titleMedium),
          ),
          ..._groupCache.entries.map((entry) {
            final selected = entry.key == _selectedGroupId;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primaryContainer,
                child: Text(
                  entry.value.name[0].toUpperCase(),
                  style: TextStyle(
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(entry.value.name),
              trailing: selected
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              onTap: () {
                setState(() => _selectedGroupId = entry.key);
                Navigator.pop(ctx);
              },
            );
          }),
          SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  void _showCreateRitualDialog() {
    _titleController.clear();
    _emojiController.clear();
    _scheduleDays.clear();
    _reminderTime = null;

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
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Ritual Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emojiController,
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
                    const days = [
                      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
                    ];
                    return FilterChip(
                      label: Text(days[index]),
                      selected: _scheduleDays.contains(index + 1),
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            _scheduleDays.add(index + 1);
                          } else {
                            _scheduleDays.remove(index + 1);
                          }
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Daily Reminder',
                      style: Theme.of(context).textTheme.labelLarge),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _reminderTime ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => _reminderTime = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.alarm_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _reminderTime != null
                              ? _reminderTime!.format(context)
                              : 'No reminder',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        if (_reminderTime != null)
                          GestureDetector(
                            onTap: () =>
                                setDialogState(() => _reminderTime = null),
                            child: const Icon(Icons.close, size: 16),
                          ),
                      ],
                    ),
                  ),
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
                if (_titleController.text.trim().isEmpty) return;
                if (_scheduleDays.isEmpty) return;
                String? reminderTimeStr;
                if (_reminderTime != null) {
                  final h = _reminderTime!.hour.toString().padLeft(2, '0');
                  final m = _reminderTime!.minute.toString().padLeft(2, '0');
                  reminderTimeStr = '$h:$m';
                }
                final ritual = Ritual(
                  id: '',
                  title: _titleController.text.trim(),
                  emoji: _emojiController.text.trim().isEmpty
                      ? '🎯'
                      : _emojiController.text.trim(),
                  scheduleDays: List<int>.from(_scheduleDays),
                  reminderTime: reminderTimeStr,
                  createdBy: user.uid,
                  createdAt: DateTime.now(),
                );
                await ref
                    .read(ritualServiceProvider)
                    .createRitual(_selectedGroupId, ritual);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    _titleController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final groupName = _loadingGroups
        ? ''
        : (_groupCache[_selectedGroupId]?.name ?? '');

    final tabs = [
      HomeScreen(key: ValueKey(_selectedGroupId), groupId: _selectedGroupId),
      GroupTab(
        key: ValueKey('group_$_selectedGroupId'),
        groupId: _selectedGroupId,
        onGroupChanged: _loadGroups,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: GestureDetector(
          onTap: widget.groupIds.length > 1 ? _showGroupPicker : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(groupName),
              if (widget.groupIds.length > 1) ...[
                const SizedBox(width: 2),
                Icon(Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (_showNotifBanner)
            MaterialBanner(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              content: const Text(
                  'Enable notifications to get alerts when your group shares photos.'),
              leading: Icon(Icons.notifications_outlined,
                  color: theme.colorScheme.primary),
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
            child: BottomBar(
              hideOnScroll: false,
              showIcon: false,
              offset: 12,
              width: 220,
              borderRadius: BorderRadius.circular(32),
              barDecoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              body: (context, _) => IndexedStack(
                index: _currentTab,
                children: tabs,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Add ritual button
                    IconButton(
                      icon: Icon(Icons.add,
                          color: theme.colorScheme.primary, size: 26),
                      onPressed: _showCreateRitualDialog,
                      tooltip: 'New Ritual',
                      visualDensity: VisualDensity.compact,
                    ),
                    // Subtle divider
                    Container(
                      width: 1,
                      height: 22,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    _NavItem(
                      icon: Icons.self_improvement_outlined,
                      selectedIcon: Icons.self_improvement,
                      label: 'Rituals',
                      selected: _currentTab == 0,
                      onTap: () => setState(() => _currentTab = 0),
                    ),
                    _NavItem(
                      icon: Icons.group_outlined,
                      selectedIcon: Icons.group,
                      label: 'Group',
                      selected: _currentTab == 1,
                      onTap: () => setState(() => _currentTab = 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: 22,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
