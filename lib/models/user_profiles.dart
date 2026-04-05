import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final List<String> groupIds;
  final String? fcmToken;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.displayName,
    this.groupIds = const [],
    this.fcmToken,
    required this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String,
      displayName: map['displayName'] as String,
      groupIds: List<String>.from(map['groupIds'] ??
          (map['groupId'] != null ? [map['groupId']] : [])),
      fcmToken: map['fcmToken'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'groupIds': groupIds,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
