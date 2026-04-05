import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rituals/models/user_profiles.dart';

class UserService {
  final firestore = FirebaseFirestore.instance;

  Future<UserProfile> getOrCreateProfile(User user) async {
    final doc = await firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return UserProfile.fromMap(doc.data()!);
    }
    final profile = UserProfile(
      uid: user.uid,
      displayName: user.displayName ?? 'Anonymous',
      createdAt: DateTime.now(),
    );
    await firestore.collection('users').doc(user.uid).set(profile.toMap());
    return profile;
  }

  Future<void> addGroup(String uid, String groupId) async {
    await firestore.collection('users').doc(uid).update({
      'groupIds': FieldValue.arrayUnion([groupId]),
    });
  }

  Future<void> removeGroup(String uid, String groupId) async {
    await firestore.collection('users').doc(uid).update({
      'groupIds': FieldValue.arrayRemove([groupId]),
    });
  }

  Future<void> updateFcmToken(String uid, String token) async {
    await firestore.collection('users').doc(uid).update({
      'fcmToken': token,
    });
  }

  Stream<UserProfile?> streamProfile(String uid) {
    return firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromMap(doc.data()!);
    });
  }

  Future<UserProfile?> getProfile(String uid) async {
    final doc = await firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(doc.data()!);
  }
}
