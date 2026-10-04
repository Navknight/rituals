import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:rituals/models/user_profiles.dart';
import 'package:rituals/services/group_service.dart';

class UserService {
  UserService({GroupService? groupService})
    : _groups = groupService ?? GroupService();

  final firestore = FirebaseFirestore.instance;
  final GroupService _groups;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      firestore.collection('users').doc(uid);

  /// Loads the profile, creating it on first sign-in.
  ///
  /// Every account is given a private space straight away, so nobody has to
  /// create or join a group before they can track anything.
  Future<UserProfile> getOrCreateProfile(User user) async {
    final snapshot = await _doc(user.uid).get();
    final displayName = user.displayName?.trim();

    if (!snapshot.exists) {
      final profile = UserProfile(
        uid: user.uid,
        displayName: displayName?.isNotEmpty == true
            ? displayName!
            : (user.isAnonymous ? 'Guest' : 'Someone'),
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
      );
      await _doc(user.uid).set(profile.toMap());
      return _ensurePersonalSpace(profile);
    }

    final data = snapshot.data()!;

    // Keep name and avatar in step with the signed-in account.
    final updates = <String, dynamic>{};
    if (user.photoURL != null && data['photoUrl'] != user.photoURL) {
      updates['photoUrl'] = user.photoURL;
    }
    if (displayName != null &&
        displayName.isNotEmpty &&
        data['displayName'] != displayName) {
      updates['displayName'] = displayName;
    }
    if (updates.isNotEmpty) await _doc(user.uid).update(updates);

    return _ensurePersonalSpace(UserProfile.fromMap({...data, ...updates}));
  }

  /// Gives a profile a personal space if it has none, and repairs the link if
  /// the space was deleted out from under it.
  Future<UserProfile> _ensurePersonalSpace(UserProfile profile) async {
    final existing = profile.personalGroupId;
    if (existing != null && await _groups.getGroup(existing) != null) {
      return profile;
    }

    final space = await _groups.createPersonalSpace(profile.uid);
    await _doc(profile.uid).update({
      'personalGroupId': space.id,
      'groupIds': FieldValue.arrayUnion([space.id]),
    });

    return UserProfile(
      uid: profile.uid,
      displayName: profile.displayName,
      groupIds: [space.id, ...profile.groupIds.where((id) => id != space.id)],
      fcmToken: profile.fcmToken,
      photoUrl: profile.photoUrl,
      personalGroupId: space.id,
      createdAt: profile.createdAt,
    );
  }

  Future<void> setDisplayName(String uid, String name) async {
    await _doc(uid).update({'displayName': name});
  }

  Future<void> addGroup(String uid, String groupId) async {
    await _doc(uid).update({
      'groupIds': FieldValue.arrayUnion([groupId]),
    });
  }

  Future<void> removeGroup(String uid, String groupId) async {
    await _doc(uid).update({
      'groupIds': FieldValue.arrayRemove([groupId]),
    });
  }

  Future<void> updateFcmToken(String uid, String token) async {
    await _doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
  }

  Stream<UserProfile?> streamProfile(String uid) {
    return _doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromMap(doc.data()!);
    });
  }

  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(doc.data()!);
  }

  /// Display names and avatars for a set of members, in one pass.
  Future<Map<String, UserProfile>> getProfiles(Iterable<String> uids) async {
    final result = <String, UserProfile>{};
    for (final uid in uids) {
      final profile = await getProfile(uid);
      if (profile != null) result[uid] = profile;
    }
    return result;
  }

  /// Removes everything the account owns, then the account itself. Spaces it
  /// is the last member of go entirely; in shared spaces only its own logs go
  /// and it leaves. Relay photos expire on their own (`cleanupRelayPhotos`).
  Future<void> deleteAccount(User user) async {
    final uid = user.uid;
    final profile = await getProfile(uid);
    final groupIds = {
      ...?profile?.groupIds,
      ?profile?.personalGroupId,
    }.where((id) => id.isNotEmpty);
    for (final id in groupIds) {
      final group = await _groups.getGroup(id);
      if (group == null) continue;
      final entries = firestore
          .collection('groups')
          .doc(id)
          .collection('entries');
      if (group.isPersonal || group.memberIds.every((m) => m == uid)) {
        for (final doc in (await entries.get()).docs) {
          await _deletePhoto(doc.data()['photoUrl'] as String?);
        }
        await _groups.deleteGroup(id, group.inviteCode);
        continue;
      }
      final mine = await entries.where('userId', isEqualTo: uid).get();
      for (final doc in mine.docs) {
        await _deletePhoto(doc.data()['photoUrl'] as String?);
        await doc.reference.delete();
      }
      await _groups.leaveGroup(id, uid);
    }
    await _doc(uid).delete();
    await user.delete();
  }

  Future<void> _deletePhoto(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (e) {
      // Already gone (relay cleanup) or not a storage URL; nothing to remove.
      debugPrint('[UserService] photo delete skipped: $e');
    }
  }
}
