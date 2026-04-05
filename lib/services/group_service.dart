import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rituals/models/group.dart';

class GroupService {
  final firestore = FirebaseFirestore.instance;

  String generateInviteCode() {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    final rand = Random();
    return List.generate(6, (i) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<Group> createGroup(String name, String creatorUid) async {
    final String inviteCode = generateInviteCode();

    final group = Group(
      id: '', // Firestore will generate this
      name: name,
      memberIds: [creatorUid],
      inviteCode: inviteCode,
      createdAt: DateTime.now(),
      createdBy: creatorUid,
    );
    final docRef = await firestore.collection('groups').add(group.toMap());

    await firestore.collection('inviteCodes').doc(inviteCode).set({
      'groupId': docRef.id,
    });
    await docRef.update({'id': docRef.id});
    return Group(
      id: docRef.id,
      name: name,
      memberIds: [creatorUid],
      inviteCode: inviteCode,
      createdAt: group.createdAt,
      createdBy: creatorUid,
    );
  }

  Future<Group?> joinGroup(String inviteCode, String userUid) async {
    final query = await firestore
        .collection('inviteCodes')
        .doc(inviteCode)
        .get();
    if (!query.exists) return null;

    final groupId = query.data()?['groupId'];
    final groupDoc = await firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) return null;

    final group = Group.fromMap(groupDoc.data()!);
    if (group.memberIds.length >= 4) return null;

    await firestore.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([userUid]),
    });

    final updatedDoc = await firestore.collection('groups').doc(groupId).get();
    return Group.fromMap(updatedDoc.data()!);
  }

  Future<Group?> getGroup(String groupId) async {
    final doc = await firestore.collection('groups').doc(groupId).get();
    if (!doc.exists) return null;
    return Group.fromMap(doc.data()!);
  }

  Future<void> leaveGroup(String groupId, String uid) async {
    await firestore.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> deleteGroup(String groupId, String inviteCode) async {
    await firestore.collection('groups').doc(groupId).delete();
    await firestore.collection('inviteCodes').doc(inviteCode).delete();
  }
}
