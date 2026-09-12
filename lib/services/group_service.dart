import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rituals/models/group.dart';

class JoinResult {
  final Group? group;
  final String? error;

  const JoinResult.success(this.group) : error = null;
  const JoinResult.failure(this.error) : group = null;

  bool get ok => group != null;
}

class GroupService {
  final firestore = FirebaseFirestore.instance;

  String generateInviteCode() {
    // No I, O, 0 or 1: they are the codes people mistype when reading aloud.
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (i) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<Group> createGroup(
    String name,
    String creatorUid, {
    bool isPersonal = false,
  }) async {
    final inviteCode = isPersonal ? '' : generateInviteCode();
    final createdAt = DateTime.now();

    final docRef = firestore.collection('groups').doc();
    final group = Group(
      id: docRef.id,
      name: name,
      memberIds: [creatorUid],
      inviteCode: inviteCode,
      createdAt: createdAt,
      createdBy: creatorUid,
      isPersonal: isPersonal,
    );
    await docRef.set(group.toMap());

    if (!isPersonal) {
      await firestore.collection('inviteCodes').doc(inviteCode).set({
        'groupId': docRef.id,
      });
    }
    return group;
  }

  /// The private space every account starts with. Created on demand so an
  /// existing user who only ever had shared groups gets one too.
  Future<Group> createPersonalSpace(String uid) =>
      createGroup('My Rituals', uid, isPersonal: true);

  Future<JoinResult> joinGroup(String inviteCode, String userUid) async {
    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) return const JoinResult.failure('Enter an invite code');

    final codeDoc = await firestore.collection('inviteCodes').doc(code).get();
    if (!codeDoc.exists) return const JoinResult.failure('No space with that code');

    final groupId = codeDoc.data()?['groupId'] as String?;
    if (groupId == null) return const JoinResult.failure('That code is broken');

    final groupDoc = await firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) {
      return const JoinResult.failure('That space no longer exists');
    }

    final group = Group.fromMap(groupDoc.data()!);
    if (group.memberIds.contains(userUid)) {
      return JoinResult.success(group);
    }
    if (group.isFull) {
      return JoinResult.failure('${group.name} is full');
    }

    await groupDoc.reference.update({
      'memberIds': FieldValue.arrayUnion([userUid]),
    });

    final updated = await groupDoc.reference.get();
    return JoinResult.success(Group.fromMap(updated.data()!));
  }

  Future<Group?> getGroup(String groupId) async {
    final doc = await firestore.collection('groups').doc(groupId).get();
    if (!doc.exists) return null;
    return Group.fromMap(doc.data()!);
  }

  Stream<Group?> watchGroup(String groupId) {
    return firestore.collection('groups').doc(groupId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Group.fromMap(doc.data()!);
    });
  }

  Future<void> rename(String groupId, String name) async {
    await firestore.collection('groups').doc(groupId).update({'name': name});
  }

  Future<void> leaveGroup(String groupId, String uid) async {
    await firestore.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> deleteGroup(String groupId, String inviteCode) async {
    final group = firestore.collection('groups').doc(groupId);

    for (final sub in ['rituals', 'entries']) {
      final docs = await group.collection(sub).get();
      for (final chunk in _chunk(docs.docs, 400)) {
        final batch = firestore.batch();
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    await group.delete();
    if (inviteCode.isNotEmpty) {
      await firestore.collection('inviteCodes').doc(inviteCode).delete();
    }
  }

  static Iterable<List<T>> _chunk<T>(List<T> items, int size) sync* {
    for (var i = 0; i < items.length; i += size) {
      yield items.sublist(i, min(i + size, items.length));
    }
  }
}
