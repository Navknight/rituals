import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:rituals/models/ritual.dart';
import 'package:rituals/models/ritual_entry.dart';
import 'package:rituals/services/streak_service.dart';
import 'package:rituals/features/camera/camera_screen.dart';
import 'package:rituals/services/restore_service.dart';
import 'package:rituals/shared/download.dart';

class RitualDetailScreen extends ConsumerStatefulWidget {
  const RitualDetailScreen({
    super.key,
    required this.groupId,
    required this.ritual,
  });

  final String groupId;
  final Ritual ritual;

  @override
  ConsumerState<RitualDetailScreen> createState() => _RitualDetailScreenState();
}

class _RitualDetailScreenState extends ConsumerState<RitualDetailScreen> {
  final _streakService = StreakService();
  final _firestore = FirebaseFirestore.instance;
  StreakInfo? _streakInfo;
  List<RitualEntry> _entries = [];
  Map<String, String> _memberNames = {};
  List<String> _allMemberIds = [];
  bool _loading = true;
  String? _error;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final streakInfo = await _streakService.calculateStreak(
        groupId: widget.groupId,
        ritualId: widget.ritual.id,
        scheduledDays: widget.ritual.scheduleDays,
      );

      final snapshot = await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('rituals')
          .doc(widget.ritual.id)
          .collection('entries')
          .orderBy('createdAt', descending: true)
          .get();

      final entries =
          snapshot.docs.map((doc) => RitualEntry.fromMap(doc.data())).toList();

      // Load all group members (not just those who posted)
      final groupDoc =
          await _firestore.collection('groups').doc(widget.groupId).get();
      final allMemberIds =
          List<String>.from(groupDoc.data()?['memberIds'] ?? []);

      final names = <String, String>{};
      for (final uid in allMemberIds) {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        names[uid] = userDoc.data()?['displayName'] ?? 'Unknown';
      }

      if (mounted) {
        setState(() {
          _streakInfo = streakInfo;
          _entries = entries;
          _memberNames = names;
          _allMemberIds = allMemberIds;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _sendNudge(String toUid) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    try {
      await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('rituals')
          .doc(widget.ritual.id)
          .collection('nudges')
          .add({
        'fromUid': me.uid,
        'toUid': toUid,
        'ritualTitle': '${widget.ritual.emoji} ${widget.ritual.title}',
        'sentAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nudged ${_memberNames[toUid] ?? 'them'}! 👀'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send nudge: $e')),
        );
      }
    }
  }

  static Future<void> _savePhoto(
      BuildContext context, RitualEntry entry) async {
    try {
      if (kIsWeb) {
        await downloadImageWeb(entry.photoUrl, 'ritual_photo.jpg');
      } else {
        if (entry.localPath != null && File(entry.localPath!).existsSync()) {
          await Gal.putImage(entry.localPath!);
        } else {
          final response = await http.get(Uri.parse(entry.photoUrl));
          await Gal.putImageBytes(response.bodyBytes);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved to gallery')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ritual = widget.ritual;

    return Scaffold(
      appBar: AppBar(
        title: Text('${ritual.emoji} ${ritual.title}'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () => _openCamera(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              const Text('Failed to load data',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(_error!, textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: () {
                                  setState(() { _loading = true; _error = null; });
                                  _loadData();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 80),
                      children: [
                        // Streak hero
                        _StreakHero(streak: _streakInfo?.currentStreak ?? 0),

                        // Stat cards
                        _StatCards(streakInfo: _streakInfo),

                        const SizedBox(height: 8),

                        // Nudge members who haven't posted today
                        _NudgeSection(
                          allMemberIds: _allMemberIds,
                          memberNames: _memberNames,
                          entries: _entries,
                          onNudge: _sendNudge,
                        ),

                        const SizedBox(height: 8),

                        // Recent photos from all members
                        _RecentPhotosSection(
                          groupId: widget.groupId,
                          ritualId: widget.ritual.id,
                          entries: _entries,
                          memberNames: _memberNames,
                          onSave: (entry) => _savePhoto(context, entry),
                        ),

                        const SizedBox(height: 8),

                        // Month calendar
                        _MonthCalendar(
                          visibleMonth: _visibleMonth,
                          scheduledDays: ritual.scheduleDays,
                          streakInfo: _streakInfo,
                          onPreviousMonth: () {
                            setState(() {
                              _visibleMonth = DateTime(
                                _visibleMonth.year,
                                _visibleMonth.month - 1,
                              );
                            });
                          },
                          onNextMonth: () {
                            final now = DateTime.now();
                            final next = DateTime(
                              _visibleMonth.year,
                              _visibleMonth.month + 1,
                            );
                            if (!next.isAfter(DateTime(now.year, now.month))) {
                              setState(() => _visibleMonth = next);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _openCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          groupId: widget.groupId,
          ritualId: widget.ritual.id,
        ),
      ),
    ).then((_) => _loadData());
  }
}

// --- Streak Hero ---

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                streak.toString(),
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.bolt, size: 32, color: Color(0xFFFFBC03)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            streak == 1 ? 'day streak' : 'day streak',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Stat Cards ---

class _StatCards extends StatelessWidget {
  const _StatCards({required this.streakInfo});
  final StreakInfo? streakInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Longest this month',
              value: streakInfo?.longestStreakThisMonth ?? 0,
              theme: theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Longest overall',
              value: streakInfo?.longestStreakOverall ?? 0,
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.theme,
  });
  final String label;
  final int value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.bolt, size: 20, color: Color(0xFFFFBC03)),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Recent Photos Section (grouped by day, stacked thumbnails) ---

class _RecentPhotosSection extends StatelessWidget {
  const _RecentPhotosSection({
    required this.groupId,
    required this.ritualId,
    required this.entries,
    required this.memberNames,
    required this.onSave,
  });

  final String groupId;
  final String ritualId;
  final List<RitualEntry> entries;
  final Map<String, String> memberNames;
  final void Function(RitualEntry) onSave;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    // Group entries by date
    final grouped = <String, List<RitualEntry>>{};
    for (final entry in entries) {
      final key =
          '${entry.createdAt.year}-${entry.createdAt.month.toString().padLeft(2, '0')}-${entry.createdAt.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Photos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sortedDays.length > 7 ? 7 : sortedDays.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final dayKey = sortedDays[index];
                final dayEntries = grouped[dayKey]!;
                final firstEntry = dayEntries.first;
                return _DayStack(
                  entries: dayEntries,
                  memberNames: memberNames,
                  date: firstEntry.createdAt,
                  onTap: () => _showDayPhotos(context, dayEntries, onSave, groupId, ritualId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDayPhotos(BuildContext context, List<RitualEntry> dayEntries,
      void Function(RitualEntry) onSave, String groupId, String ritualId) {
    final theme = Theme.of(context);
    final date = dayEntries.first.createdAt;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final title = '${weekdays[date.weekday - 1]}, ${date.day}/${date.month}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: dayEntries.length,
                itemBuilder: (context, index) {
                  final entry = dayEntries[index];
                  final name = memberNames[entry.userId] ?? 'Unknown';
                  return _ExpandedPhotoCard(
                    groupId: groupId,
                    ritualId: ritualId,
                    entry: entry,
                    posterName: name,
                    onSave: () => onSave(entry),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Stacked day thumbnail — shows top photo with count badge, slightly rotated stack effect
class _DayStack extends StatelessWidget {
  const _DayStack({
    required this.entries,
    required this.memberNames,
    required this.date,
    required this.onTap,
  });

  final List<RitualEntry> entries;
  final Map<String, String> memberNames;
  final DateTime date;
  final VoidCallback onTap;

  static const _tileWidth = 80.0;
  static const _tileHeight = 100.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const weekdays = ['M', 'Tu', 'W', 'Th', 'F', 'Sa', 'Su'];
    final label = '${weekdays[date.weekday - 1]}\n${date.day}';

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _tileWidth + 12, // Extra space for rotation overflow
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _tileWidth + 12,
              height: _tileHeight + 8,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Back cards (stagger effect) if multiple photos
                  if (entries.length > 2)
                    Positioned(
                      child: Transform.rotate(
                        angle: -0.08,
                        child: _photoFrame(entries.length > 2 ? entries[2] : entries.last, fade: true),
                      ),
                    ),
                  if (entries.length > 1)
                    Positioned(
                      child: Transform.rotate(
                        angle: 0.05,
                        child: _photoFrame(entries[1], fade: true),
                      ),
                    ),
                  // Top card
                  _photoFrame(entries.first, fade: false),
                  // Count badge
                  if (entries.length > 1)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1DB954),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          entries.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoFrame(RitualEntry entry, {required bool fade}) {
    return Opacity(
      opacity: fade ? 0.5 : 1.0,
      child: Container(
        width: _tileWidth,
        height: _tileHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30000000),
              blurRadius: 5,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildEntryImage(entry),
        ),
      ),
    );
  }

  Widget _buildEntryImage(RitualEntry entry) {
    if (!kIsWeb && entry.localPath != null && entry.localPath!.isNotEmpty) {
      final file = File(entry.localPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return Image.network(
      entry.photoUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.photo, size: 24, color: Colors.grey),
      ),
    );
  }
}

// Full photo card shown in the bottom sheet popup
class _ExpandedPhotoCard extends StatefulWidget {
  const _ExpandedPhotoCard({
    required this.groupId,
    required this.ritualId,
    required this.entry,
    required this.posterName,
    required this.onSave,
  });

  final String groupId;
  final String ritualId;
  final RitualEntry entry;
  final String posterName;
  final VoidCallback onSave;

  @override
  State<_ExpandedPhotoCard> createState() => _ExpandedPhotoCardState();
}

class _ExpandedPhotoCardState extends State<_ExpandedPhotoCard> {
  late String _currentUrl;
  bool _restoreRequested = false;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _entryStream;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.entry.photoUrl;
    _entryStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('rituals')
        .doc(widget.ritualId)
        .collection('entries')
        .doc(widget.entry.id)
        .snapshots();
  }

  void _onImageError() {
    if (_restoreRequested) return;
    setState(() => _restoreRequested = true);
    RestoreService().requestRestore(
      groupId: widget.groupId,
      ritualId: widget.ritualId,
      entryId: widget.entry.id,
      originalUrl: _currentUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _entryStream,
      builder: (context, snapshot) {
        // Update URL if a peer restored the photo
        final newUrl = snapshot.data?.data()?['photoUrl'] as String?;
        if (newUrl != null && newUrl != _currentUrl) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() { _currentUrl = newUrl; _restoreRequested = false; });
          });
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: _buildImage(),
                ),
              ),
              // Info
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        widget.posterName.isNotEmpty
                            ? widget.posterName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.posterName,
                              style: theme.textTheme.bodyMedium),
                          if (widget.entry.caption != null &&
                              widget.entry.caption!.isNotEmpty)
                            Text(
                              widget.entry.caption!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      _formatTime(widget.entry.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.download_outlined, size: 20),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Save photo',
                      onPressed: widget.onSave,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImage() {
    if (!kIsWeb &&
        widget.entry.localPath != null &&
        widget.entry.localPath!.isNotEmpty) {
      final file = File(widget.entry.localPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    if (_restoreRequested) {
      return Container(
        color: Colors.grey[100],
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Restoring photo…',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }
    return Image.network(
      _currentUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        _onImageError();
        return Container(
          color: Colors.grey[200],
          child: const Icon(Icons.photo, size: 48, color: Colors.grey),
        );
      },
    );
  }

  String _formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// --- Nudge Section ---

class _NudgeSection extends StatefulWidget {
  const _NudgeSection({
    required this.allMemberIds,
    required this.memberNames,
    required this.entries,
    required this.onNudge,
  });

  final List<String> allMemberIds;
  final Map<String, String> memberNames;
  final List<RitualEntry> entries;
  final Future<void> Function(String uid) onNudge;

  @override
  State<_NudgeSection> createState() => _NudgeSectionState();
}

class _NudgeSectionState extends State<_NudgeSection> {
  final Set<String> _nudgedToday = {};

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final todayPosters = widget.entries
        .where((e) =>
            e.createdAt.year == now.year &&
            e.createdAt.month == now.month &&
            e.createdAt.day == now.day)
        .map((e) => e.userId)
        .toSet();

    final me = FirebaseAuth.instance.currentUser?.uid;
    final missing = widget.allMemberIds
        .where((uid) => uid != me && !todayPosters.contains(uid))
        .toList();

    if (missing.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Waiting on…', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...missing.map((uid) {
            final name = widget.memberNames[uid] ?? 'Unknown';
            final nudged = _nudgedToday.contains(uid);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(name, style: theme.textTheme.bodyMedium),
                  ),
                  TextButton.icon(
                    onPressed: nudged
                        ? null
                        : () async {
                            await widget.onNudge(uid);
                            if (mounted) {
                              setState(() => _nudgedToday.add(uid));
                            }
                          },
                    icon: Icon(nudged ? Icons.check : Icons.notifications_outlined,
                        size: 16),
                    label: Text(nudged ? 'Nudged' : 'Nudge'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// --- Month Calendar ---

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.visibleMonth,
    required this.scheduledDays,
    required this.streakInfo,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime visibleMonth;
  final List<int> scheduledDays;
  final StreakInfo? streakInfo;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isCurrentMonth =
        visibleMonth.year == now.year && visibleMonth.month == now.month;

    // Month name
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final title = '${monthNames[visibleMonth.month - 1]} ${visibleMonth.year}';

    // Calculate grid
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday; // 1=Mon

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Header with navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: onPreviousMonth,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: isCurrentMonth ? null : onNextMonth,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Weekday headers
          Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Day grid
          ...List.generate(_weekCount(startWeekday, daysInMonth), (weekIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: List.generate(7, (dayIndex) {
                  final cellIndex = weekIndex * 7 + dayIndex;
                  final dayNum = cellIndex - (startWeekday - 1) + 1;

                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 40));
                  }

                  final date = DateTime(
                    visibleMonth.year,
                    visibleMonth.month,
                    dayNum,
                  );
                  final isToday = date.year == now.year &&
                      date.month == now.month &&
                      date.day == now.day;
                  final isFuture = date.isAfter(now);
                  final isScheduled = scheduledDays.contains(date.weekday);
                  final isCompleted =
                      streakInfo?.hasCompleted(date) ?? false;

                  return Expanded(
                    child: _DayCell(
                      day: dayNum,
                      isToday: isToday,
                      isFuture: isFuture,
                      isScheduled: isScheduled,
                      isCompleted: isCompleted,
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  int _weekCount(int startWeekday, int daysInMonth) {
    return ((startWeekday - 1 + daysInMonth) / 7).ceil();
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isFuture,
    required this.isScheduled,
    required this.isCompleted,
  });

  final int day;
  final bool isToday;
  final bool isFuture;
  final bool isScheduled;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isCompleted) {
      // Green circle with lightning bolt
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1DB954),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.bolt, size: 20, color: Colors.white),
        ),
      );
    }

    if (isToday && isScheduled) {
      // Today's scheduled but not completed — outlined with bolt
      return Container(
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF1DB954), width: 2),
        ),
        child: Center(
          child: Icon(
            Icons.bolt,
            size: 20,
            color: const Color(0xFF1DB954).withValues(alpha: 0.5),
          ),
        ),
      );
    }

    // Regular day number
    return SizedBox(
      height: 40,
      child: Center(
        child: Text(
          day.toString(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isFuture
                ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)
                : isScheduled
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            fontWeight: isScheduled ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
