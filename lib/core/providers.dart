import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rituals/features/commentary/commentary.dart';
import 'package:rituals/models/group.dart';
import 'package:rituals/models/ritual.dart';
import 'package:rituals/models/ritual_entry.dart';
import 'package:rituals/models/user_profiles.dart';
import 'package:rituals/services/group_service.dart';
import 'package:rituals/services/ritual_service.dart';
import 'package:rituals/services/streak_service.dart';
import 'package:rituals/services/user_service.dart';

final groupServiceProvider = Provider<GroupService>((ref) => GroupService());
final ritualServiceProvider = Provider<RitualService>((ref) => RitualService());
final streakServiceProvider = Provider<StreakService>((ref) => StreakService());
final userServiceProvider = Provider<UserService>(
  (ref) => UserService(groupService: ref.watch(groupServiceProvider)),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.uid,
);

/// The signed-in user's profile, kept live so a newly joined space shows up
/// without a reload.
final profileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userServiceProvider).streamProfile(uid);
});

/// The space currently being viewed. Defaults to the personal space.
class ActiveSpaceController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String groupId) => state = groupId;

  /// Falls back to the personal space when the current selection is gone.
  String? resolve(UserProfile profile) {
    final current = state;
    if (current != null && profile.groupIds.contains(current)) return current;
    return profile.personalGroupId ??
        (profile.groupIds.isEmpty ? null : profile.groupIds.first);
  }
}

final activeSpaceProvider =
    NotifierProvider<ActiveSpaceController, String?>(ActiveSpaceController.new);

/// An invite code that arrived through a `/join/<code>` link and has not been
/// redeemed yet. It survives the sign in screen, so a signed out tap still
/// lands in the space once the account exists. `_SpaceGate` clears it.
class PendingInviteController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? code) => state = code;
}

final pendingInviteProvider =
    NotifierProvider<PendingInviteController, String?>(
  PendingInviteController.new,
);

/// The space to show: the current selection when it is still valid, otherwise
/// the personal space.
///
/// This has to watch the selection rather than the controller. Watching
/// `activeSpaceProvider.notifier` returns the same instance forever, so
/// picking a different space changed the state without rebuilding anything.
final resolvedSpaceProvider = Provider<String?>((ref) {
  final profile = ref.watch(profileProvider).value;
  if (profile == null) return null;

  final selected = ref.watch(activeSpaceProvider);
  if (selected != null && profile.groupIds.contains(selected)) return selected;

  return profile.personalGroupId ??
      (profile.groupIds.isEmpty ? null : profile.groupIds.first);
});

final groupProvider = StreamProvider.family<Group?, String>(
  (ref, groupId) => ref.watch(groupServiceProvider).watchGroup(groupId),
);

final ritualsProvider = StreamProvider.family<List<Ritual>, String>(
  (ref, groupId) => ref.watch(ritualServiceProvider).watchRituals(groupId),
);

/// Today's logs for a space, keyed by ritual id.
final todayEntriesProvider =
    StreamProvider.family<Map<String, List<RitualEntry>>, String>(
  (ref, groupId) => ref
      .watch(ritualServiceProvider)
      .watchDay(groupId: groupId, day: DateTime.now()),
);

class RitualRef {
  final String groupId;
  final String ritualId;

  const RitualRef(this.groupId, this.ritualId);

  @override
  bool operator ==(Object other) =>
      other is RitualRef &&
      other.groupId == groupId &&
      other.ritualId == ritualId;

  @override
  int get hashCode => Object.hash(groupId, ritualId);
}

/// Every log in a space, keyed by ritual id.
final spaceEntriesProvider =
    StreamProvider.family<Map<String, List<RitualEntry>>, String>((ref, groupId) {
  return ref.watch(ritualServiceProvider).watchAllEntries(groupId).map((entries) {
    final byRitual = <String, List<RitualEntry>>{};
    for (final entry in entries) {
      byRitual.putIfAbsent(entry.ritualId, () => []).add(entry);
    }
    return byRitual;
  });
});

final ritualEntriesProvider =
    StreamProvider.family<List<RitualEntry>, RitualRef>(
  (ref, key) => ref
      .watch(ritualServiceProvider)
      .watchRitualEntries(key.groupId, key.ritualId),
);

final memberProfilesProvider =
    FutureProvider.family<Map<String, UserProfile>, String>((ref, groupId) async {
  final group = await ref.watch(groupProvider(groupId).future);
  if (group == null) return {};
  return ref.watch(userServiceProvider).getProfiles(group.memberIds);
});

/// Picks the app's commentary lines. Kept alive so the same joke does not
/// repeat across rebuilds.
final commentaryProvider = Provider<Commentary>((ref) => Commentary());
