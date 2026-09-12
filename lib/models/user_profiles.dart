import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final List<String> groupIds;
  final String? fcmToken;
  final DateTime createdAt;

  final String? photoUrl;

  /// The private space created for this account. Rituals land here unless the
  /// user picks a shared space.
  final String? personalGroupId;

  UserProfile({
    required this.uid,
    required this.displayName,
    this.groupIds = const [],
    this.fcmToken,
    this.photoUrl,
    this.personalGroupId,
    required this.createdAt,
  });

  /// Shared spaces only, in the order they were joined.
  List<String> get sharedGroupIds =>
      groupIds.where((id) => id != personalGroupId).toList();

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String,
      displayName: map['displayName'] as String,
      groupIds: List<String>.from(map['groupIds'] ??
          (map['groupId'] != null ? [map['groupId']] : [])),
      fcmToken: map['fcmToken'] as String?,
      photoUrl: map['photoUrl'] as String?,
      personalGroupId: map['personalGroupId'] as String?,
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'groupIds': groupIds,
      'fcmToken': fcmToken,
      'photoUrl': photoUrl,
      'personalGroupId': personalGroupId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
