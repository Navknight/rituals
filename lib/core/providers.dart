import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
