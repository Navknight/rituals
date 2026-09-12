import 'package:cloud_firestore/cloud_firestore.dart';

/// A space holds rituals. Every account gets a personal space of one; shared
/// spaces add members, invite codes and nudges on top of the same structure.
class Group {
  static const int defaultMemberLimit = 8;

  final String id;
  final String name;
  final List<String> memberIds;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;

  /// A private space of one. Hides invites, members and nudges.
  final bool isPersonal;

  final int memberLimit;

  Group({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    this.isPersonal = false,
    this.memberLimit = defaultMemberLimit,
  });

  bool get isFull => memberIds.length >= memberLimit;

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Space',
      memberIds: map['memberIds'] is List
          ? List<String>.from(map['memberIds'] as List<dynamic>)
          : const [],
      inviteCode: map['inviteCode'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPersonal: map['isPersonal'] as bool? ?? false,
      memberLimit:
          (map['memberLimit'] as num?)?.toInt() ?? defaultMemberLimit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'memberIds': memberIds,
      'inviteCode': inviteCode,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPersonal': isPersonal,
      'memberLimit': memberLimit,
    };
  }
}
