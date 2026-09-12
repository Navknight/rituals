import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:rituals/core/providers.dart';
import 'package:rituals/features/camera/pending_capture.dart';
import 'package:rituals/features/camera/preview_screen.dart';
import 'package:rituals/features/home/home_screen.dart';
import 'package:rituals/features/rituals/ritual_editor.dart';
import 'package:rituals/features/settings/settings_screen.dart';
import 'package:rituals/features/spaces/spaces_screen.dart';
import 'package:rituals/features/stats/overview_screen.dart';
import 'package:rituals/features/streaks/ritual_detail_screen.dart';
import 'package:rituals/models/ritual.dart';
import 'package:rituals/services/notification_service.dart';
import 'package:rituals/services/restore_service.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _tab = 0;
  bool _notifBanner = false;
  StreamSubscription<RemoteMessage>? _fcmSub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      ref.read(ritualServiceProvider).migrateLegacyEntries(widget.groupId);
    }
  }

  Future<void> _bootstrap() async {
    await _resumeLostCapture();

    unawaited(ref.read(ritualServiceProvider).migrateLegacyEntries(widget.groupId));

    final needs = await NotificationService().needsWebPermissionPrompt();
    if (mounted) setState(() => _notifBanner = needs);

    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) _openFromNotification(m.data);
    });
    _fcmSub = FirebaseMessaging.onMessageOpenedApp
        .listen((m) => _openFromNotification(m.data));

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) RestoreService().processPendingRequests([widget.groupId]);
    });
  }

  /// Picks up a photo taken just before Android killed the app, which would
  /// otherwise be dropped and leave the user back on Today wondering what
  /// happened to it.
  Future<void> _resumeLostCapture() async {
    final lost = await PendingCapture.claim();
    if (lost == null || !mounted || !context.mounted) return;

    final (pending, path) = lost;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PreviewScreen(
          photoPath: path,
          groupId: pending.groupId,
          ritualId: pending.ritualId,
          completionValue: pending.completionValue,
        ),
      ),
    );
  }

  Future<void> _openFromNotification(Map<String, dynamic> data) async {
    final groupId = data['groupId'] as String?;
    final ritualId = data['ritualId'] as String?;
    if (groupId == null || ritualId == null) return;

    ref.read(activeSpaceProvider.notifier).select(groupId);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('rituals')
          .doc(ritualId)
          .get();
      if (!doc.exists || !mounted) return;
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RitualDetailScreen(
            groupId: groupId,
            ritual: Ritual.fromMap(doc.data()!),
          ),
        ),
      );
    } catch (_) {
      // A notification for a ritual that has since been deleted.
    }
  }

  Future<void> _enableNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    var granted = false;
    try {
      granted = await NotificationService().requestWebPermission(uid);
    } catch (e) {
      debugPrint('[MainScreen] notification permission failed: $e');
    }
    if (!mounted) return;
    // Dismiss regardless: the banner must never outlive the prompt.
    setState(() => _notifBanner = false);
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifications are blocked in your browser settings.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = ref.watch(groupProvider(widget.groupId)).value;
    final profile = ref.watch(profileProvider).value;
    final spaceCount = profile?.groupIds.length ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SpacesScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (group?.isPersonal == false)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      LucideIcons.users,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                Flexible(
                  child: Text(
                    group?.name ?? 'Rituals',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (spaceCount > 1)
                  Icon(
                    LucideIcons.chevronDown,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () =>
                  showRitualEditor(context, ref, groupId: widget.groupId),
              tooltip: 'New ritual',
              child: const Icon(LucideIcons.plus),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.listChecks),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.chartNoAxesColumn),
            label: 'Progress',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_notifBanner)
              MaterialBanner(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                leading: Icon(LucideIcons.bell,
                    color: theme.colorScheme.primary),
                content: const Text(
                  'Turn on notifications to get your reminders.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _notifBanner = false),
                    child: const Text('Not now'),
                  ),
                  FilledButton(
                    onPressed: _enableNotifications,
                    child: const Text('Enable'),
                  ),
                ],
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      HomeScreen(
                        key: ValueKey('home_${widget.groupId}'),
                        groupId: widget.groupId,
                      ),
                      OverviewScreen(
                        key: ValueKey('overview_${widget.groupId}'),
                        groupId: widget.groupId,
                      ),
                    ],
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
